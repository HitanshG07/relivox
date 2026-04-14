import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/peer.dart';
import '../../services/communication_service.dart';

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

class DiscoveryState extends Equatable {
  final List<Peer> peers;
  final bool isRunning;
  final String? error;

  const DiscoveryState({
    this.peers = const [],
    this.isRunning = false,
    this.error,
  });

  DiscoveryState copyWith({
    List<Peer>? peers,
    bool? isRunning,
    String? error,
  }) =>
      DiscoveryState(
        peers: peers ?? this.peers,
        isRunning: isRunning ?? this.isRunning,
        error: error,
      );

  @override
  List<Object?> get props => [peers, isRunning, error];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final CommunicationService _comm;
  StreamSubscription<P2PEvent>? _sub;

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
 
    _sub = _comm.events.listen(_routeEvent);
    _startRefreshTimer();
  }
 
  Timer? _refreshTimer;
 
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(RefreshPeersEvent());
    });
  }

  void _routeEvent(P2PEvent event) {
    if (event is PeerDiscoveredEvent) add(_NativePeerDiscovered(event.peer));
    if (event is PeerLostEvent) add(_NativePeerLost(event.endpointId));
    if (event is PeerConnectedEvent) add(_NativePeerConnected(event.endpointId));
    if (event is PeerDisconnectedEvent) add(_NativePeerDisconnected(event.endpointId));
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
    _comm.stopRetryLoop();
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
    final peers = state.peers.map((p) {
      if (p.endpointId == e.endpointId) return p.copyWith(status: PeerStatus.connected);
      return p;
    }).toList();
    emit(state.copyWith(peers: peers));
  }

  Future<void> _onRefreshPeers(RefreshPeersEvent e, Emitter<DiscoveryState> emit) async {
    final currentPeers = _comm.getCurrentPeers();
    // Rebuild peer list to match service reality
    final syncList = <Peer>[];
    for (var svcPeer in currentPeers) {
      final existing = state.peers.toList().where((p) => p.displayName == svcPeer.displayName);
      if (existing.isNotEmpty) {
        syncList.add(existing.first.copyWith(endpointId: svcPeer.endpointId));
      } else {
        syncList.add(svcPeer);
      }
    }
    
    // HARD DEDUPLICATION by displayName
    final uniqueNames = <String>{};
    final finalPeers = syncList.where((p) => uniqueNames.add(p.displayName)).toList();
    
    emit(state.copyWith(peers: finalPeers));
  }

  void _onDisconnected(_NativePeerDisconnected e, Emitter<DiscoveryState> emit) {
    final peers = state.peers.map((p) {
      if (p.endpointId == e.endpointId) return p.copyWith(status: PeerStatus.disconnected);
      return p;
    }).toList();
    emit(state.copyWith(peers: peers));
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
