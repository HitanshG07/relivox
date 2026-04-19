import 'dart:convert';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Singleton service for voice recording and playback.
/// Used by Push-to-Talk in ChatScreen (Phase 10).
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _currentRecordingPath;

  /// Starts recording to a temp file.
  Future<void> startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${dir.path}/relivox_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _currentRecordingPath!,
      );
      _log.i('[VoiceService] Recording started: $_currentRecordingPath');
    } catch (e) {
      _log.e('[VoiceService] startRecording failed: $e');
    }
  }

  /// Stops recording and returns the audio as a base64 string.
  /// Returns null if recording failed or file is missing.
  Future<String?> stopRecordingAsBase64() async {
    try {
      final path = await _recorder.stop();
      if (path == null) return null;
      final file = File(path);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      _log.i('[VoiceService] Encoded ${bytes.length} bytes to base64');
      return b64;
    } catch (e) {
      _log.e('[VoiceService] stopRecordingAsBase64 failed: $e');
      return null;
    }
  }

  /// Decodes base64 audio and plays it.
  Future<void> playBase64Audio(String b64) async {
    try {
      final bytes = base64Decode(b64);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/relivox_play_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final file = File(path);
      await file.writeAsBytes(bytes);
      await _player.setFilePath(path);
      await _player.play();
      _log.i('[VoiceService] Playing audio from $path');
    } catch (e) {
      _log.e('[VoiceService] playBase64Audio failed: $e');
    }
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
