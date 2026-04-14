import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/message.dart';
import '../../services/communication_service.dart';
import '../../services/database_service.dart';
import '../../services/identity_service.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAllMessages extends ChatEvent {}

class SendTextMessage extends ChatEvent {
  final String text;
  SendTextMessage(this.text);
  @override
  List<Object?> get props => [text];
}

class SendEmergencyBroadcast extends ChatEvent {
  final String text;
  SendEmergencyBroadcast(this.text);
  @override
  List<Object?> get props => [text];
}

class _IncomingMessage extends ChatEvent {
  final Message message;
  _IncomingMessage(this.message);
  @override
  List<Object?> get props => [message.id];
}

class _MessageAcked extends ChatEvent {
  final String messageId;
  _MessageAcked(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

// ── State ────────────────────────────────────────────────────────────────────

class ChatState extends Equatable {
  final List<Message> messages;
  final bool isLoading;

  const ChatState({this.messages = const [], this.isLoading = false});

  ChatState copyWith({List<Message>? messages, bool? isLoading}) => ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [messages, isLoading];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final CommunicationService _comm;
  final DatabaseService _db;
  final IdentityService _identity;
  StreamSubscription<P2PEvent>? _sub;

  // Monotonically-increasing sequence number per device session
  int _seq = 0;

  ChatBloc(this._comm, this._db, this._identity) : super(const ChatState()) {
    on<LoadAllMessages>(_onLoad);
    on<SendTextMessage>(_onSendText);
    on<SendEmergencyBroadcast>(_onEmergency);
    on<_IncomingMessage>(_onIncoming);
    on<_MessageAcked>(_onAcked);

    _sub = _comm.events.listen(_routeEvent);
  }

  void _routeEvent(P2PEvent event) {
    if (event is MessageReceivedEvent) add(_IncomingMessage(event.message));
    if (event is AckReceivedEvent) add(_MessageAcked(event.ackedMessageId));
  }

  // ── Handlers ─────────────────────────────────────────────────────────────

  Future<void> _onLoad(LoadAllMessages e, Emitter<ChatState> emit) async {
    emit(state.copyWith(isLoading: true));
    final msgs = await _db.getAllMessages();
    emit(state.copyWith(messages: msgs, isLoading: false));
  }

  Future<void> _onSendText(SendTextMessage e, Emitter<ChatState> emit) async {
    final msg = Message.create(
      senderId: _identity.deviceId,
      senderPubKey: _identity.publicKeyBase64,
      payload: e.text,
      type: MessageType.text,
      priority: MessagePriority.normal,
      ttl: 5,
      seq: _seq++,
    );
    await _comm.broadcastMessage(msg);
    add(LoadAllMessages());
  }

  Future<void> _onEmergency(SendEmergencyBroadcast e, Emitter<ChatState> emit) async {
    final msg = Message.create(
      senderId: _identity.deviceId,
      senderPubKey: _identity.publicKeyBase64,
      payload: e.text,
      type: MessageType.emergency,
      priority: MessagePriority.high,
      ttl: 7, // Extra hops for emergency
      seq: _seq++,
    );
    await _comm.broadcastMessage(msg);
    add(LoadAllMessages());
  }

  void _onIncoming(_IncomingMessage e, Emitter<ChatState> emit) {
    // Insert into in-memory list immediately for real-time feel,
    // avoiding a full DB reload on every received message.
    final existing = state.messages;
    final alreadyExists = existing.any((m) => m.id == e.message.id);
    if (!alreadyExists) {
      final updated = [e.message, ...existing];
      emit(state.copyWith(messages: updated));
    }
  }

  void _onAcked(_MessageAcked e, Emitter<ChatState> emit) {
    final updated = state.messages.map((m) {
      if (m.id == e.messageId) return m.copyWith(deliveryStatus: DeliveryStatus.acked);
      return m;
    }).toList();
    emit(state.copyWith(messages: updated));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
