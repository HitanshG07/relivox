import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Singleton service for picking and encoding images for
/// offline mesh transmission (Phase 12).
class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Opens the gallery, compresses the selected image,
  /// and returns a base64-encoded string.
  /// Returns null if user cancels or any error occurs.
  Future<String?> pickAndEncodeImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (file == null) return null;

      final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        quality: 50,
        minWidth: 800,
        minHeight: 800,
        // keepExif removed — not supported in compressWithFile on Android (Sprint 6 Correction)
      );
      if (compressed == null) return null;

      final b64 = base64Encode(compressed);
      _log.i('[ImageService] Encoded ${compressed.length} bytes to base64');
      return b64;
    } catch (e) {
      _log.e('[ImageService] pickAndEncodeImage failed: $e');
      return null;
    }
  }
}
