import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/ack_constants.dart';
import '../models/peer.dart';
import '../models/message.dart';
import '../protocols/gossip_manager.dart';
import 'database_service.dart';
import 'identity_service.dart';
import 'notification_service.dart';
import 'encryption_service.dart';

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

class AdvertisementEmergencyEvent extends P2PEvent {
  final String displayName;
  final String deviceId;
  final String emergencyType; // FIRE | MEDC | TRAP | GEN
  final String latitude; // decimal string e.g. "19.0709"
  final String longitude; // decimal string e.g. "72.8796"
  AdvertisementEmergencyEvent({
    required this.displayName,
    required this.deviceId,
    required this.emergencyType,
    required this.latitude,
    required this.longitude,
  });
}

/// The central Dart service that talks to NearbyPlugin.kt via MethodChannel.
class CommunicationService {
  final IdentityService _identity;
  final DatabaseService _db;
  late final GossipManager _gossip;
  final _enc = EncryptionService();

  static CommunicationService? _instance;
  factory CommunicationService(
      [IdentityService? identity, DatabaseService? db]) {
    if (_instance == null) {
      if (identity == null || db == null) {
        throw Exception(
            "CommunicationService must be initialized with services first");
      }
      _instance = CommunicationService._internal(identity, db);
    }
    return _instance!;
  }

  CommunicationService._internal(this._identity, this._db) {
    _kChannel.setMethodCallHandler(_onNativeCall);

    _gossip = GossipManager(
      myDeviceId: _identity.deviceId,
      transmit: (endpointId, payload) async {
        // Encrypt at the transmit boundary so ALL gossip relay paths
        // (send, relay, retry, flush) are encrypted automatically.
        // GossipManager stays encryption-unaware.
        final encrypted = await _enc.encrypt(payload);
        await _kChannel.invokeMethod('sendPayload', {
          'endpointId': endpointId,
          'payload': encrypted,
        });
      },
    );
  }

  // All P2P events (peer lifecycle + messages) in a single stream
  final _eventController = StreamController<P2PEvent>.broadcast();
  Stream<P2PEvent> get events => _eventController.stream;

  // Public streams exposing core state for UI layers (BLoC).
  Stream<List<Peer>> get deviceStream async* {
    yield getCurrentPeers();
    await for (final ev in events) {
      if (ev is PeerDiscoveredEvent ||
          ev is PeerLostEvent ||
          ev is PeerConnectedEvent ||
          ev is PeerDisconnectedEvent) {
        yield getCurrentPeers();
      }
    }
  }

  Stream<Message> get messageStream async* {
    await for (final ev in events) {
      if (ev is MessageReceivedEvent) yield ev.message;
    }
  }

  Stream<Message> get incomingMessages => messageStream;

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

  String? _activeEmergencyMarker; // e.g. "|EMG:a3f9"
  Timer? _emergencyMarkerTimer;

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
  final Set<String> _ackedIds = {};
  String? _lastSentMessageId;
  String? get lastSentMessageId => _lastSentMessageId;

  Timer? _cleanupTimer;

  // ── Advertising & Discovery ───────────────────────────────────────────────

  Future<void> startAdvertising() async {
    if (_isAdvertising) return;
    if (!await _requestPermissions()) return;
    try {
      final combinedName = "${_identity.displayName}|${_identity.deviceId}";
      await _kChannel
          .invokeMethod('startAdvertising', {'userName': combinedName});
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
    _exposedIdForName.clear();
    _connectingDevices.clear();
    // NOTE: Do NOT clear _connectedDevices here — that is handled
    // by onDisconnected events fired by Nearby after stopAll().
    // Clearing it here would cause the isEmpty guard to misbehave.
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
    await _kChannel
        .invokeMethod('startAdvertising', {'userName': combinedName});
    _log.i('Advertising restarted with name: $combinedName');
  }

  List<Peer> getCurrentPeers() {
    final seenDeviceIds = <String>{};
    return _deviceEndpoints.keys
        .map((name) {
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
                : (isConnecting
                    ? PeerStatus.connecting
                    : PeerStatus.discovered),
            lastSeen: DateTime.now().toUtc().toIso8601String(),
          );
        })
        .where((p) => seenDeviceIds.add(p.deviceId ?? p.displayName))
        .toList();
  }

  void startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => cleanupStaleEndpoints());

    _seenCleanupTimer?.cancel();
    _seenCleanupTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final now = DateTime.now();
      _seenMessageTimestamps
          .removeWhere((id, time) => now.difference(time).inSeconds > 60);
      _seenMessageIds
          .removeWhere((id) => !_seenMessageTimestamps.containsKey(id));
    });
  }

  void stopCleanupTimer() {
    _cleanupTimer?.cancel();
    _seenCleanupTimer?.cancel();
  }

  void cleanupStaleEndpoints() {
    final now = DateTime.now();
    final staleEndpoints = _endpointLastSeen.entries
        .where((entry) => now.difference(entry.value).inSeconds > 30)
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

    // Clear any stale "connecting" state from a previous attempt
    // that was aborted by a Nearby restart. Without this, the device
    // appears stuck and the UI never allows a retry.
    if (_connectingDevices.contains(name)) {
      final currentEid = _exposedIdForName[name];
      if (currentEid == null) {
        // No fresh endpoint — genuinely still waiting for rediscovery
        _log.w('[CONNECT] $name still connecting but no eid — skipping');
        return;
      }
      // Has a fresh eid — previous attempt was stale, clear and retry
      _log.i(
          '[CONNECT] $name had stale connecting state — clearing and retrying');
      _connectingDevices.remove(name);
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (_connectedDevices.contains(name)) return;

    final endpointId = _exposedIdForName[name];
    if (endpointId == null) return;
    _connectingDevices.add(name);
    await _requestConnection(endpointId);
  }

  Future<void> disconnectFromDevice(String name) async {
    final endpoints = _deviceEndpoints[name];
    if (endpoints == null) return;
    for (var eid in endpoints) {
      await _kChannel
          .invokeMethod('disconnectFromEndpoint', {'endpointId': eid});
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

  Future<void> sendUserMessage(
    String content,
    String receiverId,
    MessageType type, {
    String emergencyType = 'GEN',
  }) async {
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
      priority:
          type.isEmergency ? MessagePriority.high : MessagePriority.normal,
    );
    _lastSentMessageId = message.id;
    _log.i(
        '💡 [TX-TRACE] Sending user message ${message.id} to ${receiverId.isEmpty ? 'BROADCAST' : receiverId}');
    await _db.upsertMessage(message);
    _eventController.add(MessageReceivedEvent(message, 'local'));
    await _gossip.send(message);

    // If this is a broadcast emergency, also embed the marker in
    // the advertisement so non-connected nearby peers can receive it.
    if (type == MessageType.emergency && receiverId == Message.broadcastId) {
      _activateEmergencyMarker(message.id, type: emergencyType);
    }
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

        // Detect format:
        //   Emergency: "DisplayName|EMG:TYPE:Lat,Lng"
        //   Normal:    "DisplayName|deviceId"
        final emgPart =
            parts.firstWhere((p) => p.startsWith('EMG:'), orElse: () => '');

        String? incomingDeviceId;
        String? emgType;
        String? emgLat;
        String? emgLng;

        if (emgPart.isNotEmpty) {
          // Emergency mode — UUID dropped, GPS embedded instead
          // Token format: EMG:TYPE:Lat,Lng
          final emgTokens = emgPart.split(':');
          if (emgTokens.length >= 3) {
            emgType = emgTokens[1]; // FIRE | MEDC | TRAP | GEN
            final coords = emgTokens[2].split(',');
            if (coords.length >= 2) {
              emgLat = coords[0];
              emgLng = coords[1];
            }
          }
          // incomingDeviceId stays null — UUID was not in this beacon
        } else if (parts.length > 1 && !parts[1].startsWith('EMG:')) {
          // Normal advertisement — parts[1] is persistent deviceId
          incomingDeviceId = parts[1];
        }

        // Persist username ↔ deviceId (normal mode only)
        if (incomingDeviceId != null &&
            displayName.isNotEmpty &&
            !displayName.startsWith('Device-')) {
          _db.upsertKnownPeer(incomingDeviceId, displayName);
        }

        // Fire geo-emergency event if all tokens parsed correctly
        if (emgPart.isNotEmpty &&
            emgType != null &&
            emgLat != null &&
            emgLng != null) {
          _log.i('[EMG-ADV] Geo-emergency from $displayName: '
              '$emgType @ $emgLat,$emgLng');
          _eventController.add(AdvertisementEmergencyEvent(
            displayName: displayName,
            deviceId: eid, // UUID dropped during emergency — use eid
            emergencyType: emgType,
            latitude: emgLat,
            longitude: emgLng,
          ));
          // Early exit — do NOT run normal peer discovery logic
          // for UUID-less emergency beacons (would corrupt peer map)
          _endpointLastSeen[eid] = DateTime.now();
          break;
        }

        // Normal flow: clear stale state for this deviceId
        if (incomingDeviceId != null) {
          final staleEndpoint = _endpointToDeviceId.entries
              .where((e) => e.value == incomingDeviceId)
              .map((e) => e.key)
              .firstOrNull;
          if (staleEndpoint != null && staleEndpoint != eid) {
            final oldName = _endpointToName[staleEndpoint];
            if (oldName != null) {
              _connectedDevices.remove(oldName);
              _connectingDevices.remove(oldName);
            }
            _endpointToDeviceId.remove(staleEndpoint);
            _endpointToName.remove(staleEndpoint);
          }
        }

        // Clear stale old-name if deviceId re-advertised with new name
        if (incomingDeviceId != null) {
          final oldName = _endpointToName.entries
              .where((e) =>
                  _endpointToDeviceId[e.key] == incomingDeviceId &&
                  e.value != displayName)
              .map((e) => e.value)
              .firstOrNull;
          if (oldName != null) {
            if (_connectedDevices.remove(oldName))
              _connectedDevices.add(displayName);
            if (_connectingDevices.remove(oldName))
              _connectingDevices.add(displayName);
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
        } else {
          _deviceEndpoints[displayName]!.add(eid);
        }
        // ALWAYS update exposedIdForName so connectToDevice()
        // always has the freshest endpointId after a Nearby restart
        _exposedIdForName[displayName] = eid;

        _log.i(
            'Device discovered: $displayName ($eid) | ID: $incomingDeviceId.');

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
        _log.i(
            'Connection initiated with $name ($eid). Accepting (Bug 1 Step 2)...');
        _eventController.add(ConnectionInitiatedEvent(
            eid, name, args['token'] as String? ?? ''));
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
          // Flush is now handled by the 3s delayed call inside
          // onEndpointConnected — removing instant flush here
          // to prevent it from racing the radio init window
          debugPrint('[FLUSH-TRACE] Delayed flush scheduled for $eid (3s)');
          _log.i('Connected to $eid');
          _eventController.add(PeerConnectedEvent(eid));
        } else {
          // Remove from connecting regardless of whether name is known.
          // This prevents the "stuck spinner" when name lookup fails.
          if (name != null) {
            _connectingDevices.remove(name);
          } else {
            // name unknown — scan all connecting devices and clear any
            // that match this endpointId via _exposedIdForName
            final staleName = _exposedIdForName.entries
                .where((e) => e.value == eid)
                .map((e) => e.key)
                .firstOrNull;
            if (staleName != null) _connectingDevices.remove(staleName);
          }
          _eventController.add(PeerFailedEvent(eid, code));
          // Auto-retry removed — after a Nearby restart the eid changes.
          // Retrying with a stale eid causes permanent deadlock.
          // The user or the 5s discovery refresh will trigger a fresh connect.
          _log.w('[CONN-FAIL] Connection to $eid (name: $name) failed '
              'with code $code — no auto-retry');
        }
        break;

      case 'onDisconnected':
        final eid = args['endpointId'] as String;
        _connectedEndpoints.remove(eid);
        final name = _endpointToName[eid];
        if (name != null) {
          _connectedDevices.remove(name);
          _connectingDevices.remove(name);
          // Remove stale exposedId so connectToDevice() cannot fire
          // a request with this dead eid during the restart window.
          // It will be repopulated by the next onEndpointFound.
          if (_exposedIdForName[name] == eid) {
            _exposedIdForName.remove(name);
          }
        }
        _gossip.onEndpointDisconnected(eid);
        _eventController.add(PeerDisconnectedEvent(eid));
        // Only restart when ALL connections are gone.
        // Restarting while other peers are still connected
        // kills those active connections.
        if (_connectedEndpoints.isEmpty) {
          _log.i('Disconnected from $eid — no peers left. Restarting.');
          _restartDiscoveryAndAdvertising();
        } else {
          _log.i(
              'Disconnected from $eid — ${_connectedEndpoints.length} peers still active, skip restart.');
        }
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
    final rawPayload = args['payload'] as String? ?? '';

    // Attempt decryption — drop packet silently if it fails
    final payloadStr = await _enc.decrypt(rawPayload);
    if (payloadStr == null) {
      _log.w('[ENC] Dropped packet from $eid — decryption failed');
      return;
    }

    late Message incoming;
    try {
      incoming = Message.fromWireJson(payloadStr);
    } catch (e) {
      return;
    }

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
    final isBroadcast = processedMessage.receiverId == Message.broadcastId;
    final isFinalReceiver = processedMessage.receiverId == myId || isBroadcast;

    if (!isFinalReceiver && processedMessage.ttl <= 0) return;

    if (isFinalReceiver) {
      await _db.upsertMessage(processedMessage);
      _eventController.add(MessageReceivedEvent(processedMessage, eid));
      // Resolve the human-readable name for the notification title.
      // _endpointToName maps endpointId → displayName.
      // Falls back gracefully inside show() if null.
      final senderName = _endpointToName[eid];
      await NotificationService()
          .show(processedMessage, senderName: senderName);

      if (processedMessage.type != MessageType.ack) {
        if (processedMessage.type == MessageType.emergency &&
            processedMessage.senderId != _identity.deviceId) {
          if (!_ackedIds.contains(processedMessage.id)) {
            _ackedIds.add(processedMessage.id);
            final ack = Message(
              id: const Uuid().v4(),
              type: MessageType.ack,
              senderId: _identity.deviceId,
              receiverId: processedMessage.senderId,
              timestamp: DateTime.now().toUtc().toIso8601String(),
              ttl: AckConstants.ACK_TTL,
              hops: 0,
              seq: 0,
              priority: MessagePriority.high,
              payload: '${AckConstants.ACK_PREFIX}${processedMessage.id}'
                  '${AckConstants.ACK_SEPARATOR}${processedMessage.hops}',
            );
            await _db.upsertMessage(ack);
            await _gossip.send(ack);
            _log.i('💡 [ACK] Sent ACK for SOS ${processedMessage.id}');
          }
        } else {
          _log.i(
              '💡 [ACK-TRACE] Generating auto-ACK for message ${processedMessage.id} to ${processedMessage.senderId}');
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
      }
      return;
    }

    if (processedMessage.ttl <= 0) return;
    // Relay silently — relay nodes must NOT show notifications
    // for messages addressed to other devices
    debugPrint(
        'MESH RELAY: ${processedMessage.id} | Recipients: ${_connectedEndpoints.length} peers connected');
    await _gossip.relay(processedMessage, eid);
  }

  Future<void> _restartDiscoveryAndAdvertising() async {
    // SAFETY: Never restart if peers are still connected.
    // stopDiscovery/stopAdvertising on Nearby will NOT drop
    // already-established connections, but we guard here
    // to avoid the edge case where Nearby firmware does.
    if (_connectedEndpoints.isNotEmpty) {
      _log.i('[RESTART] Skipped — ${_connectedEndpoints.length} '
          'active connections still live');
      return;
    }
    try {
      await stopDiscovery();
    } catch (_) {}
    try {
      await stopAdvertising();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));
    await startDiscovery();

    await startAdvertising();
  }

  Future<void> forceRefresh() async {
    // Clear all in-progress connection attempts before restarting.
    // After restart all endpointIds change — stale connecting state
    // would permanently block re-connection to those devices.
    _connectingDevices.clear();
    await _restartDiscoveryAndAdvertising();
  }

  /// Restarts advertising with an |EMG:xxxx suffix embedded in the
  /// endpointName so nearby non-connected devices can detect the alert.
  /// Automatically clears after 5 minutes.
  Future<void> _activateEmergencyMarker(
    String messageId, {
    String type = 'GEN',
  }) async {
    String lat = '0.0000';
    String lng = '0.0000';
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 5),
          ),
        );
        // 4 decimal places = ~11m accuracy, keeps BLE name short
        lat = pos.latitude.toStringAsFixed(4);
        lng = pos.longitude.toStringAsFixed(4);
      }
    } catch (e) {
      _log.w('[EMG-ADV] GPS unavailable — using 0.0000 fallback: $e');
    }

    // Format: "DisplayName|EMG:TYPE:Lat,Lng"
    // UUID dropped during emergency to fit within BLE name limit
    // Example: "Hitansh|EMG:FIRE:19.0709,72.8796" = 34 chars
    _activeEmergencyMarker = '|EMG:$type:$lat,$lng';
    final combinedName = '${_identity.displayName}$_activeEmergencyMarker';

    try {
      await _kChannel.invokeMethod('stopAdvertising');
      await _kChannel
          .invokeMethod('startAdvertising', {'userName': combinedName});
      _log.i('[EMG-ADV] Geo-emergency marker activated: $combinedName');
    } catch (e) {
      _log.e('[EMG-ADV] Failed to start geo-emergency advertising: $e');
    }

    _emergencyMarkerTimer?.cancel();
    _emergencyMarkerTimer = Timer(const Duration(minutes: 5), () async {
      _activeEmergencyMarker = null;
      // Restore normal advertising WITH deviceId
      final normalName = '${_identity.displayName}|${_identity.deviceId}';
      try {
        await _kChannel.invokeMethod('stopAdvertising');
        await _kChannel
            .invokeMethod('startAdvertising', {'userName': normalName});
        _log.i('[EMG-ADV] Geo-emergency marker cleared, back to normal');
      } catch (e) {
        _log.e('[EMG-ADV] Failed to clear geo-emergency marker: $e');
      }
    });
  }

  void dispose() {
    stopCleanupTimer();
    _emergencyMarkerTimer?.cancel();
    _gossip.dispose();
    _eventController.close();
  }
}
