import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Centralized permission request handler.
/// Requests all permissions required by Nearby Connections on Android 10-14.
class PermissionService {
  /// Returns true if ALL required permissions are granted.
  Future<bool> requestAll() async {
    if (!Platform.isAndroid) return true;

    final perms = await _buildPermissionList();
    final statuses = await perms.request();

    bool allGranted = true;
    for (final entry in statuses.entries) {
      if (!entry.value.isGranted) {
        _log.w('Permission denied: ${entry.key}');
        allGranted = false;
      }
    }
    return allGranted;
  }

  Future<List<Permission>> _buildPermissionList() async {
    final base = <Permission>[
      Permission.location,
      Permission.locationWhenInUse,
    ];

    // Bluetooth permissions are split into granular permissions on Android 12+
    base.addAll([
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ]);

    return base;
  }

  Future<bool> areAllGranted() async {
    final perms = await _buildPermissionList();
    for (final p in perms) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  Future<void> openSettingsIfPermanentlyDenied() async {
    final perms = await _buildPermissionList();
    for (final p in perms) {
      if (await p.isPermanentlyDenied) {
        await openAppSettings();
        return;
      }
    }
  }
}
