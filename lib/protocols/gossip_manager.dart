import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../constants/mesh_constants.dart';

enum MeshMode { STAR, CLUSTER }

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
  static const int MAX_RETRIES = 3;

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

  // Key: messageId  Value: Set of endpointIds that received it
  final Map<String, Set<String>> _broadcastEmergencyDelivered = {};

  /// Tracks when each endpoint first connected (for smart relay).
  final Map<String, DateTime> _connectionTimes = {};

  Timer? _retryTimer;

  GossipManager({
    required this.myDeviceId,
    required Future<void> Function(String endpointId, String payload) transmit,
  }) : _transmit = transmit {
    _retryTimer = Timer.periodic(
      const Duration(seconds: 30),
      // FIX-2: unawaited() explicitly marks this as intentional fire-and-forget.
      // The Future return type now ensures exceptions are catchable internally.
      (_) => unawaited(_retryPendingMessages()),
    );
    _init(); // Restores queue from DB (fire-and-forget async)
  }

  Future<void> _init() async {
    try {
      final restored = await DatabaseService().getPendingMessages();
      for (final msg in restored) {
        _pendingQueue.add(_PendingMessage(msg));
      }
      debugPrint(
          '[GossipManager] Restored ${_pendingQueue.length} pending messages from DB');
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
    _connectionTimes[endpointId] = DateTime.now(); // NEW
    // Use a two-stage flush:
    //   Stage 1 @ 3s  — covers fast devices (most modern Android)
    //   Stage 2 @ 8s  — safety net for slow devices or congested radio
    // Each stage checks the endpoint is still connected before flushing.
    // This replaces the single blind 3s delay with validated retry.
    _scheduledFlush(endpointId, const Duration(seconds: 3));
    _scheduledFlush(endpointId, const Duration(seconds: 8));
  }

  void _scheduledFlush(String endpointId, Duration delay) {
    Future.delayed(delay, () async {
      if (!_connectedEndpoints.contains(endpointId)) {
        debugPrint(
            '[GossipManager] Flush cancelled — $endpointId disconnected');
        return;
      }
      debugPrint('[GossipManager] Flush @ ${delay.inSeconds}s for $endpointId');
      _retryPendingMessages();
      await _flushBroadcastEmergenciesToEndpoint(endpointId);
    });
  }

  /// Removes a disconnected device from management.
  void onEndpointDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    _connectionTimes.remove(endpointId); // NEW — clean up
  }

  /// Current mesh advertising mode.
  MeshMode get meshMode =>
      _connectedEndpoints.length >= MeshConstants.clusterThreshold
          ? MeshMode.CLUSTER
          : MeshMode.STAR;

  /// Number of currently connected endpoints.
  int get connectedCount => _connectedEndpoints.length;

  /// Returns the appropriate TTL for the current mesh density.
  static int adaptiveTtl(int peerCount) {
    if (peerCount < MeshConstants.sparseLimit) return MeshConstants.ttlSparse;
    if (peerCount < MeshConstants.denseLimit) return MeshConstants.ttlNormal;
    if (peerCount < MeshConstants.maxDenseLimit) return MeshConstants.ttlDense;
    return MeshConstants.ttlMaxDense;
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

    // 4b. Broadcast emergency: ALWAYS store for late-joining peers,
    // regardless of whether endpoints are connected right now.
    final isBroadcastEmergency =
        message.type.isEmergency && message.receiverId == Message.broadcastId;
    if (isBroadcastEmergency) {
      _storeForLater(message);
    }

    // Phase 7: Drop expired messages (emergency bypasses)
    if (message.ttl <= 0 && !message.type.isEmergency) {
      debugPrint('[TTL-DROP] ${message.id} (ttl=${message.ttl})');
      return;
    }

    // 5. Transmission
    final now = DateTime.now();
    for (final endpoint in _connectedEndpoints) {
      if (endpoint == fromEndpoint) continue;

      // Phase 6: Skip brand-new peers for NORMAL messages only
      if (message.priority == MessagePriority.normal) {
        final connectedAt = _connectionTimes[endpoint];
        if (connectedAt != null) {
          final ageMs = now.difference(connectedAt).inMilliseconds;
          if (ageMs < MeshConstants.newPeerGracePeriodMs) {
            debugPrint('[SmartRelay] Skipping new peer $endpoint '
                '(age ${ageMs}ms < grace period)');
            continue;
          }
        }
      }

      try {
        // Phase 7: Decrement TTL + increment hops for relay hops
        final toSend = (fromEndpoint == 'local')
            ? message
            : message.copyWith(
                ttl: message.ttl - 1,
                hops: message.hops + 1,
              );
        await _transmit(endpoint, toSend.toWireJson());

        // Phase 7: Remove from pending queue if present
        final pendingIdx =
            _pendingQueue.indexWhere((pm) => pm.message.id == message.id);
        if (pendingIdx != -1) {
          _pendingQueue.removeAt(pendingIdx);
          DatabaseService().removePendingMessage(message.id);
        }
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
      int oldestNormalIdx =
          _pendingQueue.indexWhere((m) => m.message.type.isNormal);
      if (oldestNormalIdx != -1) {
        final removed = _pendingQueue.removeAt(oldestNormalIdx);
        DatabaseService().removePendingMessage(removed.message.id);

        // Add EMERGENCY to FRONT
        _pendingQueue.insert(0, _PendingMessage(message));
        DatabaseService().savePendingMessage(message);
      } else {
        debugPrint(
            '[GossipManager] Queue full, cannot store emergency — no NORMAL to evict');
      }
      return;
    }

    if (message.type.isNormal) {
      // Find oldest NORMAL message
      int oldestNormalIdx =
          _pendingQueue.indexWhere((m) => m.message.type.isNormal);
      if (oldestNormalIdx != -1) {
        final removed = _pendingQueue.removeAt(oldestNormalIdx);
        DatabaseService().removePendingMessage(removed.message.id);

        // Add new NORMAL to BACK
        _pendingQueue.add(_PendingMessage(message));
        DatabaseService().savePendingMessage(message);
      } else {
        debugPrint(
            '[GossipManager] Queue full with EMERGENCY messages, rejecting NORMAL');
      }
      return;
    }
  }

  /// Retries sending all pending messages to all connected endpoints.
  Future<void> _retryPendingMessages() async {
    if (_connectedEndpoints.isEmpty) return;
    if (_pendingQueue.isEmpty) return;

    // Snapshot to avoid concurrent modification
    final snapshot = List<_PendingMessage>.from(_pendingQueue);
    final endpointList = List<String>.from(_connectedEndpoints);

    final Set<_PendingMessage> toRemove = {};

    for (final pending in snapshot) {
      if (pending.retryCount >= GossipManager.MAX_RETRIES) {
        toRemove.add(pending);
        debugPrint(
            '[FLUSH-TRACE] ${pending.message.id} → ⛔ MAX_RETRIES exceeded, dropping');
        continue;
      }

      // Track per-message delivery — only remove when ALL endpoints got it
      bool sentToAll = true;
      for (final endpoint in endpointList) {
        try {
          await _transmit(endpoint, pending.message.toWireJson());
          debugPrint(
              '[FLUSH-TRACE] ${pending.message.id} → ✅ sent to $endpoint');
        } catch (e) {
          sentToAll = false;
          debugPrint(
              '[FLUSH-TRACE] ${pending.message.id} → ❌ failed for $endpoint: $e');
        }
      }

      if (sentToAll) {
        toRemove.add(pending);
      } else {
        // Partial failure — increment retry, keep in queue
        pending.retryCount++;
        debugPrint('[FLUSH-TRACE] ${pending.message.id} → partial failure '
            '[retry ${pending.retryCount}/${GossipManager.MAX_RETRIES}]');
      }
    }

    for (final sent in toRemove) {
      _pendingQueue.remove(sent);
      DatabaseService().removePendingMessage(sent.message.id);
      debugPrint(
          '[FLUSH-TRACE] ${sent.message.id} → 🗑 removed after full delivery');
    }
  }

  /// Re-sends all stored broadcast emergency messages that have NOT been
  /// acknowledged yet to a single newly connected [endpointId].
  /// Called only from onEndpointConnected — normal text messages are
  /// NOT affected.
  Future<void> _flushBroadcastEmergenciesToEndpoint(String endpointId) async {
    final emergencies = _pendingQueue
        .where((pm) =>
            pm.message.type.isEmergency &&
            pm.message.receiverId == Message.broadcastId)
        .toList();

    if (emergencies.isEmpty) return;

    debugPrint('[EMERGENCY-FLUSH] Sending ${emergencies.length} broadcast '
        'emergencies to new peer $endpointId');

    final List<_PendingMessage> toRemove = [];

    for (final pm in emergencies) {
      try {
        await _transmit(endpointId, pm.message.toWireJson());
        debugPrint('[EMERGENCY-FLUSH] ✅ ${pm.message.id} → $endpointId');

        // Record this endpoint as having received this broadcast emergency
        _broadcastEmergencyDelivered
            .putIfAbsent(pm.message.id, () => {})
            .add(endpointId);

        // If ALL currently connected endpoints have now received it, prune it
        final deliveredTo = _broadcastEmergencyDelivered[pm.message.id] ?? {};
        final allDelivered = _connectedEndpoints.every(
          (ep) => deliveredTo.contains(ep),
        );
        if (allDelivered) {
          toRemove.add(pm);
          debugPrint('[EMERGENCY-FLUSH] 🗑 ${pm.message.id} delivered to all '
              '${_connectedEndpoints.length} peers — pruning from queue');
        }
      } catch (e) {
        debugPrint(
            '[EMERGENCY-FLUSH] ❌ ${pm.message.id} → $endpointId failed: $e');
      }
    }

    // Prune fully-delivered broadcast emergencies from queue and DB
    for (final pm in toRemove) {
      _pendingQueue.remove(pm);
      _broadcastEmergencyDelivered.remove(pm.message.id);
      DatabaseService().removePendingMessage(pm.message.id);
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
    _connectionTimes.clear(); // NEW
  }

  void dispose() {
    _retryTimer?.cancel();
  }

  /// Sends this device's full known peer list to [endpointId].
  /// Called once at connection time (Phase 8).
  Future<void> sendPeerManifest(String endpointId) async {
    try {
      final peers = await DatabaseService().getAllKnownPeers();
      if (peers.isEmpty) return;
      final payload = json.encode(peers);
      final manifest = Message.create(
        senderId: myDeviceId,
        receiverId: endpointId,
        payload: payload,
        type: MessageType.control,
        priority: MessagePriority.normal,
        ttl: 1,
      );
      await _transmit(endpointId, manifest.toWireJson());
      debugPrint('[PeerManifest] Sent ${peers.length} peers '
          'to $endpointId');
    } catch (e) {
      debugPrint('[PeerManifest] Send failed: $e');
    }
  }

  /// Merges an incoming peer manifest into the local DB.
  /// Called when a control message with a JSON-array payload
  /// is received (Phase 8).
  Future<void> receivePeerManifest(String payload) async {
    try {
      final List<dynamic> list = json.decode(payload) as List;
      int merged = 0;
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        final deviceId = map['device_id'] as String?;
        final displayName = map['display_name'] as String?;
        if (deviceId != null && displayName != null) {
          await DatabaseService().upsertKnownPeer(deviceId, displayName);
          merged++;
        }
      }
      debugPrint('[PeerManifest] Merged $merged peers from manifest');
    } catch (e) {
      debugPrint('[PeerManifest] Receive failed: $e');
    }
  }
}
