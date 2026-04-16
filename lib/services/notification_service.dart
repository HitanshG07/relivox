import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'settings_service.dart';
import '../models/message.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Session-lifetime duplicate guard — separate from seenMessageIds
  final Set<String> _notifiedIds = {};

  // Global navigator key — required for SnackBar in foreground
  // Assign this in main.dart to MaterialApp(navigatorKey: navigatorKey)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'relivox_normal',
        'Messages',
        description: 'Normal Relivox messages',
        importance: Importance.defaultImportance,
        enableVibration: false,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        'relivox_emergency',
        'Emergency Alerts',
        description: 'Emergency Relivox alerts',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        ledColor: const Color(0xFFFF0000),
        playSound: true,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();
  }

  /// MAIN ENTRY POINT
  /// Call this AFTER message is displayed in UI, BEFORE relay in
  /// communication_service.dart
  Future<void> show(Message message) async {
    // GATE 1: Global notification toggle
    if (!SettingsService().enableNotifications) return;

    // GATE 2: Duplicate notification prevention
    if (_notifiedIds.contains(message.id)) return;
    _notifiedIds.add(message.id);

    // GATE 3: Route by message type with specific gating logic
    if (message.type == MessageType.emergency) {
      if (!SettingsService().enableEmergencyAlerts) return;
      await _showEmergencyNotification(message);
      // _showInAppBanner(message); // User requested removal
    } else {
      await _showNormalNotification(message);
      // _showInAppBanner(message); // User requested removal
    }
  }

  Future<void> _showNormalNotification(Message message) async {
    const androidDetails = AndroidNotificationDetails(
      'relivox_normal',
      'Messages',
      channelDescription: 'Normal Relivox messages',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: false,
    );
    await _plugin.show(
      message.id.hashCode,
      message.senderId,     // Title = sender ID (mesh identity)
      message.content,      // Body = message text
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _showEmergencyNotification(Message message) async {
    final androidDetails = AndroidNotificationDetails(
      'relivox_emergency',
      'Emergency Alerts',
      channelDescription: 'Emergency Relivox alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern:
          Int64List.fromList([0, 500, 200, 500, 200, 500]),
      color: const Color(0xFFFF0000),
      ledColor: const Color(0xFFFF0000),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,  // Appears on lock screen
    );
    await _plugin.show(
      message.id.hashCode,
      '🚨 EMERGENCY ALERT',
      message.content,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Manually show an emergency notification with custom title and body.
  Future<void> showEmergency({
    required String title,
    required String body,
  }) async {
    if (!SettingsService().enableNotifications ||
        !SettingsService().enableEmergencyAlerts) return;

    final androidDetails = AndroidNotificationDetails(
      'relivox_emergency',
      'Emergency Alerts',
      channelDescription: 'Emergency Relivox alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      color: const Color(0xFFFF0000),
      ledColor: const Color(0xFFFF0000),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
    );

    await _plugin.show(
      title.hashCode.abs(),
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }
}
