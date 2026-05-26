import 'api_service.dart';
import '../utils/value_parser.dart';

class ViolationService {
  static Future<ViolationListResult> getViolations({
    int page = 1,
    String? search,
    String? status,
    String? type,
  }) async {
    String url = '/admin/violations?page=$page';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }
    if (status != null && status.isNotEmpty && status != 'Semua') {
      url += '&status=${Uri.encodeComponent(status)}';
    }
    if (type != null && type.isNotEmpty && type != 'Semua') {
      url += '&type=${Uri.encodeComponent(type)}';
    }

    final response = await ApiService.get(url);
    if (!response.success) {
      return ViolationListResult.error(
        response.errorMessage ?? 'Gagal memuat data pelanggaran',
      );
    }

    final pageData = response.data['data'] as Map<String, dynamic>? ?? {};
    final rawItems = pageData['data'] as List<dynamic>? ?? [];

    return ViolationListResult.success(
      rawItems
          .map((v) => ViolationItem.fromJson(Map<String, dynamic>.from(v)))
          .toList(),
      currentPage: pageData['current_page'] as int? ?? page,
      lastPage: pageData['last_page'] as int? ?? page,
      total: pageData['total'] as int? ?? rawItems.length,
    );
  }

  static Future<ApiResponse> storeViolation(
    String userId,
    Map<String, dynamic> data,
  ) async {
    return await ApiService.post('/admin/users/$userId/violations', data);
  }

  static Future<ApiResponse> updateViolation(
    String violationId,
    Map<String, dynamic> data,
  ) async {
    return await ApiService.put('/admin/violations/$violationId', data);
  }

  static Future<ApiResponse> deleteViolation(String violationId) async {
    return await ApiService.delete('/admin/violations/$violationId');
  }
}

class ViolationListResult {
  final bool success;
  final String? message;
  final List<ViolationItem> items;
  final int currentPage;
  final int lastPage;
  final int total;

  ViolationListResult.success(
    this.items, {
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  })  : success = true,
        message = null;

  ViolationListResult.error(this.message)
      : success = false,
        items = [],
        currentPage = 1,
        lastPage = 1,
        total = 0;
}

class ViolationItem {
  final String id;
  final String title;
  final String? violationCategory;
  final String? violationSubcategory;
  final String type;
  final int level;
  final String? description;
  final String? location;
  final String dateOfViolation;
  final String? expiredAt;
  final bool isPermanent;
  final String status;
  final String? sanction;
  final String? fileUrl;
  final Map<String, dynamic> user;

  ViolationItem({
    required this.id,
    required this.title,
    this.violationCategory,
    this.violationSubcategory,
    this.type = 'Violation',
    this.level = 1,
    this.description,
    this.location,
    required this.dateOfViolation,
    this.expiredAt,
    this.isPermanent = false,
    required this.status,
    this.sanction,
    this.fileUrl,
    required this.user,
  });

  factory ViolationItem.fromJson(Map<String, dynamic> json) {
    return ViolationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      violationCategory: json['violation_category']?.toString(),
      violationSubcategory: json['violation_subcategory']?.toString(),
      type: json['type']?.toString() ?? 'Violation',
      level: int.tryParse(json['level']?.toString() ?? '') ?? 1,
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      dateOfViolation: json['date_of_violation']?.toString() ?? '',
      expiredAt: json['expired_at']?.toString(),
      isPermanent: parseFlexibleBool(json['is_permanent']),
      status: json['status']?.toString() ?? 'Aktif',
      sanction: json['sanction']?.toString(),
      fileUrl: json['file_url']?.toString(),
      user: Map<String, dynamic>.from(json['user'] as Map? ?? {}),
    );
  }
}
