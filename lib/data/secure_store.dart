import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/ids.dart';

/// Small device-bound secrets kept in the Android Keystore / iOS Keychain:
/// the database key, this device's id and a few per-device preferences.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _dbKey = 'db_key_v1';
  static const _deviceId = 'device_id';
  static const _lastUsername = 'last_username';
  static const _themeMode = 'theme_mode';

  /// The 256-bit database key, created on first launch.
  Future<String> databaseKey() async {
    final existing = await _storage.read(key: _dbKey);
    if (existing != null) return existing;
    final r = Random.secure();
    final key = List<int>.generate(
      32,
      (_) => r.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _dbKey, value: key);
    return key;
  }

  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceId);
    if (existing != null) return existing;
    final id = newId();
    await _storage.write(key: _deviceId, value: id);
    return id;
  }

  Future<String?> lastUsername() => _storage.read(key: _lastUsername);
  Future<void> setLastUsername(String username) =>
      _storage.write(key: _lastUsername, value: username);

  /// Small per-phone settings (phone name, last batch export, reminders).
  Future<String?> pref(String key) => _storage.read(key: 'pref_$key');
  Future<void> setPref(String key, String? value) => value == null
      ? _storage.delete(key: 'pref_$key')
      : _storage.write(key: 'pref_$key', value: value);

  Future<String?> themeMode() => _storage.read(key: _themeMode);
  Future<void> setThemeMode(String mode) =>
      _storage.write(key: _themeMode, value: mode);
}
