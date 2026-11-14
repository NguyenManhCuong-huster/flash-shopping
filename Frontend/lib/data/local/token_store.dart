import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu access/refresh token trong kho bảo mật của thiết bị
/// (EncryptedSharedPreferences trên Android, Keychain trên iOS) - NFR12.
class TokenStore {
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessCache;
  String? _refreshCache;

  Future<void> load() async {
    try {
      _accessCache = await _storage.read(key: _access);
      _refreshCache = await _storage.read(key: _refresh);
    } catch (e) {
      // Secure storage không khả dụng trên thiết bị này (ví dụ Android emulator không có keystore)
      debugPrint('TokenStore.load error: $e');
      _accessCache = null;
      _refreshCache = null;
    }
  }

  String? get accessToken => _accessCache;
  String? get refreshToken => _refreshCache;
  bool get hasSession => _refreshCache != null;

  Future<void> save(String access, String refresh) async {
    _accessCache = access;
    _refreshCache = refresh;
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
  }

  Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}
