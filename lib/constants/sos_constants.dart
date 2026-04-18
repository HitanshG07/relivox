/// SOS broadcast configuration constants.
/// All numeric values are defined here to eliminate magic numbers
/// across sos_bloc.dart and sos_service.dart.
class SosConstants {
  SosConstants._(); // Prevent instantiation

  /// Time in seconds between consecutive SOS broadcasts.
  static const int broadcastIntervalSeconds = 60;

  /// Maximum number of broadcasts before SOS auto-pauses.
  static const int maxBroadcasts = 5;

  /// GPS capture timeout in seconds.
  static const int gpsTimeoutSeconds = 5;

  /// Decimal places for GPS coordinate string formatting.
  /// 6 decimal places ≈ 11 cm accuracy.
  static const int gpsDecimalPrecision = 6;

  /// Emergency message TTL (hops before expiry).
  static const int emergencyTtl = 8;

  /// Timer tick interval in milliseconds (1-second countdown).
  static const int countdownTickMs = 1000;
}
