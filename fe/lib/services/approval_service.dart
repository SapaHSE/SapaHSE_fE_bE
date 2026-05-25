import '../models/inbox_item.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';

class ApprovalService {
  static Future<List<InboxItem>> getPendingApprovalItems() async {
    final response = await ApiService.get(
      '/inbox?type=personal&per_page=100',
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.inbox,
    );
    final items = _parseApprovalItems(response);
    return items.where((item) {
      final status = (item.approvalStatus ?? 'pending').toLowerCase();
      return _isDocumentApproval(item) &&
          (status == 'pending' || status == 'pending_changes');
    }).toList();
  }

  static Future<List<InboxItem>> getApprovalHistoryItems() async {
    final response = await ApiService.get(
      '/admin/document-approvals?status=history&per_page=100',
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.inbox,
    );
    final items = _parseApprovalItems(response);
    return items.where(_isDocumentApproval).toList();
  }

  static Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    final response = await ApiService.get(
      '/inbox?type=personal&per_page=100',
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.inbox,
    );
    if (!response.success) {
      throw Exception(response.errorMessage ?? 'Gagal memuat approval.');
    }

    final rawList = response.data['data'];
    if (rawList is! List) return [];

    return rawList
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((item) {
          final type = item['item_type']?.toString();
          return type == 'approval_license' || type == 'approval_certification';
        })
        .map(_flattenApprovalDocument)
        .toList();
  }

  static Map<String, dynamic> _flattenApprovalDocument(
      Map<String, dynamic> item) {
    final type = item['item_type']?.toString() ?? '';
    final submitter = item['submitter'] is Map
        ? Map<String, dynamic>.from(item['submitter'] as Map)
        : <String, dynamic>{};
    final document = item['item'] is Map
        ? Map<String, dynamic>.from(item['item'] as Map)
        : <String, dynamic>{};

    return <String, dynamic>{
      ...document,
      'id': item['id']?.toString() ?? document['id']?.toString() ?? '',
      'item_type': type,
      'license_type': document['license_type'],
      'vehicle_equipment': document['vehicle_equipment'],
      'sim_type': document['sim_type'],
      'sim_indonesia_type': document['sim_indonesia_type'],
      'approval_status': item['approval_status'],
      'rejection_reason': item['rejection_reason'],
      'created_at': item['created_at'] ?? item['submitted_at'],
      'submitted_at': item['submitted_at'],
      'user': submitter,
    };
  }

  static Future<ApiResponse> approveRegistration(String id) async {
    final response = await ApiService.put('/admin/users/$id/approve', {});
    await _clearApprovalCachesIfSuccess(response);
    return response;
  }

  static Future<ApiResponse> rejectRegistration(String id, String reason) async {
    final response = await ApiService.post('/admin/users/$id/reject', {
      'reason': reason.trim(),
    });
    await _clearApprovalCachesIfSuccess(response);
    return response;
  }

  static Future<ApiResponse> approveLicense(
    String id, {
    String? obtainedAt,
    String? expiredAt,
  }) async {
    final response = await ApiService.put('/admin/licenses/$id/approve', {
      if (obtainedAt != null) 'obtained_at': obtainedAt,
      if (expiredAt != null) 'expired_at': expiredAt,
    });
    await _clearApprovalCachesIfSuccess(response);
    return response;
  }

  static Future<ApiResponse> rejectLicense(String id, String reason) async {
    final response = await ApiService.post('/admin/licenses/$id/reject', {
      'reason': reason.trim(),
    });
    await _clearApprovalCachesIfSuccess(response);
    return response;
  }

  static Future<ApiResponse> approveCertification(String id) async {
    final response = await ApiService.put('/admin/certifications/$id/approve', {});
    await _clearApprovalCachesIfSuccess(response);
    return response;
  }

  static Future<ApiResponse> rejectCertification(String id, String reason) async {
    final response = await ApiService.post('/admin/certifications/$id/reject', {
      'reason': reason.trim(),
    });
    await _clearApprovalCachesIfSuccess(response);
    return response;
  }

  static Future<ApiResponse> approveProfileChange(String id) async {
    final response =
        await ApiService.put('/admin/profile-change-requests/$id/approve', {});
    await _clearApprovalCachesIfSuccess(response);
    return response;
  }

  static Future<ApiResponse> rejectProfileChange(String id, String reason) async {
    final response = await ApiService.post('/admin/profile-change-requests/$id/reject', {
      'reason': reason.trim(),
    });
    await _clearApprovalCachesIfSuccess(response);
    return response;
  }

  static Future<void> _clearApprovalCachesIfSuccess(ApiResponse response) async {
    if (!response.success) return;
    await Future.wait([
      OfflineCacheService.clearGroup(OfflineCacheGroups.inbox),
      OfflineCacheService.clearGroup(OfflineCacheGroups.profile),
    ]);
  }

  static List<InboxItem> _parseApprovalItems(ApiResponse response) {
    if (!response.success) {
      throw Exception(response.errorMessage ?? 'Gagal memuat approval.');
    }

    final body = response.data;
    if (body is! Map) return [];

    final rawList = body['data'];
    if (rawList is! List) return [];

    return rawList
        .whereType<Map>()
        .map((raw) => InboxItem.fromJson(Map<String, dynamic>.from(raw)))
        .where((item) => item.isApproval)
        .toList();
  }

  static bool _isDocumentApproval(InboxItem item) =>
      item.itemType == InboxItemType.approvalLicense ||
      item.itemType == InboxItemType.approvalCertification ||
      item.itemType == InboxItemType.approvalProfileChange;
}
