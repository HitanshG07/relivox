/// ACK system constants for SOS delivery confirmation.
class AckConstants {
  AckConstants._();

  /// ACK message TTL — low to avoid flooding the mesh
  static const int ACK_TTL = 4;

  /// ACK payload prefix
  static const String ACK_PREFIX = 'ACK:';

  /// ACK payload separator between fields
  static const String ACK_SEPARATOR = ':';

  /// Expected number of parts in a parsed ACK payload
  static const int ACK_PAYLOAD_PARTS = 3;

  /// Index of original message ID in split ACK payload
  static const int ACK_MSG_ID_INDEX = 1;

  /// Index of hop count in split ACK payload
  static const int ACK_HOP_INDEX = 2;
}
