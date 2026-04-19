import 'package:equatable/equatable.dart';
import '../../models/medical_info.dart';

enum MicStatus { initial, loading, loaded, saving, saved, error }

class MicState extends Equatable {
  final MicStatus status;
  final MedicalInfo info;
  final String? errorMessage;

  const MicState({
    this.status = MicStatus.initial,
    this.info = const MedicalInfo(),
    this.errorMessage,
  });

  MicState copyWith({
    MicStatus? status,
    MedicalInfo? info,
    String? errorMessage,
  }) =>
      MicState(
        status: status ?? this.status,
        info: info ?? this.info,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, info, errorMessage];
}
