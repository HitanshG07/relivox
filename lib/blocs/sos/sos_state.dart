import 'package:equatable/equatable.dart';
import '../../constants/sos_constants.dart';

/// SOS lifecycle status.
enum SosStatus { inactive, active, paused }

/// Immutable snapshot of all SOS state emitted by [SosBloc].
class SosState extends Equatable {
  /// Current SOS lifecycle status.
  final SosStatus status;

  /// Number of broadcasts sent in the current session.
  final int broadcastCount;

  /// Seconds remaining until next broadcast. Counts 60 → 1.
  /// Zero when inactive or paused.
  final int secondsRemaining;

  final int ackCount;
  final int maxHops;
  final String? currentSosMessageId;
  /// FIX-9: Extended max broadcast count (null = use SosConstants.maxBroadcasts)
  final int? extendedMaxBroadcasts;

  const SosState({
    this.status = SosStatus.inactive,
    this.broadcastCount = 0,
    this.secondsRemaining = SosConstants.broadcastIntervalSeconds,
    this.ackCount = 0,
    this.maxHops = 0,
    this.currentSosMessageId,
    this.extendedMaxBroadcasts,
  });

  /// Returns a new [SosState] with provided fields overridden.
  SosState copyWith({
    SosStatus? status,
    int? broadcastCount,
    int? secondsRemaining,
    int? ackCount,
    int? maxHops,
    String? currentSosMessageId,
    int? extendedMaxBroadcasts,
  }) =>
      SosState(
        status: status ?? this.status,
        broadcastCount: broadcastCount ?? this.broadcastCount,
        secondsRemaining: secondsRemaining ?? this.secondsRemaining,
        ackCount: ackCount ?? this.ackCount,
        maxHops: maxHops ?? this.maxHops,
        currentSosMessageId: currentSosMessageId ?? this.currentSosMessageId,
        extendedMaxBroadcasts: extendedMaxBroadcasts ?? this.extendedMaxBroadcasts,
      );

  @override
  List<Object?> get props => [
        status,
        broadcastCount,
        secondsRemaining,
        ackCount,
        maxHops,
        currentSosMessageId,
        extendedMaxBroadcasts,
      ];
}
