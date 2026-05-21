import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/session_expired_dialog.dart';
import 'storage_service.dart';

class IdleTimeoutService {
  IdleTimeoutService._();
  static final IdleTimeoutService instance = IdleTimeoutService._();

  static const Duration _idleTimeout = Duration(minutes: 3);
  static const Duration _tickInterval = Duration(seconds: 15);
  static const Duration _persistThrottle = Duration(seconds: 5);
  static const String _kLastActivityKey = 'idle_last_activity';

  Timer? _ticker;
  DateTime _lastActivity = DateTime.now();
  DateTime _lastPersisted = DateTime.fromMillisecondsSinceEpoch(0);
  bool _active = false;

  bool get isActive => _active;

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('auth_remember') ?? false;
    if (rememberMe) {
      // Filosofi: remember-me = sesi panjang, tanpa idle-check.
      await _clearPersisted(prefs);
      return;
    }

    _lastActivity = DateTime.now();
    _lastPersisted = _lastActivity;
    await prefs.setInt(
        _kLastActivityKey, _lastActivity.millisecondsSinceEpoch);

    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
    _active = true;
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _active = false;
    final prefs = await SharedPreferences.getInstance();
    await _clearPersisted(prefs);
  }

  void recordActivity() {
    if (!_active) return;
    final now = DateTime.now();
    _lastActivity = now;
    if (now.difference(_lastPersisted) >= _persistThrottle) {
      _lastPersisted = now;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_kLastActivityKey, now.millisecondsSinceEpoch);
      });
    }
  }

  /// Cek saat app resume dari background.
  /// Return true kalau idle sudah lewat batas — caller harus trigger dialog.
  Future<bool> checkOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('auth_remember') ?? false;
    if (rememberMe) return false;

    final lastMs = prefs.getInt(_kLastActivityKey);
    if (lastMs == null) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final diff = DateTime.now().difference(last);
    if (diff >= _idleTimeout) {
      await _triggerTimeout();
      return true;
    }
    // Sinkronkan state in-memory dengan timestamp persistent.
    _lastActivity = last;
    return false;
  }

  void _tick() {
    if (!_active) return;
    final diff = DateTime.now().difference(_lastActivity);
    if (diff >= _idleTimeout) {
      _triggerTimeout();
    }
  }

  Future<void> _triggerTimeout() async {
    await stop();
    await StorageService.clear();
    await showSessionExpiredDialog();
  }

  Future<void> _clearPersisted(SharedPreferences prefs) async {
    await prefs.remove(_kLastActivityKey);
  }
}
