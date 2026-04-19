import 'package:equatable/equatable.dart';
import '../../models/medical_info.dart';

abstract class MicEvent extends Equatable {
  const MicEvent();
  @override
  List<Object?> get props => [];
}

/// Load saved medical info from SharedPreferences on startup.
class LoadMicEvent extends MicEvent {
  const LoadMicEvent();
}

/// Save updated medical info to SharedPreferences.
class SaveMicEvent extends MicEvent {
  final MedicalInfo info;
  const SaveMicEvent(this.info);
  @override
  List<Object?> get props => [info];
}
