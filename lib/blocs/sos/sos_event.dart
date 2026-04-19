import 'package:equatable/equatable.dart';

/// Base class for all SOS BLoC events.
abstract class SosEvent extends Equatable {
  const SosEvent();

  @override
  List<Object?> get props => [];
}

/// User tapped the SOS button from INACTIVE state.
/// Triggers: GPS capture, first broadcast, countdown start.
class SosActivateEvent extends SosEvent {
  const SosActivateEvent();
}

/// User tapped EXTEND 5 MIN from PAUSED state.
/// Triggers: timer cancel, fresh GPS, new broadcast, restart.
class SosExtendEvent extends SosEvent {
  const SosExtendEvent();
}

/// User tapped CANCEL SOS from ACTIVE or PAUSED state.
/// Triggers: timer cancel, full state reset to INACTIVE.
class SosCancelEvent extends SosEvent {
  const SosCancelEvent();
}

/// Internal: 1-second countdown tick fired by Timer.periodic.
class SosTickEvent extends SosEvent {
  const SosTickEvent();
}

/// Internal: fire one broadcast now (on activate, extend, or tick=0).
class SosBroadcastEvent extends SosEvent {
  const SosBroadcastEvent();
}

/// Internal event: An ACK was received for the active SOS broadcast.
/// hopCount = number of hops the ACK travelled.
class AckReceivedEvent extends SosEvent {
  final int hopCount;
  const AckReceivedEvent(this.hopCount);
  @override
  List<Object?> get props => [hopCount];
}
