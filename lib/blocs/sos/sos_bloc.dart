import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/sos_constants.dart';
import '../../services/sos_service.dart';
import 'sos_event.dart';
import 'sos_state.dart';

import '../mic/mic_bloc.dart';

/// Manages the SOS panic button state machine.
///
/// State transitions:
///   INACTIVE → [SosActivateEvent]  → ACTIVE
///   ACTIVE   → [SosCancelEvent]    → INACTIVE
///   ACTIVE   → [5 broadcasts done] → PAUSED
///   PAUSED   → [SosExtendEvent]    → ACTIVE
///   PAUSED   → [SosCancelEvent]    → INACTIVE
class SosBloc extends Bloc<SosEvent, SosState> {
  final SosService _sos;
  final MicBloc _mic;
  Timer? _tickTimer;

  SosBloc({SosService? sosService, required MicBloc mic})
      : _sos = sosService ?? SosService(),
        _mic = mic,
        super(const SosState()) {
    on<SosActivateEvent>(_onActivate);
    on<SosCancelEvent>(_onCancel);
    on<SosExtendEvent>(_onExtend);
    on<SosTickEvent>(_onTick);
    on<SosBroadcastEvent>(_onBroadcast);
  }

  Future<void> _onActivate(SosActivateEvent e, Emitter<SosState> emit) async {
    if (state.status == SosStatus.active) return;
    _cancelTimer();
    emit(state.copyWith(
      status: SosStatus.active,
      broadcastCount: 0,
      secondsRemaining: SosConstants.broadcastIntervalSeconds,
    ));
    add(const SosBroadcastEvent());
    _startTimer();
  }

  void _onCancel(SosCancelEvent e, Emitter<SosState> emit) {
    _cancelTimer();
    emit(const SosState());
  }

  Future<void> _onExtend(SosExtendEvent e, Emitter<SosState> emit) async {
    _cancelTimer();
    emit(state.copyWith(
      status: SosStatus.active,
      broadcastCount: 0,
      secondsRemaining: SosConstants.broadcastIntervalSeconds,
    ));
    add(const SosBroadcastEvent());
    _startTimer();
  }

  void _onTick(SosTickEvent e, Emitter<SosState> emit) {
    if (state.status != SosStatus.active) return;
    final next = state.secondsRemaining - 1;
    if (next <= 0) {
      emit(state.copyWith(
          secondsRemaining: SosConstants.broadcastIntervalSeconds));
      add(const SosBroadcastEvent());
    } else {
      emit(state.copyWith(secondsRemaining: next));
    }
  }

  Future<void> _onBroadcast(SosBroadcastEvent e, Emitter<SosState> emit) async {
    final newCount = state.broadcastCount + 1;
    await _sos.fireBroadcast(
      broadcastNumber: newCount,
      medicalInfo: _mic.state.info.isEmpty ? null : _mic.state.info,
    );
    if (newCount >= SosConstants.maxBroadcasts) {
      _cancelTimer();
      emit(state.copyWith(
        status: SosStatus.paused,
        broadcastCount: newCount,
        secondsRemaining: 0,
      ));
    } else {
      emit(state.copyWith(broadcastCount: newCount));
    }
  }

  void _startTimer() {
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: SosConstants.countdownTickMs),
      (_) => add(const SosTickEvent()),
    );
  }

  void _cancelTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  @override
  Future<void> close() {
    _cancelTimer();
    return super.close();
  }
}
