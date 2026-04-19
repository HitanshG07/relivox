import 'package:flutter/material.dart';
import '../../services/voice_service.dart';

/// Renders a voice message bubble with a play button.
/// Used in ChatScreen when message.payload.startsWith('voice:').
class VoiceMessageBubble extends StatelessWidget {
  /// The raw base64 audio data (payload after stripping 'voice:' prefix).
  final String base64Audio;
  final bool isOwn;

  const VoiceMessageBubble({
    super.key,
    required this.base64Audio,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic, size: 18, color: Colors.white70),
        const SizedBox(width: 6),
        const Text(
          'Voice message',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon:
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => VoiceService().playBase64Audio(base64Audio),
        ),
      ],
    );
  }
}
