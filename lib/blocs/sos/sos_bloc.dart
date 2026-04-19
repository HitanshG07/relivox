import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/ack_constants.dart';
import '../../constants/sos_constants.dart';
import '../../services/communication_service.dart' hide AckReceivedEvent;
import '../../models/message.dart';
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
  final CommunicationService _comm;
  Timer? _tickTimer;
  StreamSubscription<Message>? _commSubscription;

  SosBloc({
    SosService? sosService,
    required MicBloc mic,
    required CommunicationService comm,
  })  : _sos = sosService ?? SosService(),
        _mic = mic,
        _comm = comm,
        super(const SosState()) {
    on<SosActivateEvent>(_onActivate);
    on<SosCancelEvent>(_onCancel);
    on<SosExtendEvent>(_onExtend);
    on<SosTickEvent>(_onTick);
    on<SosBroadcastEvent>(_onBroadcast);
    on<AckReceivedEvent>(_onAckReceived);
  }

  Future<void> _onActivate(SosActivateEvent e, Emitter<SosState> emit) async {
    if (state.status == SosStatus.active) return;
    _cancelTimer();
    emit(state.copyWith(
      status: SosStatus.active,
      broadcastCount: 0,
      secondsRemaining: SosConstants.broadcastIntervalSeconds,
    ));
    _startCommSubscription();
    add(const SosBroadcastEvent());
    _startTimer();
  }

  void _onCancel(SosCancelEvent e, Emitter<SosState> emit) {
    _cancelTimer();
    _cancelCommSubscription();
    emit(const SosState());
  }

  Future<void> _onExtend(SosExtendEvent e, Emitter<SosState> emit) async {
    _cancelTimer();
    // FIX-9: Do NOT reset broadcastCount. Extend grants 5 more broadcasts
    // from the current count, preventing unlimited extend abuse.
    final newMax = (state.extendedMaxBroadcasts ?? SosConstants.maxBroadcasts)
        + SosConstants.maxBroadcasts;
    emit(state.copyWith(
      status: SosStatus.active,
      secondsRemaining: SosConstants.broadcastIntervalSeconds,
      extendedMaxBroadcasts: newMax,
    ));
    _startCommSubscription();
    add(const SosBroadcastEvent());
    _startTimer();
  }

  void _onTick(SosTickEvent e, Emitter<SosState> emit) {
    if (state.status != SosStatus.active) return;
    final next = state.secondsRemaining - 1;
    if (next <= 0) {
      final effectiveMax =
          state.extendedMaxBroadcasts ?? SosConstants.maxBroadcasts;
      if (state.broadcastCount < effectiveMax) {
        emit(state.copyWith(
            secondsRemaining: SosConstants.broadcastIntervalSeconds));
        add(const SosBroadcastEvent());
      } else {
        add(const SosBroadcastEvent()); // triggers paused emit
      }
    } else {
      emit(state.copyWith(secondsRemaining: next));
    }
  }

  Future<void> _onBroadcast(SosBroadcastEvent e, Emitter<SosState> emit) async {
    final newCount = state.broadcastCount + 1;
    // FIX-1/3: fireBroadcast now returns the message ID directly,
    // eliminating the race condition from reading _comm.lastSentMessageId.
    final msgId = await _sos.fireBroadcast(
      broadcastNumber: newCount,
      medicalInfo: _mic.state.info.isEmpty ? null : _mic.state.info,
    );
    final effectiveMax = state.extendedMaxBroadcasts ?? SosConstants.maxBroadcasts;
    if (newCount >= effectiveMax) {
      _cancelTimer();
      emit(state.copyWith(
        status: SosStatus.paused,
        broadcastCount: newCount,
        secondsRemaining: 0,
        currentSosMessageId: msgId,
      ));
    } else {
      emit(state.copyWith(
        broadcastCount: newCount,
        currentSosMessageId: msgId,
      ));
    }
  }

  void _onAckReceived(AckReceivedEvent event, Emitter<SosState> emit) {
    // FIX-7: Accept ACKs in both active AND paused states.
    // Late ACKs for the 5th broadcast arrive after status = paused.
    if (state.status == SosStatus.inactive) return;
    emit(state.copyWith(
      ackCount: state.ackCount + 1,
      maxHops: event.hopCount > state.maxHops ? event.hopCount : state.maxHops,
    ));
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

  void _startCommSubscription() {
    _cancelCommSubscription();
    _commSubscription = _comm.incomingMessages.listen((msg) {
      if (msg.type == MessageType.ack &&
          msg.payload.startsWith(AckConstants.ACK_PREFIX)) {
        final parts = msg.payload.split(AckConstants.ACK_SEPARATOR);
        if (parts.length == AckConstants.ACK_PAYLOAD_PARTS) {
          final msgId = parts[AckConstants.ACK_MSG_ID_INDEX];
          final hops = int.tryParse(parts[AckConstants.ACK_HOP_INDEX]) ?? 0;
          if (msgId == state.currentSosMessageId) {
            add(AckReceivedEvent(hops));
          }
        }
      }
    });
  }

  void _cancelCommSubscription() {
    _commSubscription?.cancel();
    _commSubscription = null;
  }

  @override
  Future<void> close() {
    _cancelTimer();
    _cancelCommSubscription();
    return super.close();
  }
}
