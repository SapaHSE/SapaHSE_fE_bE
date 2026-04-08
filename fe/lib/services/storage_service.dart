import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles local persistence of auth token and user data.
class StorageService {
  static const _keyToken = 'auth_token';
  static const _keyUser  = 'auth_user';

  // Cached instance — initialized once in main(), reused everywhere
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Token ─────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyToken);
  }

  static Future<void> removeToken() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyToken);
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

  // ── Clear all (logout) ────────────────────────────────────────────────────
  static Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  // ── Check if logged in ────────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(_keyToken);
    return token != null && token.isNotEmpty;
  }
}