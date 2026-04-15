import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/peer.dart';
import '../models/message.dart';
import '../protocols/gossip_manager.dart';
import 'database_service.dart';
import 'identity_service.dart';
import 'notification_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

const _kChannel = MethodChannel('com.relivox/nearby');

/// Unifies all P2P events into strongly-typed streams.
class P2PEvent {}

class PeerDiscoveredEvent extends P2PEvent {
  final Peer peer;
  PeerDiscoveredEvent(this.peer);
}

class PeerLostEvent extends P2PEvent {
  final String endpointId;
  PeerLostEvent(this.endpointId);
}

class PeerConnectedEvent extends P2PEvent {
  final String endpointId;
  PeerConnectedEvent(this.endpointId);
}

class PeerFailedEvent extends P2PEvent {
  final String endpointId;
  final int statusCode;
  PeerFailedEvent(this.endpointId, this.statusCode);
}

class PeerDisconnectedEvent extends P2PEvent {
  final String endpointId;
  PeerDisconnectedEvent(this.endpointId);
}

class ConnectionInitiatedEvent extends P2PEvent {
  final String endpointId;
  final String endpointName;
  final String token;
  ConnectionInitiatedEvent(this.endpointId, this.endpointName, this.token);
}

class MessageReceivedEvent extends P2PEvent {
  final Message message;
  final String fromEndpointId;
  MessageReceivedEvent(this.message, this.fromEndpointId);
}

class AckReceivedEvent extends P2PEvent {
  final String ackedMessageId;
  final String fromEndpointId;
  AckReceivedEvent(this.ackedMessageId, this.fromEndpointId);
}


/// The central Dart service that talks to NearbyPlugin.kt via MethodChannel.
class CommunicationService {
  final IdentityService _identity;
  final DatabaseService _db;
  late final GossipManager _gossip;

  static CommunicationService? _instance;
  factory CommunicationService([IdentityService? identity, DatabaseService? db]) {
    if (_instance == null) {
      if (identity == null || db == null) {
        throw Exception("CommunicationService must be initialized with services first");
      }
      _instance = CommunicationService._internal(identity, db);
    }
    return _instance!;
  }

  CommunicationService._internal(this._identity, this._db) {
    _kChannel.setMethodCallHandler(_onNativeCall);
    _gossip = GossipManager(
      myDeviceId: _identity.deviceId,
      transmit: (endpointId, payload) => _kChannel.invokeMethod('sendPayload', {
        'endpointId': endpointId,
        'payload': payload,
      }),
    );
  }

  // All P2P events (peer lifecycle + messages) in a single stream
  final _eventController = StreamController<P2PEvent>.broadcast();
  Stream<P2PEvent> get events => _eventController.stream;

  // Public streams exposing core state for UI layers (BLoC).
  Stream<List<Peer>> get deviceStream async* {
    yield getCurrentPeers();
    await for (final ev in events) {
      if (ev is PeerDiscoveredEvent || ev is PeerLostEvent || ev is PeerConnectedEvent || ev is PeerDisconnectedEvent) {
        yield getCurrentPeers();
      }
    }
  }

  Stream<Message> get messageStream async* {
    await for (final ev in events) {
      if (ev is MessageReceivedEvent) yield ev.message;
    }
  }

  Stream<bool> get connectionStateStream async* {
    await for (final ev in events) {
      if (ev is PeerConnectedEvent) {
        yield true;
      } else if (ev is PeerDisconnectedEvent) {
        yield _connectedEndpoints.isNotEmpty;
      }
    }
  }

  // Track currently connected endpoints locally
  final Set<String> _connectedEndpoints = {};

  bool _isAdvertising = false;
  bool _isDiscovering = false;
  bool _isRunning = false;

  final Map<String, Set<String>> _deviceEndpoints = {};
  final Set<String> _seenMessageIds = {};
  final Map<String, DateTime> _seenMessageTimestamps = {};
  Timer? _seenCleanupTimer;

  final Map<String, String> _exposedIdForName = {};
  final Set<String> _connectedDevices = {};
  final Set<String> _connectingDevices = {};
  final Map<String, String> _endpointToName = {};
  final Map<String, DateTime> _endpointLastSeen = {};
  final Map<String, String> _endpointToDeviceId = {}; // New map
  Timer? _cleanupTimer;


  // ── Advertising & Discovery ───────────────────────────────────────────────

  Future<void> startAdvertising() async {
    if (_isAdvertising) return;
    if (!await _requestPermissions()) return;
    try {
      final combinedName = "${_identity.displayName}|${_identity.deviceId}";
      await _kChannel.invokeMethod('startAdvertising', {'userName': combinedName});
      _isAdvertising = true;
      _log.i('Advertising started as "$combinedName"');
    } catch (e) {
      _log.e('startAdvertising failed: $e');
      rethrow;
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    if (!await _requestPermissions()) return;
    try {
      await _kChannel.invokeMethod('startDiscovery');
      _isDiscovering = true;
      _log.i('Discovery started');
    } catch (e) {
      _log.e('startDiscovery failed: $e');
      rethrow;
    }
  }

  void _resetState() {
    _endpointToName.clear();
    _endpointLastSeen.clear();
    _deviceEndpoints.clear();
    _seenMessageTimestamps.clear();
  }

  Future<void> startAll() async {
    if (_isRunning) return;
    _resetState();
    _isRunning = true;
    await startAdvertising();
    await startDiscovery();
    startCleanupTimer();
    _log.i('Communication system started');
  }

  Future<void> stopAll() async {
    if (!_isRunning) return;
    _isRunning = false;
    try {
      await stopDiscovery();
      await stopAdvertising();
      stopCleanupTimer();
      await _kChannel.invokeMethod('stopAll');
      _resetState();
    } catch (e) {
      _log.e('stopAll failure: $e');
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _kChannel.invokeMethod('stopAdvertising');
      _isAdvertising = false;
      _log.i('Advertising stopped');
    } catch (e) {
      _log.e('stopAdvertising failed: $e');
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _kChannel.invokeMethod('stopDiscovery');
      _isDiscovering = false;
      _log.i('Discovery stopped');
    } catch (e) {
      _log.e('stopDiscovery failed: $e');
    }
  }

  Future<void> restartAdvertising(String newName) async {
    await _kChannel.invokeMethod('stopAdvertising');
    final combinedName = "$newName|${_identity.deviceId}";
    await _kChannel.invokeMethod('startAdvertising', {'userName': combinedName});
    _log.i('Advertising restarted with name: $combinedName');
  }

  List<Peer> getCurrentPeers() {
    final seenDeviceIds = <String>{};
    return _deviceEndpoints.keys.map((name) {
      final isConnected = _connectedDevices.contains(name);
      final isConnecting = _connectingDevices.contains(name);
      final eid = _exposedIdForName[name] ?? '';
      final devId = _endpointToDeviceId[eid];
      return Peer(
        endpointId: eid,
        displayName: name,
        deviceId: devId,
        status: isConnected
            ? PeerStatus.connected
            : (isConnecting ? PeerStatus.connecting : PeerStatus.discovered),
        lastSeen: DateTime.now().toUtc().toIso8601String(),
      );
    }).where((p) => seenDeviceIds.add(p.deviceId ?? p.displayName)).toList();
  }

  void startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 1), (_) => cleanupStaleEndpoints());
    _seenCleanupTimer?.cancel();
    _seenCleanupTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final now = DateTime.now();
      _seenMessageTimestamps.removeWhere((id, time) => now.difference(time).inSeconds > 60);
      _seenMessageIds.removeWhere((id) => !_seenMessageTimestamps.containsKey(id));
    });
  }

  void stopCleanupTimer() {
    _cleanupTimer?.cancel();
    _seenCleanupTimer?.cancel();
  }

  void cleanupStaleEndpoints() {
    final now = DateTime.now();
    final staleEndpoints = _endpointLastSeen.entries
        .where((entry) => now.difference(entry.value).inSeconds > 10)
        .map((entry) => entry.key)
        .toList();
    for (final eid in staleEndpoints) {
      final name = _endpointToName[eid];
      if (name != null && _connectedDevices.contains(name)) continue;
      _endpointLastSeen.remove(eid);
      for (var set in _deviceEndpoints.values) set.remove(eid);
    }
    _deviceEndpoints.removeWhere((key, set) => set.isEmpty);
  }

  Future<void> connectToDevice(String name) async {
    if (_connectedDevices.contains(name)) return;
    // Clear any stuck connecting state before retrying
    _connectingDevices.remove(name);
    final endpointId = _exposedIdForName[name];
    if (endpointId == null) return;
    _connectingDevices.add(name);
    await _requestConnection(endpointId);
  }
 
  Future<void> disconnectFromDevice(String name) async {
    final endpoints = _deviceEndpoints[name];
    if (endpoints == null) return;
    for (var eid in endpoints) {
      await _kChannel.invokeMethod('disconnectFromEndpoint', {'endpointId': eid});
    }
    _connectedDevices.remove(name);
    _connectingDevices.remove(name);
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  Future<void> sendUserMessage(String content, String receiverId, MessageType type) async {
    if (content.isEmpty) return;
    final message = Message(
      id: const Uuid().v4(),
      senderId: _identity.deviceId,
      receiverId: receiverId,
      payload: content,
      ttl: type.isEmergency ? 8 : 5,
      type: type,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      hops: 0,
      seq: 0,
      priority: type.isEmergency ? MessagePriority.high : MessagePriority.normal,
    );
    _log.i('💡 [TX-TRACE] Sending user message ${message.id} to ${receiverId.isEmpty ? 'BROADCAST' : receiverId}');
    await _db.upsertMessage(message);
    _eventController.add(MessageReceivedEvent(message, 'local'));
    await _gossip.send(message);
  }

  Future<void> broadcastMessage(Message message) async {
    final updatedMessage = message.copyWith(ttl: (message.ttl > 0) ? message.ttl - 1 : 0);
    _gossip.markSeen(updatedMessage.id);
    await _db.upsertMessage(updatedMessage);
    _log.i('💡 [TX-TRACE] Invoking broadcastPayload for ${updatedMessage.id}');
    await _kChannel.invokeMethod('broadcastPayload', {'payload': updatedMessage.toWireJson()});
  }

  // ── Native → Dart callbacks ───────────────────────────────────────────────

  Future<void> _onNativeCall(MethodCall call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    switch (call.method) {
      case 'onEndpointFound':
        final eid = args['endpointId'] as String;
        final rawName = args['endpointName'] as String? ?? eid;
        
        final parts = rawName.split('|');
        final displayName = parts[0];
        final incomingDeviceId = parts.length > 1 ? parts[1] : null;

        // If this deviceId is known, clear its stale state
        // so reconnection is not blocked
        if (incomingDeviceId != null) {
          final staleEndpoint = _endpointToDeviceId.entries
            .where((e) => e.value == incomingDeviceId)
            .map((e) => e.key)
            .firstOrNull;

          if (staleEndpoint != null && staleEndpoint != eid) {
            // Find the OLD name associated with this endpoint to clear it
            final oldName = _endpointToName[staleEndpoint];
            if (oldName != null) {
              _connectedDevices.remove(oldName);
              _connectingDevices.remove(oldName);
            }
            _endpointToDeviceId.remove(staleEndpoint);
            _endpointToName.remove(staleEndpoint);
          }
        }

        // Remove stale old-name entry if this deviceId re-advertised with a new name
        if (incomingDeviceId != null) {
          final oldName = _endpointToName.entries
            .where((e) => _endpointToDeviceId[e.key] == incomingDeviceId && e.value != displayName)
            .map((e) => e.value)
            .firstOrNull;
          if (oldName != null) {
            if (_connectedDevices.remove(oldName)) _connectedDevices.add(displayName);
            if (_connectingDevices.remove(oldName)) _connectingDevices.add(displayName);
            _deviceEndpoints.remove(oldName);
            _exposedIdForName.remove(oldName);
          }
        }

        _endpointLastSeen[eid] = DateTime.now();
        _endpointToName[eid] = displayName;
        if (incomingDeviceId != null) {
          _endpointToDeviceId[eid] = incomingDeviceId;
        }

        if (!_deviceEndpoints.containsKey(displayName)) {
          _deviceEndpoints[displayName] = {eid};
          _exposedIdForName[displayName] = eid;
        } else {
          _deviceEndpoints[displayName]!.add(eid);
        }
        
        _log.i('Device discovered: $displayName ($eid) | ID: $incomingDeviceId.');
        
        final peer = Peer(
          endpointId: eid,
          displayName: displayName,
          deviceId: incomingDeviceId,
          lastSeen: DateTime.now().toUtc().toIso8601String(),
        );
        _eventController.add(PeerDiscoveredEvent(peer));
        break;

      case 'onConnectionInitiated':
        final eid = args['endpointId'] as String;
        final name = args['endpointName'] as String? ?? eid;
        _log.i('Connection initiated with $name ($eid). Accepting (Bug 1 Step 2)...');
        _eventController.add(ConnectionInitiatedEvent(eid, name, args['token'] as String? ?? ''));
        await _acceptConnection(eid);
        break;

      case 'onConnectionResult':
        final eid = args['endpointId'] as String;
        final code = args['statusCode'] as int;
        final name = _endpointToName[eid];
        if (name != null) _connectingDevices.remove(name);
        if (code == 0 /* STATUS_OK */) {
          if (name != null) _connectedDevices.add(name);
          _connectedEndpoints.add(eid);
          _gossip.onEndpointConnected(eid);
          _gossip.flush();
          debugPrint('[FLUSH-TRACE] Flush triggered after connection established with $eid');
          _log.i('Connected to $eid (Bug 1 Step 3)');
          _eventController.add(PeerConnectedEvent(eid));
        } else {
          if (name != null) _connectingDevices.remove(name);
          _eventController.add(PeerFailedEvent(eid, code));
          // Retry once after 4s — handles Nearby radio init delay on device restart
          final retryName = name;
          Future.delayed(const Duration(seconds: 4), () async {
            if (retryName != null &&
                _deviceEndpoints.containsKey(retryName) &&
                !_connectedDevices.contains(retryName)) {
              _log.w('[RETRY] Retrying connection to $retryName after code $code');
              await _requestConnection(eid);
            }
          });
        }
        break;

      case 'onDisconnected':
        final eid = args['endpointId'] as String;
        _connectedEndpoints.remove(eid);
        final name = _endpointToName[eid];
        if (name != null) {
          _connectedDevices.remove(name);
          _connectingDevices.remove(name);
        }
        _gossip.onEndpointDisconnected(eid);
        _eventController.add(PeerDisconnectedEvent(eid));
        _log.i('Disconnected from $eid. Restarting (Bug 3)...');
        _restartDiscoveryAndAdvertising();
        break;

      case 'onPayloadReceived':
        await _handlePayload(args);
        break;
    }
  }

  Future<void> _requestConnection(String eid) async {
    try {
      await _kChannel.invokeMethod('requestConnection', {
        'endpointId': eid,
        'userName': _identity.displayName,
      });
    } on PlatformException catch (e) {
      if (e.code == '8003') {
        _log.w('Already connected to $eid — syncing state');
        await _acceptConnection(eid);
      } else {
        _log.e('requestConnection to $eid failed: $e');
      }
    } catch (e) {
      _log.e('requestConnection to $eid failed: $e');
    }
  }

  Future<void> _acceptConnection(String eid) async {
    try {
      await _kChannel.invokeMethod('acceptConnection', {'endpointId': eid});
    } catch (e) {
      _log.e('acceptConnection to $eid failed: $e');
    }
  }

  Future<void> _handlePayload(Map<String, dynamic> args) async {
    final eid = args['endpointId'] as String;
    final payloadStr = args['payload'] as String? ?? '';
    late Message incoming;
    try {
      incoming = Message.fromWireJson(payloadStr);
    } catch (e) { return; }

    if (_seenMessageIds.contains(incoming.id)) return;
    _seenMessageIds.add(incoming.id);
    _seenMessageTimestamps[incoming.id] = DateTime.now();

    if (incoming.type == MessageType.ack) {
      final ackedId = incoming.payload;
      _log.i('💡 [ACK-TRACE] Caught ACK for message $ackedId from $eid');
      await _db.updateDeliveryStatus(ackedId, DeliveryStatus.acked);
      _gossip.recordAck(ackedId, eid);
      _eventController.add(AckReceivedEvent(ackedId, eid));
      return;
    }

    final processedMessage = incoming.copyWith(
      ttl: incoming.ttl - 1,
      hops: incoming.hops + 1,
    );

    final myId = _identity.deviceId;
    final isBroadcast =
        processedMessage.receiverId == Message.broadcastId;
    final isFinalReceiver =
        processedMessage.receiverId == myId || isBroadcast;

    if (!isFinalReceiver && processedMessage.ttl <= 0) return;

    if (isFinalReceiver) {
      await _db.upsertMessage(processedMessage);
      _eventController.add(MessageReceivedEvent(processedMessage, eid));
      await NotificationService().show(processedMessage);
      if (processedMessage.type != MessageType.ack) {
        _log.i('💡 [ACK-TRACE] Generating auto-ACK for message ${processedMessage.id} to ${processedMessage.senderId}');
        final ack = Message(
          id: const Uuid().v4(),
          type: MessageType.ack,
          senderId: _identity.deviceId,
          receiverId: processedMessage.senderId,
          timestamp: DateTime.now().toUtc().toIso8601String(),
          ttl: 3,
          hops: 0,
          seq: 0,
          priority: MessagePriority.normal,
          payload: processedMessage.id,
        );
        await _gossip.send(ack);
      }
      return;
    }

    if (processedMessage.ttl <= 0) return;
    // Relay silently — relay nodes must NOT show notifications
    // for messages addressed to other devices
    debugPrint('MESH RELAY: ${processedMessage.id} | Recipients: ${_connectedEndpoints.length} peers connected');
    await _gossip.relay(processedMessage, eid);
  }

  Future<void> _restartDiscoveryAndAdvertising() async {
    try { await stopDiscovery(); } catch (_) {}
    try { await stopAdvertising(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    await startDiscovery();
    await startAdvertising();
  }

  Future<void> forceRefresh() async {
    await _restartDiscoveryAndAdvertising();
  }

  void dispose() {
    stopCleanupTimer();
    _gossip.dispose();
    _eventController.close();
  }
}
