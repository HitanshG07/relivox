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

  const SosState({
    this.status = SosStatus.inactive,
    this.broadcastCount = 0,
    this.secondsRemaining = SosConstants.broadcastIntervalSeconds,
  });

  /// Returns a new [SosState] with provided fields overridden.
  SosState copyWith({
    SosStatus? status,
    int? broadcastCount,
    int? secondsRemaining,
  }) =>
      SosState(
        status: status ?? this.status,
        broadcastCount: broadcastCount ?? this.broadcastCount,
        secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      );

  @override
  List<Object?> get props => [status, broadcastCount, secondsRemaining];
}
