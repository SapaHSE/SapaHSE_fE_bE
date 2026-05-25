import '../models/inbox_item.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';

class InboxListResult {
  final bool success;
  final List<InboxItem> items;
  final int unreadPersonal;
  final int unreadAnnouncements;
  final int unreadTotal;
  final int currentPage;
  final int lastPage;
  final bool hasMore;
  final String? errorMessage;

  InboxListResult._({
    required this.success,
    this.items = const [],
    this.unreadPersonal = 0,
    this.unreadAnnouncements = 0,
    this.unreadTotal = 0,
    this.currentPage = 1,
    this.lastPage = 1,
    this.hasMore = false,
    this.errorMessage,
  });

  factory InboxListResult.success({
    required List<InboxItem> items,
    required int unreadPersonal,
    required int unreadAnnouncements,
    required int unreadTotal,
    required int currentPage,
    required int lastPage,
    required bool hasMore,
  }) =>
      InboxListResult._(
        success: true,
        items: items,
        unreadPersonal: unreadPersonal,
        unreadAnnouncements: unreadAnnouncements,
        unreadTotal: unreadTotal,
        currentPage: currentPage,
        lastPage: lastPage,
        hasMore: hasMore,
      );

  factory InboxListResult.error(String message) =>
      InboxListResult._(success: false, errorMessage: message);
}

class InboxService {
  /// [type] = 'personal' (reports) or 'announcement'.
  /// [isRead] = null → all, true → read only, false → unread only.
  static Future<InboxListResult> fetchInbox({
    required String type,
    bool? isRead,
    String? search,
    int perPage = 50,
    int page = 1,
    ApiCachePolicy cachePolicy = ApiCachePolicy.networkFirst,
  }) async {
    final params = <String, String>{
      'type': type,
      'per_page': '$perPage',
      'page': '$page',
    };
    if (isRead != null) params['is_read'] = isRead ? 'true' : 'false';
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    final query = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    var response = await ApiService.get(
      '/inbox?$query',
      cachePolicy: cachePolicy,
      cacheGroup: OfflineCacheGroups.inbox,
    );
    final localSearch = !response.success &&
        search != null &&
        search.trim().isNotEmpty;
    if (localSearch) {
      final fallbackParams = Map<String, String>.from(params)..remove('search');
      final fallbackQuery = fallbackParams.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      response = await ApiService.get(
        '/inbox?$fallbackQuery',
        cachePolicy: ApiCachePolicy.cacheOnly,
      );
    }
    if (!response.success) {
      return InboxListResult.error(
        response.errorMessage ?? 'Gagal memuat inbox.',
      );
    }

    final body = response.data;
    if (body is! Map) {
      return InboxListResult.error('Respons server tidak valid.');
    }

    final rawData = body['data'];
    final rawMeta = body['meta'];
    final rawUnread = body['unread_count'];

    final itemsList = rawData is List ? rawData : const <dynamic>[];
    final items = itemsList
        .whereType<Map>()
        .map((m) => InboxItem.fromJson(Map<String, dynamic>.from(m)))
        .where((item) {
          if (!localSearch) return true;
          final q = search.trim().toLowerCase();
          return item.title.toLowerCase().contains(q) ||
              (item.description ?? '').toLowerCase().contains(q) ||
              (item.location ?? '').toLowerCase().contains(q);
        })
        .toList();

    int asInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final meta = rawMeta is Map ? rawMeta : const {};
    final unread = rawUnread is Map ? rawUnread : const {};

    return InboxListResult.success(
      items: items,
      unreadPersonal: asInt(unread['personal']),
      unreadAnnouncements: asInt(unread['announcements']),
      unreadTotal: asInt(unread['total']),
      currentPage: asInt(meta['current_page'], 1),
      lastPage: asInt(meta['last_page'], 1),
      hasMore: meta['has_more'] == true,
    );
  }

  static Future<ApiResponse> markRead({
    required String itemId,
    required String itemType,
  }) async {
    final response = await ApiService.post('/inbox/read', {
      'item_id': itemId,
      'item_type': itemType,
    });
    if (response.success) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.inbox);
    }
    return response;
  }

  static Future<ApiResponse> markAllRead() async {
    final response = await ApiService.post('/inbox/read-all', {});
    if (response.success) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.inbox);
    }
    return response;
  }
}
