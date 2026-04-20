import 'package:shared_preferences/shared_preferences.dart';

class MedicalService {
  static const String _keyBloodGroup = 'bloodGroup';
  static const String _keyAllergies = 'allergies';
  static const String _keyConditions = 'conditions';
  static const String _keyContactName = 'contactName';
  static const String _keyContactPhone = 'contactPhone';

  static Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'bloodGroup': prefs.getString(_keyBloodGroup) ?? '',
      'allergies': prefs.getString(_keyAllergies) ?? '',
      'conditions': prefs.getString(_keyConditions) ?? '',
      'contactName': prefs.getString(_keyContactName) ?? '',
      'contactPhone': prefs.getString(_keyContactPhone) ?? '',
    };
  }

  static Future<void> save({required Map<String, String> data}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBloodGroup, data['bloodGroup'] ?? '');
    await prefs.setString(_keyAllergies, data['allergies'] ?? '');
    await prefs.setString(_keyConditions, data['conditions'] ?? '');
    await prefs.setString(_keyContactName, data['contactName'] ?? '');
    await prefs.setString(_keyContactPhone, data['contactPhone'] ?? '');
  }

  static Future<String> getMedicalSummary() async {
    final data = await load();
    
    final blood = data['bloodGroup'] ?? '';
    final allergies = data['allergies'] ?? '';
    final conditions = data['conditions'] ?? '';
    final contactName = data['contactName'] ?? '';
    final contactPhone = data['contactPhone'] ?? '';

    if (blood.isEmpty &&
        allergies.isEmpty &&
        conditions.isEmpty &&
        contactName.isEmpty &&
        contactPhone.isEmpty) {
      return '';
    }

    return '🩺 Medical Info:\n'
        'Blood: ${blood.isEmpty ? "Unknown" : blood}  |  '
        'Allergies: ${allergies.isEmpty ? "None" : allergies}  |  '
        'Conditions: ${conditions.isEmpty ? "None" : conditions}\n'
        'Emergency Contact: ${contactName.isEmpty ? "Not set" : contactName} — ${contactPhone.isEmpty ? "N/A" : contactPhone}';
  }
}
