// lib/services/encryption_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// AES-256-GCM symmetric encryption for Relivox mesh payloads.
///
/// Design:
///   - One shared 256-bit key derived once at app start via PBKDF2
///   - Each encrypt() call generates a fresh 12-byte random nonce
///   - Wire format: base64( nonce[12] + ciphertext + mac[16] )
///   - Decryption is the reverse — split, verify MAC, return plaintext
///   - If decryption fails (wrong key or tampered packet) returns null
///     and the message is silently dropped
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static const _kPassphrase = 'relivox-mesh-v1-shared-secret';
  static const _kSalt       = 'relivox-pbkdf2-salt-v1';
  static const _kIterations = 100000;

  final _aesGcm = AesGcm.with256bits();
  SecretKey? _meshKey;

  /// Must be called once at app startup before any send/receive.
  Future<void> init() async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kIterations,
      bits: 256,
    );
    _meshKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(_kPassphrase)),
      nonce: utf8.encode(_kSalt),
    );
  }

  /// Encrypts [plaintext] string.
  /// Returns base64-encoded wire string: nonce(12) + ciphertext + mac(16)
  Future<String> encrypt(String plaintext) async {
    assert(_meshKey != null, 'EncryptionService.init() not called');
    final nonce = _randomNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: _meshKey!,
      nonce: nonce,
    );
    // Concatenate: nonce + ciphertext + mac
    final combined = Uint8List(
      nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    combined.setRange(0, nonce.length, nonce);
    combined.setRange(
        nonce.length,
        nonce.length + secretBox.cipherText.length,
        secretBox.cipherText);
    combined.setRange(
        nonce.length + secretBox.cipherText.length,
        combined.length,
        secretBox.mac.bytes);
    return base64Encode(combined);
  }

  /// Decrypts a base64 wire string produced by [encrypt].
  /// Returns null if decryption fails (bad key, corrupted packet).
  Future<String?> decrypt(String wireBase64) async {
    assert(_meshKey != null, 'EncryptionService.init() not called');
    try {
      final combined = base64Decode(wireBase64);
      if (combined.length < 28) return null; // 12 nonce + 16 mac minimum
      final nonce       = combined.sublist(0, 12);
      final mac         = Mac(combined.sublist(combined.length - 16));
      final cipherText  = combined.sublist(12, combined.length - 16);
      final secretBox   = SecretBox(cipherText, nonce: nonce, mac: mac);
      final plainBytes  = await _aesGcm.decrypt(
        secretBox,
        secretKey: _meshKey!,
      );
      return utf8.decode(plainBytes);
    } catch (_) {
      return null; // tampered or wrong key — drop silently
    }
  }

  List<int> _randomNonce() {
    final rng = Random.secure();
    return List<int>.generate(12, (_) => rng.nextInt(256));
  }
}
