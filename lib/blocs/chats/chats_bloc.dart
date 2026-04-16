import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/message.dart';
import '../../services/database_service.dart';
import '../../services/communication_service.dart';
import '../../services/identity_service.dart';

// ── Events ────────────────────────────────────────────────────────────────────
abstract class ChatsEvent {}
class LoadChatsEvent extends ChatsEvent {}
class _NewMessageChatsEvent extends ChatsEvent {
  final Message message;
  _NewMessageChatsEvent(this.message);
}

// ── State ─────────────────────────────────────────────────────────────────────
class ChatsState {
  final List<ChatSummary> conversations;
  final bool isLoading;
  const ChatsState({this.conversations = const [], this.isLoading = false});
  ChatsState copyWith({List<ChatSummary>? conversations, bool? isLoading}) =>
      ChatsState(
        conversations: conversations ?? this.conversations,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Model ─────────────────────────────────────────────────────────────────────
class ChatSummary {
  final String peerId;       // deviceId of the other person
  final String peerName;     // display name (last known)
  final String lastMessage;  // last message payload
  final DateTime lastTime;   // timestamp of last message
  final bool isEmergency;    // was it an emergency?
  final int unreadCount;     // placeholder for future use

  const ChatSummary({
    required this.peerId,
    required this.peerName,
    required this.lastMessage,
    required this.lastTime,
    this.isEmergency = false,
    this.unreadCount = 0,
  });
}

// ── BLoC ──────────────────────────────────────────────────────────────────────
class ChatsBloc extends Bloc<ChatsEvent, ChatsState> {
  final DatabaseService _db;
  final CommunicationService _comm;
  final IdentityService _identity;
  StreamSubscription? _messageSub;

  // Cache: peerId → displayName (populated from message history)
  final Map<String, String> _nameCache = {};

  ChatsBloc({
    required DatabaseService db,
    required CommunicationService comm,
    required IdentityService identity,
  })  : _db = db,
        _comm = comm,
        _identity = identity,
        super(const ChatsState(isLoading: true)) {
    on<LoadChatsEvent>(_onLoad);
    on<_NewMessageChatsEvent>(_onNewMessage);

    // Listen for live incoming messages to refresh list
    _messageSub = _comm.events.listen((event) {
      if (event is MessageReceivedEvent &&
          event.message.type != MessageType.ack) {
        add(_NewMessageChatsEvent(event.message));
      }
    });

    add(LoadChatsEvent());
  }

  Future<void> _onLoad(LoadChatsEvent event, Emitter<ChatsState> emit) async {
    emit(state.copyWith(isLoading: true));
    final summaries = await _buildSummaries();
    emit(state.copyWith(conversations: summaries, isLoading: false));
  }

  Future<void> _onNewMessage(
      _NewMessageChatsEvent event, Emitter<ChatsState> emit) async {
    final summaries = await _buildSummaries();
    emit(state.copyWith(conversations: summaries));
  }

  Future<List<ChatSummary>> _buildSummaries() async {
    final myId = _identity.deviceId;
    final allMessages = await _db.getAllMessages();

    // Group messages by conversation partner
    final Map<String, List<Message>> byPeer = {};
    for (final msg in allMessages) {
      if (msg.type == MessageType.ack) continue;
      // Skip pure broadcasts with no sender context
      if (msg.receiverId == '__BROADCAST__' && msg.senderId == myId) {
        // outbound broadcast — group under '__BROADCAST__'
        byPeer.putIfAbsent('__BROADCAST__', () => []).add(msg);
        continue;
      }
      // Determine the peer's ID
      final peerId = msg.senderId == myId ? msg.receiverId : msg.senderId;
      if (peerId.isEmpty) continue;
      byPeer.putIfAbsent(peerId, () => []).add(msg);
    }

    // Build summary list — one entry per peer, sorted newest first
    final List<ChatSummary> result = [];
    for (final entry in byPeer.entries) {
      final peerId = entry.key;
      if (peerId == '__BROADCAST__') continue; // skip broadcasts in chat list
      final msgs = entry.value..sort((a, b) =>
          b.parsedTimestamp.compareTo(a.parsedTimestamp));
      final latest = msgs.first;

      // Name resolution — three levels, first non-null wins:
      // 1. Live in-memory cache (populated by discovery this session)
      // 2. known_peers table in SQLite (survives app restarts — Fix 8)
      // 3. Empty string → UI shows "Unknown User" via Fix 4 filter
      String name = _nameCache[peerId] ?? '';
      if (name.isEmpty) {
        final stored = await _db.getDisplayName(peerId);
        if (stored != null && stored.isNotEmpty) {
          name = stored;
          _nameCache[peerId] = stored; // warm the cache for this session
        }
      }

      result.add(ChatSummary(
        peerId: peerId,
        peerName: name,
        lastMessage: latest.payload,
        lastTime: latest.parsedTimestamp,
        isEmergency: latest.type == MessageType.emergency,
      ));
    }

    // Sort by most recent first
    result.sort((a, b) => b.lastTime.compareTo(a.lastTime));
    return result;
  }

  /// Call this when a peer's real display name becomes known
  /// (e.g. from discovery events) so the Chats list shows proper names.
  void updatePeerName(String peerId, String displayName) {
    _nameCache[peerId] = displayName;
    add(LoadChatsEvent());
  }

  @override
  Future<void> close() {
    _messageSub?.cancel();
    return super.close();
  }
}
