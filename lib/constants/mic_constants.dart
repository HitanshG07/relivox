/// Keys and limits for Medical Info Card feature.
class MicConstants {
  MicConstants._();

  // SharedPreferences keys
  static const String keyName = 'mic_name';
  static const String keyBloodType = 'mic_blood_type';
  static const String keyAllergies = 'mic_allergies';
  static const String keyContactName = 'mic_contact_name';
  static const String keyContactPhone = 'mic_contact_phone';
  static const String keyNotes = 'mic_notes';

  // Field limits
  static const int maxNameLength = 64;
  static const int maxContactLength = 64;
  static const int maxNotesLength = 512;

  // Dropdown values
  static const List<String> bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
}
