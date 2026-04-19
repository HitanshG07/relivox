import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../constants/sos_constants.dart';
import '../models/message.dart';
import 'communication_service.dart';

import '../models/medical_info.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// GPS acquisition and emergency broadcast singleton.
///
/// Responsible only for:
///   1. Acquiring GPS coordinates (with timeout + fallback)
///   2. Firing one emergency broadcast via [CommunicationService]
///
/// GPS failure is non-fatal. Broadcast fires regardless.
class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  /// Fires one emergency broadcast with GPS payload if available.
  ///
  /// Returns true on successful send, false only if the send itself
  /// throws. GPS failure alone does NOT return false.
  Future<bool> fireBroadcast({
    required int broadcastNumber,
    MedicalInfo? medicalInfo,
  }) async {
    try {
      String lat = 'Unknown';
      String lng = 'Unknown';
      String? geoUri;

      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: SosConstants.gpsTimeoutSeconds),
          ),
        );
        lat = pos.latitude.toStringAsFixed(SosConstants.gpsDecimalPrecision);
        lng = pos.longitude.toStringAsFixed(SosConstants.gpsDecimalPrecision);
        geoUri = 'geo:$lat,$lng?q=$lat,$lng(SOS+Emergency)';
        _log.i('[SosService] GPS acquired: $lat, $lng');
      } catch (e) {
        _log.w('[SosService] GPS unavailable — sending without location: $e');
      }

      final parts = <String>['🆘 SOS ALERT #$broadcastNumber'];
      parts.add('Location: $lat, $lng');

      if (medicalInfo != null) {
        if (medicalInfo.name.isNotEmpty) {
          parts.add('Name: ${medicalInfo.name}');
        }
        if (medicalInfo.bloodType.isNotEmpty) {
          parts.add('Blood: ${medicalInfo.bloodType}');
        }
        if (medicalInfo.allergies.isNotEmpty) {
          parts.add('Allergy: ${medicalInfo.allergies}');
        }
        if (medicalInfo.contactName.isNotEmpty) {
          parts.add('Contact: ${medicalInfo.contactName}');
        }
      }

      String payload = parts.join(' | ');

      if (geoUri != null) {
        payload += '\nTap to open offline map:\n$geoUri';
      }

      CommunicationService().sendUserMessage(
        payload,
        Message.broadcastId,
        MessageType.emergency,
        emergencyType: 'GEN',
      );
      _log.i('[SosService] Broadcast #$broadcastNumber sent');
      return true;
    } catch (e) {
      _log.e('[SosService] Broadcast failed: $e');
      return false;
    }
  }
}
