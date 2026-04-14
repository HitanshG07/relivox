import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'settings_service.dart';
import '../models/message.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
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
      _showInAppBanner(message);
    } else {
      await _showNormalNotification(message);
      _showInAppBanner(message);
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
  void _showInAppBanner(Message message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final isEmergency = message.type == MessageType.emergency;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isEmergency ? Colors.red[800] : const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isEmergency ? 6 : 3),
        content: Row(
          children: [
            Icon(
              isEmergency ? Icons.warning_amber_rounded : Icons.message,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEmergency
                    ? '🚨 EMERGENCY from ${message.senderId}: ${message.content}'
                    : 'Message from ${message.senderId}: ${message.content}',
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
