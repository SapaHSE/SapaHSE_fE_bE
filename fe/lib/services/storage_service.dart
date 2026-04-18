import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyToken = 'auth_token';
  static const _keyUser = 'auth_user';
  static const _keyExpiry = 'auth_expiry'; // ← baru
  static const _keyRememberMe = 'auth_remember'; // ← baru

  static SharedPreferences? _prefs;

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

    if (rememberMe) {
      // Sesi selamanya — tidak ada expiry di sisi client.
      await prefs.remove(_keyExpiry);
    } else {
      final expiry = DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String();
      await prefs.setString(_keyExpiry, expiry);
    }
  }

  static Future<String?> getToken() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(_keyToken);
    if (token == null) return null;

    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    if (rememberMe) {
      // Remember me aktif — sesi tidak pernah expired di sisi client.
      return token;
    }

    final expiry = prefs.getString(_keyExpiry);
    if (expiry == null) return null;

    // Cek apakah sesi sudah kadaluarsa
    final expiryDate = DateTime.parse(expiry);
    if (DateTime.now().isAfter(expiryDate)) {
      // Token kadaluarsa — hapus semua
      await clear();
      return null;
    }

    return token;
  }

  static Future<void> removeToken() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyExpiry);
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
    await prefs.remove(_keyExpiry);
    await prefs.remove(_keyRememberMe);
  }

  // ── Cek login + validasi expiry sekaligus ─────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getToken(); // getToken() sudah handle expiry check
    return token != null;
  }

  // ── Sisa waktu sesi (opsional, untuk ditampilkan di UI) ───────────────────
  static Future<Duration?> getRemainingSession() async {
    final prefs = await _getPrefs();

    // Remember me aktif → sesi tidak terbatas, tidak ada countdown.
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    if (rememberMe) return null;

    final expiry = prefs.getString(_keyExpiry);
    if (expiry == null) return null;

    final expiryDate = DateTime.parse(expiry);
    final remaining = expiryDate.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }
}