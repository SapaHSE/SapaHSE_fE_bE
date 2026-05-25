import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'storage_service.dart';

class OfflineCacheGroups {
  OfflineCacheGroups._();

  static const reports = 'reports';
  static const inbox = 'inbox';
  static const news = 'news';
  static const announcements = 'announcements';
  static const profile = 'profile';
  static const references = 'references';
  static const reportDetail = 'report_detail';
}

class OfflineCacheEntry {
  final dynamic payload;
  final DateTime savedAt;
  final String group;
  final String endpoint;
  final String userId;

  const OfflineCacheEntry({
    required this.payload,
    required this.savedAt,
    required this.group,
    required this.endpoint,
    required this.userId,
  });
}

class OfflineCacheService {
  OfflineCacheService._();

  static const _boxName = 'api_response_cache_v1';
  static const staleAfter = Duration(minutes: 15);

  static Box<dynamic>? _box;

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.initFlutter();
      _box = await Hive.openBox<dynamic>(_boxName);
    } else {
      _box = Hive.box<dynamic>(_boxName);
    }
  }

  static Future<Box<dynamic>> _cacheBox() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    return _box!;
  }

  static Future<String> _currentUserId() async {
    final user = await StorageService.getUser();
    final id = user?['id']?.toString().trim();
    return id == null || id.isEmpty ? 'anonymous' : id;
  }

  static String _key({
    required String userId,
    required String method,
    required String endpoint,
  }) {
    return '$userId|${method.toUpperCase()}|$endpoint';
  }

  static Future<void> saveGet({
    required String endpoint,
    required dynamic payload,
    required String group,
  }) async {
    final box = await _cacheBox();
    final userId = await _currentUserId();
    final key = _key(userId: userId, method: 'GET', endpoint: endpoint);
    await box.put(key, <String, dynamic>{
      'payload': jsonEncode(payload),
      'saved_at': DateTime.now().toIso8601String(),
      'group': group,
      'endpoint': endpoint,
      'method': 'GET',
      'user_id': userId,
    });
  }

  static Future<OfflineCacheEntry?> loadGet(String endpoint) async {
    final box = await _cacheBox();
    final userId = await _currentUserId();
    final key = _key(userId: userId, method: 'GET', endpoint: endpoint);
    final raw = box.get(key);
    if (raw is! Map) return null;

    try {
      final payloadRaw = raw['payload'];
      final payload = payloadRaw is String ? jsonDecode(payloadRaw) : payloadRaw;
      final savedAt = DateTime.tryParse(raw['saved_at']?.toString() ?? '');
      if (savedAt == null) return null;

      return OfflineCacheEntry(
        payload: payload,
        savedAt: savedAt,
        group: raw['group']?.toString() ?? '',
        endpoint: raw['endpoint']?.toString() ?? endpoint,
        userId: raw['user_id']?.toString() ?? userId,
      );
    } catch (_) {
      await box.delete(key);
      return null;
    }
  }

  static Future<bool> hasFreshGroup(String group) async {
    final savedAt = await newestSavedAt(group: group);
    if (savedAt == null) return false;
    return DateTime.now().difference(savedAt) < staleAfter;
  }

  static Future<bool> isGroupStale(String group) async {
    return !await hasFreshGroup(group);
  }

  static Future<DateTime?> newestSavedAt({String? group}) async {
    final box = await _cacheBox();
    final userId = await _currentUserId();
    DateTime? newest;

    for (final value in box.values) {
      if (value is! Map) continue;
      if (value['user_id']?.toString() != userId) continue;
      if (group != null && value['group']?.toString() != group) continue;
      final savedAt = DateTime.tryParse(value['saved_at']?.toString() ?? '');
      if (savedAt == null) continue;
      if (newest == null || savedAt.isAfter(newest)) {
        newest = savedAt;
      }
    }

    return newest;
  }

  static Future<void> clearGroup(String group) async {
    final box = await _cacheBox();
    final userId = await _currentUserId();
    final keys = <dynamic>[];

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map) continue;
      if (value['user_id']?.toString() == userId &&
          value['group']?.toString() == group) {
        keys.add(key);
      }
    }

    await box.deleteAll(keys);
  }

  static Future<void> clearCurrentUserCache() async {
    final box = await _cacheBox();
    final userId = await _currentUserId();
    final keys = <dynamic>[];

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map && value['user_id']?.toString() == userId) {
        keys.add(key);
      }
    }

    await box.deleteAll(keys);
  }

  static Future<void> clearAll() async {
    final box = await _cacheBox();
    await box.clear();
  }
}
