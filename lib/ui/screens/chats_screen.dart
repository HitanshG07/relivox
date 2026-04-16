import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/chats/chats_bloc.dart';
import '../../models/peer.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsBloc, ChatsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          );
        }

        if (state.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 48,
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text(
                  'No conversations yet',
                  style: TextStyle(color: Colors.white38, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect to a nearby device and start chatting',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: state.conversations.length,
          itemBuilder: (context, i) {
            final conv = state.conversations[i];
            return _ChatTile(summary: conv);
          },
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatSummary summary;
  const _ChatTile({required this.summary});

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isEmergency = summary.isEmergency;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13132B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEmergency
              ? Colors.redAccent.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isEmergency
              ? Colors.redAccent.withValues(alpha: 0.15)
              : const Color(0xFF6C63FF).withValues(alpha: 0.15),
          child: Icon(
            isEmergency ? Icons.warning_amber_rounded : Icons.person_outline,
            color: isEmergency ? Colors.redAccent : const Color(0xFF6C63FF),
          ),
        ),
        title: Text(
          (summary.peerName.isNotEmpty &&
           !summary.peerName.startsWith('Device-'))
              ? summary.peerName
              : 'Unknown User',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            if (isEmergency)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 12),
              ),
            Expanded(
              child: Text(
                summary.lastMessage,
                style: TextStyle(
                  color: isEmergency ? Colors.redAccent : Colors.white38,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Text(
          _formatTime(summary.lastTime),
          style: const TextStyle(color: Colors.white24, fontSize: 10),
        ),
        onTap: () {
          // Build a minimal Peer object from stored data
          // so ChatScreen can open without live discovery
          final peer = Peer(
            endpointId: '',        // empty — peer may be offline
            displayName: summary.peerName,
            deviceId: summary.peerId,
            status: PeerStatus.discovered, // treated as offline
            lastSeen: summary.lastTime.toIso8601String(),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(targetPeer: peer)),
          );
        },
      ),
    );
  }
}
