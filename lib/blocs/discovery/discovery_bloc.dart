import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/peer.dart';
import '../../models/message.dart';
import '../../services/communication_service.dart';
import '../../services/notification_service.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class DiscoveryEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartDiscoveryEvent extends DiscoveryEvent {}
class StopDiscoveryEvent extends DiscoveryEvent {}
class _NativePeerDiscovered extends DiscoveryEvent {
  final Peer peer;
  _NativePeerDiscovered(this.peer);
  @override
  List<Object?> get props => [peer.endpointId];
}
class _NativePeerLost extends DiscoveryEvent {
  final String endpointId;
  _NativePeerLost(this.endpointId);
  @override
  List<Object?> get props => [endpointId];
}
class _NativePeerConnected extends DiscoveryEvent {
  final String endpointId;
  _NativePeerConnected(this.endpointId);
  @override
  List<Object?> get props => [endpointId];
}
class _NativePeerDisconnected extends DiscoveryEvent {
  final String endpointId;
  _NativePeerDisconnected(this.endpointId);
  @override
  List<Object?> get props => [endpointId];
}

// ── State ────────────────────────────────────────────────────────────────────

class ConnectToPeerEvent extends DiscoveryEvent {
  final String deviceName;
  ConnectToPeerEvent(this.deviceName);
}

class RefreshPeersEvent extends DiscoveryEvent {}

class DisconnectFromPeerEvent extends DiscoveryEvent {
  final String deviceName;
  DisconnectFromPeerEvent(this.deviceName);
}

class ManualRefreshEvent extends DiscoveryEvent {}

class ClearBroadcastEmergencyEvent extends DiscoveryEvent {}

class _IncomingBroadcastEmergency extends DiscoveryEvent {
  final Message message;
  _IncomingBroadcastEmergency(this.message);
}

class ClearBroadcastLogEvent extends DiscoveryEvent {}

class DiscoveryState extends Equatable {
  final List<Peer> peers;
  final bool isRunning;
  final String? error;
  final Message? latestBroadcastEmergency;
  final List<Message> broadcastEmergencyLog;

  const DiscoveryState({
    this.peers = const [],
    this.isRunning = false,
    this.error,
    this.latestBroadcastEmergency,
    this.broadcastEmergencyLog = const [],
  });

  DiscoveryState copyWith({
    List<Peer>? peers,
    bool? isRunning,
    String? error,
    Message? latestBroadcastEmergency,
    List<Message>? broadcastEmergencyLog,
    bool clearEmergency = false,
  }) =>
      DiscoveryState(
        peers: peers ?? this.peers,
        isRunning: isRunning ?? this.isRunning,
        error: error,
        latestBroadcastEmergency:
            clearEmergency ? null : (latestBroadcastEmergency ?? this.latestBroadcastEmergency),
        broadcastEmergencyLog: broadcastEmergencyLog ?? this.broadcastEmergencyLog,
      );

  @override
  List<Object?> get props => [peers, isRunning, error, latestBroadcastEmergency, broadcastEmergencyLog];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final CommunicationService _comm;
  StreamSubscription<P2PEvent>? _sub;

  // Track advertisement emergency markers to prevent duplicate alerts
  final Set<String> _seenAdvEmergencyIds = {};

  DiscoveryBloc(this._comm) : super(const DiscoveryState()) {
    on<StartDiscoveryEvent>(_onStart);
    on<StopDiscoveryEvent>(_onStop);
    on<_NativePeerDiscovered>(_onDiscovered);
    on<_NativePeerLost>(_onLost);
    on<_NativePeerConnected>(_onConnected);
    on<_NativePeerDisconnected>(_onDisconnected);
    on<ConnectToPeerEvent>(_onConnectToPeer);
    on<RefreshPeersEvent>(_onRefreshPeers);
    on<DisconnectFromPeerEvent>(_onDisconnectFromPeer);
    on<ManualRefreshEvent>(_onManualRefresh);
    on<_IncomingBroadcastEmergency>(_onIncomingEmergency);
    on<ClearBroadcastEmergencyEvent>(_onClearEmergency);
    on<ClearBroadcastLogEvent>(_onClearLog);
 
    _sub = _comm.events.listen(_routeEvent);
    _startRefreshTimer();
  }
 
  Timer? _refreshTimer;
 
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      add(RefreshPeersEvent());
    });
  }

  void _routeEvent(P2PEvent event) {
    if (event is PeerDiscoveredEvent) add(_NativePeerDiscovered(event.peer));
    if (event is PeerLostEvent) add(_NativePeerLost(event.endpointId));
    if (event is PeerConnectedEvent) add(_NativePeerConnected(event.endpointId));
    if (event is PeerDisconnectedEvent) add(_NativePeerDisconnected(event.endpointId));

    if (event is MessageReceivedEvent) {
      final msg = event.message;
      if (msg.type.isEmergency && msg.receiverId == Message.broadcastId) {
        add(_IncomingBroadcastEmergency(msg));
      }
    } else if (event is AdvertisementEmergencyEvent) {
      if (!_seenAdvEmergencyIds.contains(event.shortId)) {
        _seenAdvEmergencyIds.add(event.shortId);
        final syntheticMsg = Message(
          id: 'adv-emg-${event.shortId}',
          type: MessageType.emergency,
          senderId: event.deviceId,
          receiverId: Message.broadcastId,
          payload: '⚠️ EMERGENCY from ${event.displayName}',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          ttl: 0,
          hops: 0,
          seq: 0,
          priority: MessagePriority.high,
        );
        add(_IncomingBroadcastEmergency(syntheticMsg));
      }
    }
  }

  Future<void> _onStart(StartDiscoveryEvent e, Emitter<DiscoveryState> emit) async {
    try {
      await _comm.startAll();
      emit(state.copyWith(isRunning: true, peers: []));
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }

  Future<void> _onStop(StopDiscoveryEvent e, Emitter<DiscoveryState> emit) async {
    await _comm.stopAll();
    emit(const DiscoveryState(peers: [], isRunning: false));
  }

  void _onDiscovered(_NativePeerDiscovered e, Emitter<DiscoveryState> emit) {
    final peers = _upsertPeer(state.peers, e.peer);
    emit(state.copyWith(peers: peers));
  }

  Future<void> _onConnectToPeer(ConnectToPeerEvent e, Emitter<DiscoveryState> emit) async {
    await _comm.connectToDevice(e.deviceName);
  }

  Future<void> _onDisconnectFromPeer(DisconnectFromPeerEvent e, Emitter<DiscoveryState> emit) async {
    await _comm.disconnectFromDevice(e.deviceName);
  }

  void _onLost(_NativePeerLost e, Emitter<DiscoveryState> emit) {
    final peers = state.peers.map((p) {
      if (p.endpointId == e.endpointId) {
        return p.copyWith(status: PeerStatus.disconnected);
      }
      return p;
    }).toList();
    emit(state.copyWith(peers: peers));
  }

  void _onConnected(_NativePeerConnected e, Emitter<DiscoveryState> emit) {
    // LEVEL 1: Fast path — match by endpointId (normal case)
    var peers = state.peers.map((p) {
      if (p.endpointId == e.endpointId) {
        return p.copyWith(status: PeerStatus.connected);
      }
      return p;
    }).toList();

    final level1Matched = peers.any(
      (p) => p.endpointId == e.endpointId && p.status == PeerStatus.connected,
    );
    if (level1Matched) {
      emit(state.copyWith(peers: peers));
      return;
    }

    // LEVEL 2 & 3: endpointId changed after a Nearby restart.
    // Ask service for fresh peer list, then match by deviceId or displayName.
    final fresh = _comm.getCurrentPeers();
    final freshPeer = fresh.where((fp) => fp.endpointId == e.endpointId).firstOrNull;

    if (freshPeer != null) {
      peers = state.peers.map((p) {
        final matchByDeviceId = freshPeer.deviceId != null &&
                                p.deviceId != null &&
                                p.deviceId == freshPeer.deviceId;
        final matchByName = p.displayName == freshPeer.displayName;
        if (matchByDeviceId || matchByName) {
          return p.copyWith(
            status: PeerStatus.connected,
            endpointId: e.endpointId, // update stale endpointId
          );
        }
        return p;
      }).toList();

      // LEVEL 4: No existing peer matched at all — add fresh peer directly
      final level234Matched = peers.any(
        (p) => p.endpointId == e.endpointId && p.status == PeerStatus.connected,
      );
      if (!level234Matched) {
        peers = [...peers, freshPeer.copyWith(status: PeerStatus.connected)];
      }
    }

    emit(state.copyWith(peers: peers));
  }

  Future<void> _onRefreshPeers(RefreshPeersEvent e, Emitter<DiscoveryState> emit) async {
    final currentPeers = _comm.getCurrentPeers();
    final syncList = <Peer>[];
    for (var svcPeer in currentPeers) {
      // Match by deviceId first, then fall back to displayName
      final existing = state.peers.where((p) =>
        (svcPeer.deviceId != null && p.deviceId == svcPeer.deviceId) ||
        p.displayName == svcPeer.displayName
      );
      if (existing.isNotEmpty) {
        final existingPeer = existing.first;
        // Only overwrite endpointId if service has a non-empty value.
        // Preserve BLoC's known-good eid when service returns '' or stale.
        final freshEid = svcPeer.endpointId.isNotEmpty
            ? svcPeer.endpointId
            : existingPeer.endpointId;
        syncList.add(existingPeer.copyWith(
          endpointId: freshEid,
          displayName: svcPeer.displayName,
        ));
      } else {
        syncList.add(svcPeer);
      }
    }

    // Preserve connected peers
    for (var statePeer in state.peers) {
      if (statePeer.status == PeerStatus.connected) {
        final alreadyIn = syncList.any((p) =>
          (p.deviceId != null && p.deviceId == statePeer.deviceId) ||
          p.displayName == statePeer.displayName
        );
        if (!alreadyIn) syncList.add(statePeer);
      }
    }

    // Deduplicate by deviceId, then displayName as fallback
    final seen = <String>{};
    final deduped = syncList.where((p) =>
      seen.add(p.deviceId ?? p.displayName)
    ).toList();

    // Final pass: re-apply connected status from BLoC state.
    // Prevents 5s refresh timer from flickering green tiles back
    // to grey if the service layer momentarily returns 'discovered'.
    final connectedNames = state.peers
        .where((p) => p.status == PeerStatus.connected)
        .map((p) => p.deviceId ?? p.displayName)
        .toSet();

    final finalPeers = deduped.map((p) {
      final key = p.deviceId ?? p.displayName;
      if (connectedNames.contains(key) &&
          p.status != PeerStatus.connected) {
        return p.copyWith(status: PeerStatus.connected);
      }
      return p;
    }).toList();

    emit(state.copyWith(peers: finalPeers));
  }

  void _onDisconnected(_NativePeerDisconnected e, Emitter<DiscoveryState> emit) {
    final peers = state.peers.map((p) {
      if (p.endpointId == e.endpointId) return p.copyWith(status: PeerStatus.disconnected);
      return p;
    }).toList();
    emit(state.copyWith(peers: peers));
  }

  Future<void> _onManualRefresh(ManualRefreshEvent e, Emitter<DiscoveryState> emit) async {
    // Check if any peers are currently connected
    final hasActiveConnections = state.peers.any(
      (p) => p.status == PeerStatus.connected,
    );

    if (hasActiveConnections) {
      // SAFE PATH: connections are live — only sync the peer list from
      // the service layer, do NOT touch Nearby advertising/discovery.
      debugPrint('[ManualRefresh] Active connections present — soft refresh only');
      add(RefreshPeersEvent());
      return;
    }

    // FULL PATH: no active connections — safe to do a full Nearby restart
    debugPrint('[ManualRefresh] No active connections — full restart allowed');
    await _comm.forceRefresh();
  }

  void _onIncomingEmergency(_IncomingBroadcastEmergency e, Emitter<DiscoveryState> emit) {
    emit(state.copyWith(
      latestBroadcastEmergency: e.message,
      broadcastEmergencyLog: [...state.broadcastEmergencyLog, e.message],
    ));

    NotificationService.instance.showEmergency(
      title: 'BROADCAST EMERGENCY',
      body: e.message.payload,
    );
  }

  void _onClearEmergency(ClearBroadcastEmergencyEvent e, Emitter<DiscoveryState> emit) {
    emit(state.copyWith(clearEmergency: true));
  }

  void _onClearLog(ClearBroadcastLogEvent e, Emitter<DiscoveryState> emit) {
    emit(state.copyWith(broadcastEmergencyLog: []));
  }

  List<Peer> _upsertPeer(List<Peer> current, Peer peer) {
    final updated = List<Peer>.from(current);
    final exists = updated.any((p) => p.displayName == peer.displayName);
    if (!exists) {
      updated.add(peer);
    } else {
      final idx = updated.indexWhere((p) => p.displayName == peer.displayName);
      updated[idx] = peer;
    }
    return updated;
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _refreshTimer?.cancel();
    return super.close();
  }
}
