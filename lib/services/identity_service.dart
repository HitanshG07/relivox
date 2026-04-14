import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Manages the persistent pseudonymous identity of this device.
/// Generates a UUID-based display name on first run.
/// Generates Ed25519 key pairs for message signing.
/// All sensitive material is stored in the Android Keystore via flutter_secure_storage.
class IdentityService {
  static const _kDeviceId = 'relivox_device_id';
  static const _kDisplayName = 'relivox_display_name';
  static const _kSignKeyPrivate = 'relivox_sign_key_private';
  static const _kSignKeyPublic = 'relivox_sign_key_public';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _ed25519 = Ed25519();

  String _deviceId = "";
  String _displayName = "Loading...";
  late String _publicKeyBase64;
  late SimpleKeyPair _keyPair;

  String get deviceId => _deviceId;
  String get displayName => _displayName;
  String get publicKeyBase64 => _publicKeyBase64;

  Future<void> init() async {
    // Load or create device ID
    _deviceId = await _storage.read(key: _kDeviceId) ?? _generateAndSaveId();
    _displayName =
        await _storage.read(key: _kDisplayName) ?? await _createDisplayName();

    // Load or create Ed25519 signing key pair
    final privKeyB64 = await _storage.read(key: _kSignKeyPrivate);
    final pubKeyB64 = await _storage.read(key: _kSignKeyPublic);

    if (privKeyB64 != null && pubKeyB64 != null) {
      final privBytes = base64Decode(privKeyB64);
      _keyPair = await _ed25519.newKeyPairFromSeed(privBytes);
      _publicKeyBase64 = pubKeyB64;
    } else {
      _keyPair = await _ed25519.newKeyPair();
      final privSeed = await _keyPair.extractPrivateKeyBytes();
      final pubKey = await _keyPair.extractPublicKey();
      final pubBytes = pubKey.bytes;
      await _storage.write(
          key: _kSignKeyPrivate, value: base64Encode(privSeed));
      await _storage.write(key: _kSignKeyPublic, value: base64Encode(pubBytes));
      _publicKeyBase64 = base64Encode(pubBytes);
    }
    _log.i('Identity loaded: $_deviceId ($_displayName)');
  }

  String _generateAndSaveId() {
    final id = const Uuid().v4();
    _storage.write(key: _kDeviceId, value: id);
    return id;
  }

  Future<String> _createDisplayName() async {
    // Derive short readable name from last 4 hex chars of UUID
    final name =
        'Device-${_deviceId.substring(_deviceId.length - 4).toUpperCase()}';
    await _storage.write(key: _kDisplayName, value: name);
    return name;
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name;
    await _storage.write(key: _kDisplayName, value: name);
  }

  /// Signs [data] with this device's Ed25519 private key.
  Future<String> sign(List<int> data) async {
    final sig = await _ed25519.sign(data, keyPair: _keyPair);
    return base64Encode(sig.bytes);
  }

  /// Verifies [sigBase64] against [data] using [pubKeyBase64].
  Future<bool> verify(
      List<int> data, String sigBase64, String pubKeyBase64) async {
    try {
      final pubKey = SimplePublicKey(base64Decode(pubKeyBase64),
          type: KeyPairType.ed25519);
      final sig = Signature(base64Decode(sigBase64), publicKey: pubKey);
      return await _ed25519.verify(data, signature: sig);
    } catch (e) {
      _log.w('Verify failed: $e');
      return false;
    }
  }
}
