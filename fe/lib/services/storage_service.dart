import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _keyToken = 'auth_token';
  static const _keyUser = 'auth_user';
  static const _keyRememberMe = 'auth_remember';
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyReadAnnouncements = 'read_announcement_ids';
  static const _keyNotificationEnabled = 'notification_enabled';

  static SharedPreferences? _prefs;
  static const _secureStorage = FlutterSecureStorage();

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Token ─────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token,
      {required bool rememberMe}) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyToken, token);
    await prefs.setBool(_keyRememberMe, rememberMe);
  }

  static Future<String?> getToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyToken);
  }

  /// Cek raw apakah ada token tersimpan, tanpa side-effect.
  /// Berbeda dari [getToken] yang mengembalikan nilai token — ini cuma cek
  /// "user pernah login" untuk membedakan 401 sesi-habis vs 401 kredensial-salah.
  static Future<bool> hasStoredToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyToken) != null;
  }

  static Future<void> removeToken() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRememberMe);
  }

  // ── User ──────────────────────────────────────────────────────────────────
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyUser, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyUser);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> removeUser() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyUser);
  }

  // ── Clear semua ───────────────────────────────────────────────────────────
  static Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyRememberMe);
  }

  // ── Cek login ─────────────────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // ── Biometric Login ───────────────────────────────────────────────────────
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    if (!enabled) {
      await clearBiometricCredentials();
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<void> saveBiometricCredentials(
      String loginId, String password) async {
    await _secureStorage.write(key: 'biometric_login_id', value: loginId);
    await _secureStorage.write(key: 'biometric_password', value: password);
  }

  static Future<Map<String, String>?> getBiometricCredentials() async {
    final loginId = await _secureStorage.read(key: 'biometric_login_id');
    final password = await _secureStorage.read(key: 'biometric_password');
    if (loginId != null && password != null) {
      return {'loginId': loginId, 'password': password};
    }
    return null;
  }

  static Future<void> clearBiometricCredentials() async {
    await _secureStorage.delete(key: 'biometric_login_id');
    await _secureStorage.delete(key: 'biometric_password');
  }

  // ── Announcement Read Tracking ───────────────────────────────────────────
  static Future<String> _announcementReadKey() async {
    final user = await getUser();
    final userId = user?['id']?.toString();
    if (userId == null || userId.isEmpty) return _keyReadAnnouncements;
    return '${_keyReadAnnouncements}_$userId';
  }

  static Future<void> markAnnouncementRead(String id) async {
    final prefs = await _getPrefs();
    final key = await _announcementReadKey();
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(key, list);
    }
  }

  static Future<bool> isAnnouncementRead(String id) async {
    final prefs = await _getPrefs();
    final key = await _announcementReadKey();
    final list = prefs.getStringList(key) ?? [];
    return list.contains(id);
  }

  // ── Push Notification ─────────────────────────────────────────────────────
  static Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyNotificationEnabled, enabled);
  }

  static Future<bool> isNotificationEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyNotificationEnabled) ?? true;
  }
}
