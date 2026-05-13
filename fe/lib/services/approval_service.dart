import 'api_service.dart';

class ApprovalService {
  static Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    final response = await ApiService.get('/inbox?type=personal&per_page=100');
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
      'approval_status': item['approval_status'],
      'rejection_reason': item['rejection_reason'],
      'created_at': item['created_at'] ?? item['submitted_at'],
      'submitted_at': item['submitted_at'],
      'user': submitter,
    };
  }

  static Future<ApiResponse> approveRegistration(String id) {
    return ApiService.put('/admin/users/$id/approve', {});
  }

  static Future<ApiResponse> rejectRegistration(String id, String reason) {
    return ApiService.post('/admin/users/$id/reject', {
      'reason': reason.trim(),
    });
  }

  static Future<ApiResponse> approveLicense(String id) {
    return ApiService.put('/admin/licenses/$id/approve', {});
  }

  static Future<ApiResponse> rejectLicense(String id, String reason) {
    return ApiService.post('/admin/licenses/$id/reject', {
      'reason': reason.trim(),
    });
  }

  static Future<ApiResponse> approveCertification(String id) {
    return ApiService.put('/admin/certifications/$id/approve', {});
  }

  static Future<ApiResponse> rejectCertification(String id, String reason) {
    return ApiService.post('/admin/certifications/$id/reject', {
      'reason': reason.trim(),
    });
  }
}
