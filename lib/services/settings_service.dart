import 'package:shared_preferences/shared_preferences.dart';
import '../constants/settings_keys.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  // In-memory cache — always read from these, never directly from _prefs
  String username               = 'Anonymous';
  bool   allowRelay             = true;
  bool   enableNotifications    = true;
  bool   enableEmergencyAlerts  = true;
  String forcedDeviceState      = 'AUTO';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadAll();
  }

  void _loadAll() {
    username              = _prefs.getString(SettingsKeys.username)              ?? 'Anonymous';
    allowRelay            = _prefs.getBool(SettingsKeys.allowRelay)            ?? true;
    enableNotifications   = _prefs.getBool(SettingsKeys.enableNotifications)     ?? true;
    enableEmergencyAlerts = _prefs.getBool(SettingsKeys.enableEmergencyAlerts)   ?? true;
    forcedDeviceState     = _prefs.getString(SettingsKeys.forcedDeviceState)     ?? 'AUTO';
  }

  Future<void> setUsername(String value) async {
    username = value;
    await _prefs.setString(SettingsKeys.username, value);
  }

  Future<void> setAllowRelay(bool value) async {
    allowRelay = value;
    await _prefs.setBool(SettingsKeys.allowRelay, value);
  }

  Future<void> setEnableNotifications(bool value) async {
    enableNotifications = value;
    await _prefs.setBool(SettingsKeys.enableNotifications, value);
  }

  Future<void> setEnableEmergencyAlerts(bool value) async {
    enableEmergencyAlerts = value;
    await _prefs.setBool(SettingsKeys.enableEmergencyAlerts, value);
  }

  Future<void> setForcedDeviceState(String value) async {
    forcedDeviceState = value;
    await _prefs.setString(SettingsKeys.forcedDeviceState, value);
  }
}
