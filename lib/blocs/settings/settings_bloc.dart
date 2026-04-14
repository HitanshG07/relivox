import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/settings_service.dart';
import '../../services/communication_service.dart';

// ── EVENTS ──────────────────────────────────────────────────
abstract class SettingsEvent {}

class SettingsLoaded           extends SettingsEvent {}
class UsernameChanged          extends SettingsEvent {
  final String value;
  UsernameChanged(this.value);
}
class AllowRelayToggled        extends SettingsEvent {
  final bool value;
  AllowRelayToggled(this.value);
}
class NotificationsToggled     extends SettingsEvent {
  final bool value;
  NotificationsToggled(this.value);
}
class EmergencyAlertsToggled   extends SettingsEvent {
  final bool value;
  EmergencyAlertsToggled(this.value);
}

// ── STATE ────────────────────────────────────────────────────
class SettingsState {
  final String username;
  final bool   allowRelay;
  final bool   enableNotifications;
  final bool   enableEmergencyAlerts;

  const SettingsState({
    required this.username,
    required this.allowRelay,
    required this.enableNotifications,
    required this.enableEmergencyAlerts,
  });

  SettingsState copyWith({
    String? username,
    bool? allowRelay,
    bool? enableNotifications,
    bool? enableEmergencyAlerts,
  }) {
    return SettingsState(
      username:             username             ?? this.username,
      allowRelay:           allowRelay           ?? this.allowRelay,
      enableNotifications:  enableNotifications  ?? this.enableNotifications,
      enableEmergencyAlerts:enableEmergencyAlerts?? this.enableEmergencyAlerts,
    );
  }
}

// ── BLOC ─────────────────────────────────────────────────────
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsService _service;

  SettingsBloc(this._service)
      : super(SettingsState(
          username:             _service.username,
          allowRelay:           _service.allowRelay,
          enableNotifications:  _service.enableNotifications,
          enableEmergencyAlerts:_service.enableEmergencyAlerts,
        )) {

    on<SettingsLoaded>((event, emit) {
      emit(SettingsState(
        username:             _service.username,
        allowRelay:           _service.allowRelay,
        enableNotifications:  _service.enableNotifications,
        enableEmergencyAlerts:_service.enableEmergencyAlerts,
      ));
    });

    on<UsernameChanged>((event, emit) async {
      await _service.setUsername(event.value);
      emit(state.copyWith(username: event.value));
      CommunicationService().restartAdvertising(event.value); // ADD THIS
    });

    on<AllowRelayToggled>((event, emit) async {
      await _service.setAllowRelay(event.value);
      emit(state.copyWith(allowRelay: event.value));
    });

    on<NotificationsToggled>((event, emit) async {
      await _service.setEnableNotifications(event.value);
      emit(state.copyWith(enableNotifications: event.value));
    });

    on<EmergencyAlertsToggled>((event, emit) async {
      await _service.setEnableEmergencyAlerts(event.value);
      emit(state.copyWith(enableEmergencyAlerts: event.value));
    });
  }
}
