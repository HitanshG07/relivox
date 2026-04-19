import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/mic_constants.dart';
import '../../models/medical_info.dart';
import 'mic_event.dart';
import 'mic_state.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Manages persistence and state of the user's Medical Info Card.
class MicBloc extends Bloc<MicEvent, MicState> {
  MicBloc() : super(const MicState()) {
    on<LoadMicEvent>(_onLoad);
    on<SaveMicEvent>(_onSave);
  }

  /// Reads all 6 MIC fields from SharedPreferences.
  Future<void> _onLoad(LoadMicEvent event, Emitter<MicState> emit) async {
    emit(state.copyWith(status: MicStatus.loading));
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = MedicalInfo(
        name: prefs.getString(MicConstants.keyName) ?? '',
        bloodType: prefs.getString(MicConstants.keyBloodType) ?? '',
        allergies: prefs.getString(MicConstants.keyAllergies) ?? '',
        contactName: prefs.getString(MicConstants.keyContactName) ?? '',
        contactPhone: prefs.getString(MicConstants.keyContactPhone) ?? '',
        notes: prefs.getString(MicConstants.keyNotes) ?? '',
      );
      emit(state.copyWith(status: MicStatus.loaded, info: info));
      _log.i('[MIC] Loaded: name=${info.name}, blood=${info.bloodType}');
    } catch (e) {
      _log.e('[MIC] Load failed: $e');
      emit(state.copyWith(status: MicStatus.error, errorMessage: e.toString()));
    }
  }

  /// Writes all 6 MIC fields to SharedPreferences.
  Future<void> _onSave(SaveMicEvent event, Emitter<MicState> emit) async {
    emit(state.copyWith(status: MicStatus.saving));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MicConstants.keyName, event.info.name);
      await prefs.setString(MicConstants.keyBloodType, event.info.bloodType);
      await prefs.setString(MicConstants.keyAllergies, event.info.allergies);
      await prefs.setString(
          MicConstants.keyContactName, event.info.contactName);
      await prefs.setString(
          MicConstants.keyContactPhone, event.info.contactPhone);
      await prefs.setString(MicConstants.keyNotes, event.info.notes);
      emit(state.copyWith(status: MicStatus.saved, info: event.info));
      _log.i('[MIC] Saved successfully');
    } catch (e) {
      _log.e('[MIC] Save failed: $e');
      emit(state.copyWith(status: MicStatus.error, errorMessage: e.toString()));
    }
  }
}
