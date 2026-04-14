import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../models/message.dart';
import '../../models/peer.dart';
import '../../services/identity_service.dart';
import '../../services/communication_service.dart';
import '../../services/database_service.dart';

class ChatScreen extends StatefulWidget {
  final Peer targetPeer;
  const ChatScreen({super.key, required this.targetPeer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        context.read<CommunicationService>(),
        context.read<DatabaseService>(),
        peerDeviceId: widget.targetPeer.deviceId ?? widget.targetPeer.endpointId,
      )..add(LoadAllMessages()),
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF13132B),
            title: Text(widget.targetPeer.displayName,
                style: const TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white70),
          ),
          body: Column(
            children: [
              Expanded(child: _MessageList(scrollController: _scrollController)),
              _InputBar(
                controller: _controller,
                onSend: () => _send(context),
                targetPeer: widget.targetPeer,
              ),
            ],
          ),
        );
      }),
    );
  }

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(SendTextMessage(text));
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scrollController;
  const _MessageList({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final myId = context.read<IdentityService>().deviceId;
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
        }
        if (state.messages.isEmpty) {
          return const Center(
            child: Text('No messages yet.\nSend the first one!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: state.messages.length,
          itemBuilder: (context, i) {
            final msg = state.messages[i];
            if (msg.type == MessageType.ack) return const SizedBox.shrink();
            final isMe = msg.senderId == myId;
            return _MessageBubble(message: msg, isMe: isMe);
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isEmergency = message.type == MessageType.emergency;
    final time = DateFormat('HH:mm').format(message.parsedTimestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              child: Text(
                message.senderId.substring(message.senderId.length - 2).toUpperCase(),
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isEmergency
                    ? Colors.red.withValues(alpha: 0.25)
                    : isMe
                        ? const Color(0xFF4A4A8A)
                        : const Color(0xFF1E1E3A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 14),
                ),
                border: isEmergency
                    ? Border.all(color: Colors.red, width: 1)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEmergency)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 14),
                          SizedBox(width: 4),
                          Text('EMERGENCY',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  Text(message.payload,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                      const SizedBox(width: 6),
                      Text('·${message.hops}hop·TTL${message.ttl}',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 9)),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _DeliveryIcon(status: message.deliveryStatus),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  final DeliveryStatus status;
  const _DeliveryIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DeliveryStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: Colors.white38);
      case DeliveryStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white54);
      case DeliveryStatus.acked:
        return const Icon(Icons.done_all, size: 12, color: Colors.greenAccent);
      case DeliveryStatus.failed:
        return const Icon(Icons.error_outline, size: 12, color: Colors.red);
    }
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Peer targetPeer;
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.targetPeer,
  });

  void _showEmergencyOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '🚨 Send Emergency Alert',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white70),
              title: const Text('👤 PERSONAL', style: TextStyle(color: Colors.white)),
              subtitle: Text('Send to ${targetPeer.displayName} only',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  // Uses the actual peer ID for direct personal emergency
                  await CommunicationService()
                      .sendUserMessage(text, targetPeer.endpointId, MessageType.emergency);
                  if (context.mounted) {
                    context.read<ChatBloc>().add(LoadAllMessages());
                  }
                  controller.clear();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF13132B),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.emergency_share, color: Colors.redAccent),
              onPressed: () => _showEmergencyOptions(context),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E3A),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
