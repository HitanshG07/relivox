import 'package:equatable/equatable.dart';

enum PeerStatus { discovered, connecting, connected, disconnected }

class Peer extends Equatable {
  final String endpointId;    // Nearby Connections ephemeral endpoint ID
  final String displayName;   // Human-readable name advertised by peer
  final String? deviceId;     // Persistent device ID
  final PeerStatus status;
  final String lastSeen;      // ISO8601 UTC

  const Peer({
    required this.endpointId,
    required this.displayName,
    this.deviceId,
    this.status = PeerStatus.discovered,
    required this.lastSeen,
  });

  Peer copyWith({
    String? endpointId,
    PeerStatus? status,
    String? lastSeen,
    String? displayName,
    String? deviceId,
  }) =>
      Peer(
        endpointId: endpointId ?? this.endpointId,
        displayName: displayName ?? this.displayName,
        deviceId: deviceId ?? this.deviceId,
        status: status ?? this.status,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  String get shortId => endpointId.length > 6
      ? endpointId.substring(endpointId.length - 6)
      : endpointId;

  @override
  List<Object?> get props => [endpointId, displayName, deviceId, status, lastSeen];
}
