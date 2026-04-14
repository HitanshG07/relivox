import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

enum DeviceState { READY, LIMITED, FULL }

/// Internal wrapper for messages in the persistent pending queue.
class _PendingMessage {
  final Message message;
  int retryCount = 0;
  _PendingMessage(this.message);
}

/// Implements the gossip relay protocol with store-and-forward semantics.
class GossipManager {
  static const int _maxSeenCacheSize = 2000;
  static const int MAX_QUEUE_SIZE = 50;
  static const int MAX_RETRIES    = 3;

  final String myDeviceId;
  final Future<void> Function(String endpointId, String payload) _transmit;
  bool get _allowRelay => SettingsService().allowRelay;

  // Connectivity state owned by GossipManager since Part 3
  final Set<String> _connectedEndpoints = {};

  // Ordered set for LRU eviction of oldest seen IDs
  final LinkedHashSet<String> _seenIds = LinkedHashSet();

  // persistent pending messages
  final List<_PendingMessage> _pendingQueue = [];

  // ACK tracking: message ID → Set of endpointIds that have acked
  final Map<String, Set<String>> _acks = {};

  Timer? _retryTimer;

  GossipManager({
    required this.myDeviceId,
    required Future<void> Function(String endpointId, String payload) transmit,
  }) : _transmit = transmit {
    _retryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _retryPendingMessages(),
    );
    _init(); // Restores queue from DB (fire-and-forget async)
  }

  Future<void> _init() async {
    try {
      final restored = await DatabaseService().getPendingMessages();
      for (final msg in restored) {
        _pendingQueue.add(_PendingMessage(msg));
      }
      debugPrint('[GossipManager] Restored ${_pendingQueue.length} pending messages from DB');
    } catch (e) {
      debugPrint('[GossipManager] Failed to restore pending queue: $e');
    }
  }

  DeviceState get currentState {
    final forced = SettingsService().forcedDeviceState;
    if (forced != 'AUTO') {
      return DeviceState.values.firstWhere(
        (e) => e.toString().split('.').last == forced,
        orElse: () => DeviceState.READY,
      );
    }

    if (_pendingQueue.length < 30) return DeviceState.READY;
    if (_pendingQueue.length >= 50) return DeviceState.FULL;
    return DeviceState.LIMITED;
  }

  bool isNew(String messageId) => !_seenIds.contains(messageId);

  void markSeen(String messageId) {
    if (_seenIds.contains(messageId)) return;
    if (_seenIds.length >= _maxSeenCacheSize) {
      _seenIds.remove(_seenIds.first);
    }
    _seenIds.add(messageId);
  }

  /// Registered a newly connected device and flushes queue immediately.
  void onEndpointConnected(String endpointId) {
    _connectedEndpoints.add(endpointId);
    _retryPendingMessages();
  }

  /// Removes a disconnected device from management.
  void onEndpointDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
  }

  /// Initiates relay for a locally created message.
  Future<void> send(Message message) async {
    return relay(message, 'local');
  }

  /// Core relay decision logic.
  Future<void> relay(
    Message message,
    String fromEndpoint,
  ) async {
    // 1. Destination Check
    if (message.receiverId == myDeviceId) {
      return;
    }

    // 2. Settings Check (NORMAL messages only)
    if (message.type.isNormal && !_allowRelay) {
      return;
    }

    // 3. Device State Rules
    final state = currentState;
    if (state == DeviceState.FULL && message.type.isNormal) {
      return;
    }
    if (state == DeviceState.LIMITED &&
        !message.type.isNormal &&
        !message.type.isEmergency) {
      return;
    }

    // 4. Connectivity Check
    if (_connectedEndpoints.isEmpty) {
      _storeForLater(message);
      return;
    }

    // 5. Transmission
    for (final endpoint in _connectedEndpoints) {
      if (endpoint == fromEndpoint) continue;
      
      try {
        await _transmit(endpoint, message.toWireJson());
      } catch (e) {
        debugPrint('[GossipManager] Transmit failed to $endpoint: $e');
        // Will be retry-eligible later via _pendingQueue if connectivity exists
      }
    }
  }

  /// Persistent store-and-forward with priority-based eviction.
  void _storeForLater(Message message) {
    if (message.ttl <= 0) return; // Drop expired
    
    // Deduplicate in queue
    if (_pendingQueue.any((m) => m.message.id == message.id)) return;

    if (_pendingQueue.length < MAX_QUEUE_SIZE) {
      _pendingQueue.add(_PendingMessage(message));
      DatabaseService().savePendingMessage(message);
      return;
    }

    // Queue full — Eviction policy
    if (message.type.isEmergency) {
      // Find oldest NORMAL message
      int oldestNormalIdx = _pendingQueue.indexWhere((m) => m.message.type.isNormal);
      if (oldestNormalIdx != -1) {
        final removed = _pendingQueue.removeAt(oldestNormalIdx);
        DatabaseService().removePendingMessage(removed.message.id);
        
        // Add EMERGENCY to FRONT
        _pendingQueue.insert(0, _PendingMessage(message));
        DatabaseService().savePendingMessage(message);
      } else {
        debugPrint('[GossipManager] Queue full, cannot store emergency — no NORMAL to evict');
      }
      return;
    }

    if (message.type.isNormal) {
      // Find oldest NORMAL message
      int oldestNormalIdx = _pendingQueue.indexWhere((m) => m.message.type.isNormal);
      if (oldestNormalIdx != -1) {
        final removed = _pendingQueue.removeAt(oldestNormalIdx);
        DatabaseService().removePendingMessage(removed.message.id);
        
        // Add new NORMAL to BACK
        _pendingQueue.add(_PendingMessage(message));
        DatabaseService().savePendingMessage(message);
      } else {
        debugPrint('[GossipManager] Queue full with EMERGENCY messages, rejecting NORMAL');
      }
      return;
    }
  }

  /// Retries sending all pending messages to all connected endpoints.
  void _retryPendingMessages() async {
    if (_connectedEndpoints.isEmpty) return;
    if (_pendingQueue.isEmpty) return;

    // Snapshot avoid concurrent modification
    final snapshot = List<_PendingMessage>.from(_pendingQueue);

    final Set<_PendingMessage> toRemove = {};
    for (final endpoint in _connectedEndpoints) {
      debugPrint('[FLUSH-TRACE] Flushing ${_pendingQueue.length} msgs for $endpoint');
      for (final pending in snapshot) {
        if (pending.retryCount >= GossipManager.MAX_RETRIES) {
          toRemove.add(pending);
          debugPrint('[FLUSH-TRACE] ${pending.message.id} → ⛔ MAX_RETRIES exceeded, dropping');
          continue;
        }
        try {
          await _transmit(endpoint, pending.message.toWireJson());
          toRemove.add(pending);
          debugPrint('[FLUSH-TRACE] ${pending.message.id} → ✅ sent to $endpoint');
        } catch (e) {
          pending.retryCount++;
          debugPrint('[FLUSH-TRACE] ${pending.message.id} → ❌ skipped ($e) [retry ${pending.retryCount}/${GossipManager.MAX_RETRIES}]');
        }
      }
    }
    for (final sent in toRemove) {
      _pendingQueue.remove(sent);
      DatabaseService().removePendingMessage(sent.message.id);
      debugPrint('[FLUSH-TRACE] ${sent.message.id} → 🗑 removed from queue after broadcast');
    }
  }

  /// Record that [endpointId] acknowledged [messageId].
  void recordAck(String messageId, String endpointId) {
    _acks.putIfAbsent(messageId, () => {}).add(endpointId);
  }

  bool hasBeenAcked(String messageId) =>
      (_acks[messageId]?.isNotEmpty) ?? false;

  void flush() {
    debugPrint('[FLUSH-TRACE] Manual flush triggered. '
      'Queue: ${_pendingQueue.length} msgs, '
      'Endpoints: ${_connectedEndpoints.length}');
    _retryPendingMessages();
  }

  void debugForceState(DeviceState state) {
    debugPrint('[STATE-TRACE] Forced: $state');
  }

  void reset() {
    _seenIds.clear();
    _pendingQueue.clear();
    _acks.clear();
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}
