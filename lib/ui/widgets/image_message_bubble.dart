import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Renders a received image message decoded from base64.
/// Used in _MessageBubble when payload starts with 'image:'.
class ImageMessageBubble extends StatelessWidget {
  final String base64Image;
  final bool isOwn;

  const ImageMessageBubble({
    super.key,
    required this.base64Image,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final Uint8List bytes = base64Decode(base64Image);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image,
            color: Colors.white38,
            size: 48,
          ),
        ),
      );
    } catch (_) {
      return const Icon(
        Icons.broken_image,
        color: Colors.white38,
        size: 48,
      );
    }
  }
}
