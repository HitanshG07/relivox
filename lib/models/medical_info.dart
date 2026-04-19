import 'package:equatable/equatable.dart';

/// Immutable model for a user's personal medical profile.
class MedicalInfo extends Equatable {
  final String name;
  final String bloodType;
  final String allergies;
  final String contactName;
  final String contactPhone;
  final String notes;

  const MedicalInfo({
    this.name = '',
    this.bloodType = '',
    this.allergies = '',
    this.contactName = '',
    this.contactPhone = '',
    this.notes = '',
  });

  bool get isEmpty =>
      name.isEmpty &&
      bloodType.isEmpty &&
      allergies.isEmpty &&
      contactName.isEmpty &&
      contactPhone.isEmpty;

  MedicalInfo copyWith({
    String? name,
    String? bloodType,
    String? allergies,
    String? contactName,
    String? contactPhone,
    String? notes,
  }) =>
      MedicalInfo(
        name: name ?? this.name,
        bloodType: bloodType ?? this.bloodType,
        allergies: allergies ?? this.allergies,
        contactName: contactName ?? this.contactName,
        contactPhone: contactPhone ?? this.contactPhone,
        notes: notes ?? this.notes,
      );

  @override
  List<Object?> get props => [
        name,
        bloodType,
        allergies,
        contactName,
        contactPhone,
        notes,
      ];
}
