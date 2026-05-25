import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/report.dart';
import '../utils/url_helper.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';
import 'supabase_storage_service.dart';

class TaggedUser {
  final String id;
  final String fullName;
  final String? role;

  const TaggedUser({
    required this.id,
    required this.fullName,
    this.role,
  });

  factory TaggedUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TaggedUser(id: '', fullName: '');
    return TaggedUser(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString(),
    );
  }
}

class ReportLogEntry {
  final String id;
  final String? actorUserId;
  final ReportStatus status;
  final ReportSubStatus? subStatus;
  final DateTime timestamp;
  final String actor;
  final String? actorPhotoUrl;
  final String? note;
  final String? photoUrl;
  final List<String> photoUrls;
  final int replyCount;
  final DateTime? latestReplyAt;
  final TaggedUser? taggedUser;

  const ReportLogEntry({
    required this.id,
    this.actorUserId,
    required this.status,
    required this.timestamp,
    required this.actor,
    this.actorPhotoUrl,
    this.subStatus,
    this.note,
    this.photoUrl,
    this.photoUrls = const [],
    this.replyCount = 0,
    this.latestReplyAt,
    this.taggedUser,
  });
}

class TimelineReply {
  final String id;
  final String logId;
  final String? parentReplyId;
  final String actor;
  final String? actorPhotoUrl;
  final String? userRole;
  final String message;
  final String? attachmentUrl;
  final List<String> attachmentUrls;
  final DateTime timestamp;

  const TimelineReply({
    required this.id,
    required this.logId,
    this.parentReplyId,
    required this.actor,
    this.actorPhotoUrl,
    this.userRole,
    required this.message,
    this.attachmentUrl,
    this.attachmentUrls = const [],
    required this.timestamp,
  });
}

class ReportService {
  static const String _placeholderImage =
      'https://placehold.co/600x400?text=No+Image';

  static Future<ReportListResult> getReports({
    int perPage = 50,
    ApiCachePolicy cachePolicy = ApiCachePolicy.networkFirst,
  }) async {
    final responses = await Future.wait([
      ApiService.get(
        '/hazard-reports?per_page=$perPage&sort=newest',
        cachePolicy: cachePolicy,
        cacheGroup: OfflineCacheGroups.reports,
      ),
      ApiService.get(
        '/inspection-reports?per_page=$perPage&sort=newest',
        cachePolicy: cachePolicy,
        cacheGroup: OfflineCacheGroups.reports,
      ),
    ]);
    final hazardRes = responses[0];
    final inspectionRes = responses[1];

    if (!hazardRes.success) {
      return ReportListResult.error(
        hazardRes.errorMessage ?? 'Gagal memuat laporan hazard.',
      );
    }
    if (!inspectionRes.success) {
      return ReportListResult.error(
        inspectionRes.errorMessage ?? 'Gagal memuat laporan inspeksi.',
      );
    }

    final hazardRaw = _asList(hazardRes.data['data']);
    final inspectionRaw = _asList(inspectionRes.data['data']);

    final reports = <Report>[
      ...hazardRaw.map((e) => _mapHazardReport(Map<String, dynamic>.from(e))),
      ...inspectionRaw
          .map((e) => _mapInspectionReport(Map<String, dynamic>.from(e))),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ReportListResult.success(reports);
  }

  static Future<ReportActionResult> createHazardReport({
    required String title,
    required String description,
    required String location,
    String? severity,
    String? company,
    String? area,
    String? picDepartment,
    String? department,
    String? hazardCategory,
    String? hazardSubcategory,
    String? suggestion,
    String? pelakuPelanggaran,
    String? pelaporLocation,
    String? kejadianLocation,
    List<String> imagePaths = const [],
    bool isPublic = true,
  }) async {
    final fields = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
      if (company != null && company.isNotEmpty) 'company': company,
      if (area != null && area.isNotEmpty) 'area': area,
      if (picDepartment != null && picDepartment.isNotEmpty)
        'pic_department': picDepartment,
      if (department != null && department.isNotEmpty)
        'reported_department': department,
      if (hazardCategory != null && hazardCategory.isNotEmpty)
        'hazard_category': hazardCategory,
      if (hazardSubcategory != null && hazardSubcategory.isNotEmpty)
        'hazard_subcategory': hazardSubcategory,
      if (suggestion != null && suggestion.isNotEmpty)
        'suggestion': suggestion,
      if (pelakuPelanggaran != null && pelakuPelanggaran.isNotEmpty)
        'pelaku_pelanggaran': pelakuPelanggaran,
      if (pelaporLocation != null && pelaporLocation.isNotEmpty)
        'pelapor_location': pelaporLocation,
      if (kejadianLocation != null && kejadianLocation.isNotEmpty)
        'kejadian_location': kejadianLocation,
      'isPublic': isPublic.toString(),
    };

    // 1) Upload semua image ke Supabase Storage dulu (jika ada)
    final uploadedUrls = <String>[];
    for (final path in imagePaths) {
      if (path.isEmpty) continue;
      final imageUrl = await SupabaseStorageService.uploadImage(
        imagePath: path,
        folder: SupabaseConfig.hazardFolder,
      );
      if (imageUrl == null) {
        return ReportActionResult.error('Gagal mengunggah gambar ke Supabase.');
      }
      uploadedUrls.add(imageUrl);
    }
    if (uploadedUrls.isNotEmpty) {
      fields['image_url'] = uploadedUrls.first; // back-compat
      fields['image_urls'] = uploadedUrls;
    }

    // 2) Send only JSON fields (including image_url(s)) to Laravel
    final response =
        await ApiService.post('/hazard-reports', fields);

    if (!response.success) {
      return ReportActionResult.error(
          response.errorMessage ?? 'Gagal kirim laporan hazard.');
    }

    final rawData = response.data['data'];
    if (rawData is! Map<String, dynamic>) {
      return ReportActionResult.error('Respons server tidak valid.');
    }

    await Future.wait([
      OfflineCacheService.clearGroup(OfflineCacheGroups.reports),
      OfflineCacheService.clearGroup(OfflineCacheGroups.inbox),
    ]);

    return ReportActionResult.success(_mapHazardReport(rawData));
  }

  static Future<ReportActionResult> createInspectionReport({
    required String title,
    required String description,
    required String location,
    String? area,
    String? inspector,
    String? reportedDepartment,
    String? result,
    String? notes,
    List<Map<String, dynamic>>? checklistItems,
    List<String> imagePaths = const [],
  }) async {
    final fields = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      if (area != null && area.isNotEmpty) 'area': area,
      if (inspector != null && inspector.isNotEmpty) 'inspector': inspector,
      if (reportedDepartment != null && reportedDepartment.isNotEmpty)
        'reported_department': reportedDepartment,
      if (result != null && result.isNotEmpty) 'result': result,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (checklistItems != null)
        'checklist_items': jsonEncode(checklistItems),
    };

    // 1) Upload semua image ke Supabase Storage dulu (jika ada)
    final uploadedUrls = <String>[];
    for (final path in imagePaths) {
      if (path.isEmpty) continue;
      final imageUrl = await SupabaseStorageService.uploadImage(
        imagePath: path,
        folder: SupabaseConfig.inspectionFolder,
      );
      if (imageUrl == null) {
        return ReportActionResult.error('Gagal mengunggah gambar ke Supabase.');
      }
      uploadedUrls.add(imageUrl);
    }
    if (uploadedUrls.isNotEmpty) {
      fields['image_url'] = uploadedUrls.first; // back-compat
      fields['image_urls'] = uploadedUrls;
    }

    // 2) Send only JSON fields (including image_url(s)) to Laravel
    final response =
        await ApiService.post('/inspection-reports', fields);

    if (!response.success) {
      return ReportActionResult.error(
        response.errorMessage ?? 'Gagal kirim laporan inspeksi.',
      );
    }

    final rawData = response.data['data'];
    if (rawData is! Map<String, dynamic>) {
      return ReportActionResult.error('Respons server tidak valid.');
    }

    await Future.wait([
      OfflineCacheService.clearGroup(OfflineCacheGroups.reports),
      OfflineCacheService.clearGroup(OfflineCacheGroups.inbox),
    ]);

    return ReportActionResult.success(_mapInspectionReport(rawData));
  }

  static Future<ReportActionResult> updateReportStatus({
    required Report report,
    required ReportStatus status,
    ReportSubStatus? subStatus,
    String? message,
    List<String> imagePaths = const [],
    String? taggedUserId,
    String? department,
    String? picDepartment,
  }) async {
    final endpoint = report.type == ReportType.hazard
        ? '/hazard-reports/${report.id}/status'
        : '/inspection-reports/${report.id}/status';

    final fields = <String, dynamic>{
      'status': _statusToApi(status),
    };
    if (subStatus != null) fields['sub_status'] = subStatus.name;
    if (message != null && message.trim().isNotEmpty) {
      fields['message'] = message.trim();
    }
    if (taggedUserId != null && taggedUserId.isNotEmpty) {
      fields['tagged_user_id'] = taggedUserId;
    }
    if (department != null && department.isNotEmpty) {
      fields['reported_department'] = department;
    }
    if (picDepartment != null && picDepartment.isNotEmpty) {
      fields['pic_department'] = picDepartment;
    }

    // Upload semua status-update image ke Supabase Storage dulu (jika ada)
    final uploadedUrls = <String>[];
    for (final path in imagePaths) {
      if (path.isEmpty) continue;
      final imageUrl = await SupabaseStorageService.uploadImage(
        imagePath: path,
        folder: SupabaseConfig.reportLogsFolder,
      );
      if (imageUrl == null) {
        return ReportActionResult.error(
            'Gagal mengunggah gambar ke Supabase.');
      }
      uploadedUrls.add(imageUrl);
    }
    if (uploadedUrls.isNotEmpty) {
      fields['image_url'] = uploadedUrls.first; // back-compat
      fields['image_urls'] = uploadedUrls;
    }
    debugPrint(
        'updateReportStatus: uploading ${uploadedUrls.length} photos for report ${report.id}');
    debugPrint(
        'updateReportStatus payload image_urls=${fields['image_urls']}');

    final response = await ApiService.post(endpoint, fields);
    debugPrint(
        'updateReportStatus response image_urls=${(response.data?['data'] as Map?)?['image_urls']}');

    if (!response.success) {
      debugPrint('Update status failed: ${response.errorMessage}');
      return ReportActionResult.error(
        response.errorMessage ?? 'Gagal memperbarui status laporan.',
      );
    }

    final rawData = response.data?['data'];
    if (rawData is! Map<String, dynamic>) {
      return ReportActionResult.error('Respons server tidak valid.');
    }

    await Future.wait([
      OfflineCacheService.clearGroup(OfflineCacheGroups.reports),
      OfflineCacheService.clearGroup(OfflineCacheGroups.inbox),
      OfflineCacheService.clearGroup(OfflineCacheGroups.reportDetail),
    ]);

    return ReportActionResult.success(
      report.type == ReportType.hazard
          ? _mapHazardReport(rawData)
          : _mapInspectionReport(rawData),
    );
  }

  static Future<ReportActionResult> getReportDetails(String id, ReportType type) async {
    final endpoint = type == ReportType.hazard
        ? '/hazard-reports/$id'
        : '/inspection-reports/$id';
    
    debugPrint('Fetching report details: $endpoint');
    final response = await ApiService.get(
      endpoint,
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.reportDetail,
    );

    if (!response.success) {
      return ReportActionResult.error(
        response.errorMessage ?? 'Gagal memuat detail laporan.',
      );
    }

    final rawData = response.data['data'];
    if (rawData is! Map<String, dynamic>) {
      return ReportActionResult.error('Respons server tidak valid.');
    }

    return ReportActionResult.success(
      type == ReportType.hazard
          ? _mapHazardReport(rawData)
          : _mapInspectionReport(rawData),
    );
  }

  static Future<ReportLogsResult> getLogs(Report report) async {
    final endpoint = report.type == ReportType.hazard
        ? '/hazard-reports/${report.id}/logs'
        : '/inspection-reports/${report.id}/logs';

    final response = await ApiService.get(
      endpoint,
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.reportDetail,
    );

    if (!response.success) {
      return ReportLogsResult.error(
        response.errorMessage ?? 'Gagal memuat riwayat laporan.',
      );
    }

    final rawList = _asList(response.data['data']);
    final logs = rawList
        .map((e) => _mapLogEntry(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    debugPrint('getLogs(${report.id}): ${logs.length} entries; '
        'photo counts=${logs.map((e) => e.photoUrls.length).toList()}');

    return ReportLogsResult.success(logs);
  }

  static Future<List<UserEntry>> getUsers({String? search}) async {
    final query = (search != null && search.trim().isNotEmpty)
        ? '?search=${Uri.encodeQueryComponent(search.trim())}'
        : '';
    final response = await ApiService.get(
      '/users$query',
      cachePolicy: search == null || search.trim().isEmpty
          ? ApiCachePolicy.networkFirst
          : ApiCachePolicy.networkOnly,
      cacheGroup: OfflineCacheGroups.references,
    );
    if (!response.success) return const [];
    final raw = _asList(response.data['data']);
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e);
      return UserEntry(
        id: m['id']?.toString() ?? '',
        fullName: m['full_name']?.toString() ?? '',
        department: m['department']?.toString(),
        photoUrl: normalizeStorageUrl(m['photo_url']?.toString()),
      );
    }).where((u) => u.id.isNotEmpty && u.fullName.trim().isNotEmpty).toList();
  }

  static Future<List<TimelineReply>> getLogReplies({
    required Report report,
    required String logId,
  }) async {
    final endpoint = report.type == ReportType.hazard
        ? '/hazard-reports/${report.id}/logs/$logId/replies'
        : '/inspection-reports/${report.id}/logs/$logId/replies';
    final response = await ApiService.get(
      endpoint,
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.reportDetail,
    );
    if (!response.success) return const [];
    final rawList = _asList(response.data['data']);
    return rawList.map((e) => _mapTimelineReply(Map<String, dynamic>.from(e))).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<TimelineReply?> postLogReply({
    required Report report,
    required String logId,
    required String message,
    String? parentReplyId,
    String? attachmentUrl,
    List<String> attachmentUrls = const [],
  }) async {
    final endpoint = report.type == ReportType.hazard
        ? '/hazard-reports/${report.id}/logs/$logId/replies'
        : '/inspection-reports/${report.id}/logs/$logId/replies';
    final response = await ApiService.post(endpoint, {
      'message': message.trim(),
      if (parentReplyId != null && parentReplyId.isNotEmpty) 'parent_reply_id': parentReplyId,
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachment_url': attachmentUrl,
      if (attachmentUrls.isNotEmpty) 'attachment_urls': attachmentUrls,
    });
    if (!response.success) return null;
    await OfflineCacheService.clearGroup(OfflineCacheGroups.reportDetail);
    final raw = response.data['data'];
    if (raw is! Map<String, dynamic>) return null;
    return _mapTimelineReply(raw);
  }

  static Future<List<String>> getDepartments() async {
    final response = await ApiService.get(
      '/departments',
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.references,
    );
    if (!response.success) return const [];
    final raw = _asList(response.data['data']);
    final seen = <String>{};
    return raw
        .map((e) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            return m['name']?.toString() ??
                m['department']?.toString() ??
                '';
          }
          return e.toString();
        })
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && seen.add(s.toLowerCase()))
        .toList();
  }

  static Future<List<String>> getCompanies({String? category}) async {
    final query = StringBuffer('?active=1');
    if (category != null && category.trim().isNotEmpty) {
      query.write('&category=${Uri.encodeQueryComponent(category.trim())}');
    }
    final response = await ApiService.get(
      '/companies$query',
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.references,
    );
    if (!response.success) return const [];
    final raw = _asList(response.data['data']);
    return raw
        .map((e) => Map<String, dynamic>.from(e)['name']?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  static Future<List<HazardCategoryData>> getHazardCategories() async {
    final response = await ApiService.get(
      '/hazard-categories',
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.references,
    );
    if (!response.success) return const [];
    final raw = _asList(response.data['data']);
    return raw
        .map((e) => _mapCategoryData(e))
        .where((c) => c.name.isNotEmpty)
        .toList();
  }

  static HazardCategoryData _mapCategoryData(dynamic e) {
    final m = Map<String, dynamic>.from(e);
    final subs = _asList(m['subcategories']);
    return HazardCategoryData(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      code: m['code']?.toString() ?? '',
      subcategories: subs
          .map((s) => _mapSubcategoryData(s))
          .where((s) => s.name.isNotEmpty)
          .toList(),
    );
  }

  static HazardSubcategoryData _mapSubcategoryData(dynamic s) {
    final sm = Map<String, dynamic>.from(s);
    return HazardSubcategoryData(
      id: sm['id']?.toString() ?? '',
      name: sm['name']?.toString() ?? '',
      abbreviation: sm['abbreviation']?.toString(),
      description: sm['description']?.toString(),
      isActive: sm['is_active'] == true || sm['is_active'] == 1,
      status: sm['status']?.toString() ?? 'approved',
      categoryId:
          sm['category_id']?.toString() ?? sm['category']?['id']?.toString(),
      categoryName: sm['category']?['name']?.toString(),
      proposedByName: sm['proposed_by']?['full_name']?.toString() ??
          sm['proposed_by_name']?.toString(),
    );
  }

  static Future<HazardCategoryData?> createCategory(
    String name, {
    String? code,
  }) async {
    final response = await ApiService.post('/hazard-categories', {
      'name': name,
      if (code != null) 'code': code,
    });
    if (!response.success) return null;
    await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    return _mapCategoryData(response.data['data']);
  }

  static Future<HazardCategoryData?> updateCategory(
    String id,
    String name, {
    String? code,
  }) async {
    final response = await ApiService.put('/hazard-categories/$id', {
      'name': name,
      if (code != null) 'code': code,
    });
    if (!response.success) return null;
    await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    return _mapCategoryData(response.data['data']);
  }

  static Future<bool> deleteCategory(String id) async {
    final response = await ApiService.delete('/hazard-categories/$id');
    if (response.success) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    }
    return response.success;
  }

  static Future<List<HazardSubcategoryData>> getPendingSubcategories() async {
    final response = await ApiService.get(
      '/hazard-categories/subcategories/pending',
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.references,
    );
    if (!response.success) return const [];
    final raw = _asList(response.data['data']);
    return raw.map((e) => _mapSubcategoryData(e)).toList();
  }

  static Future<HazardSubcategoryData?> createSubcategory(
    String categoryId,
    String name, {
    String? abbreviation,
    String? description,
  }) async {
    final response = await ApiService.post(
      '/hazard-categories/$categoryId/subcategories',
      {
        'name': name,
        'abbreviation': abbreviation,
        'description': description,
      },
    );
    if (!response.success) return null;
    await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    return _mapSubcategoryData(response.data['data']);
  }

  static Future<bool> approveSubcategory(String subId) async {
    final response = await ApiService.post(
      '/hazard-categories/subcategories/$subId/approve',
      {},
    );
    if (response.success) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    }
    return response.success;
  }

  static Future<bool> rejectSubcategory(String subId) async {
    final response = await ApiService.post(
      '/hazard-categories/subcategories/$subId/reject',
      {},
    );
    if (response.success) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    }
    return response.success;
  }

  static Future<HazardSubcategoryData?> updateSubcategory(
    String categoryId,
    String subId,
    String name, {
    String? abbreviation,
    String? description,
    bool? isActive,
  }) async {
    final response = await ApiService.put(
      '/hazard-categories/$categoryId/subcategories/$subId',
      {
        'name': name,
        'abbreviation': abbreviation,
        'description': description,
        'is_active': isActive,
      },
    );
    if (!response.success) return null;
    await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    return _mapSubcategoryData(response.data['data']);
  }

  static Future<bool> deleteSubcategory(String categoryId, String subId) async {
    final response = await ApiService.delete(
      '/hazard-categories/$categoryId/subcategories/$subId',
    );
    if (response.success) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    }
    return response.success;
  }

  static Future<bool> toggleSubcategoryStatus(String subId) async {
    final response = await ApiService.post(
      '/hazard-categories/subcategories/$subId/toggle',
      {},
    );
    if (response.success) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    }
    return response.success;
  }

  static List<String> _parseImageUrls(Map<String, dynamic> json) {
    final urls = <String>[];
    final seen = <String>{};

    final raw = json['image_urls'];
    if (raw is List) {
      for (final item in raw) {
        final normalized = normalizeStorageUrl(item?.toString());
        if (normalized != null && normalized.isNotEmpty && !seen.contains(normalized)) {
          seen.add(normalized);
          urls.add(normalized);
        }
      }
    }
    if (urls.isEmpty) {
      final n = normalizeStorageUrl(json['image_url']?.toString());
      if (n != null && n.isNotEmpty) urls.add(n);
    }
    return urls;
  }

  static Report _mapHazardReport(Map<String, dynamic> json) {
    final severity =
        _severityFromApi(json['severity']?.toString()) ?? ReportSeverity.medium;
    final rawStatus = json['status']?.toString();
    final rawSubStatus = json['sub_status']?.toString();
    final imageUrls = _parseImageUrls(json);
    final categoryCodes = _parseHazardCategoryCodes(
      json['hazard_category_codes'],
      json['hazard_category']?.toString(),
    );
    final categoryNames = _parseHazardCategoryNames(
      json['hazard_category_names'],
      categoryCodes,
    );
    final subcategories = _parseCsvList(
      json['hazard_subcategories'],
      json['hazard_subcategory']?.toString(),
    );
    return Report(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '-',
      description: json['description']?.toString() ?? '-',
      type: ReportType.hazard,
      category: _hazardCategoryFromCodes(categoryCodes),
      hazardCategoryCodes: categoryCodes,
      hazardCategoryNames: categoryNames,
      subkategori: json['hazard_subcategory']?.toString(),
      hazardSubcategories: subcategories,
      severity: severity,
      status: _statusFromApi(rawStatus),
      subStatus: _subStatusFromApi(rawSubStatus) ??
          (rawStatus == 'rejected' ? ReportSubStatus.rejected : null),
      location: json['location']?.toString() ?? '-',
      saran: json['suggestion']?.toString(),
      departemen: json['reported_department']?.toString(),
      picDepartment: json['pic_department']?.toString() ?? json['name_pja']?.toString(),
      pelakuPelanggaran: json['pelaku_pelanggaran']?.toString(),
      pelaporLocation: json['pelapor_location']?.toString(),
      kejadianLocation: json['kejadian_location']?.toString(),
      company: json['company']?.toString() ?? (json['reported_by'] is Map ? json['reported_by']['company']?.toString() : null),
      isPublic: json['is_public'] as bool?,
      dueDate: _parseDateOrNull(json['due_date']),
      sisaHari: (json['sisa_hari'] as num?)?.toInt(),
      isOverdue: json['is_overdue'] == true ||
          ((json['sisa_hari'] as num?)?.toInt() ?? 0) < 0,
      createdAt: _parseDate(json['created_at']),
      reportedBy: _reportedBy(json['reported_by']),
      reporterId: _reporterId(json['reported_by']),
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : _placeholderImage,
      imageUrls: imageUrls,
      ticketNumber: json['ticket_number']?.toString(),
      area: json['area']?.toString(),
      nameInspector: json['name_inspector']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  static Report _mapInspectionReport(Map<String, dynamic> json) {
    final result = json['result']?.toString();
    final rawStatus = json['status']?.toString();
    final rawSubStatus = json['sub_status']?.toString();
    final checklistRaw = json['checklist_items'];
    List<ChecklistItem>? checklistItems;
    if (checklistRaw is List) {
      checklistItems = checklistRaw
          .map((e) => ChecklistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final imageUrls = _parseImageUrls(json);

    return Report(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '-',
      description: json['description']?.toString() ?? '-',
      type: ReportType.inspection,
      category: _inspectionCategoryFromArea(json['area']?.toString()),
      severity: _severityFromInspectionResult(result),
      status: _statusFromApi(rawStatus),
      subStatus: _subStatusFromApi(rawSubStatus) ??
          (rawStatus == 'rejected' ? ReportSubStatus.rejected : null),
      location: json['location']?.toString() ?? '-',
      departemen: json['reported_department']?.toString(),
      createdAt: _parseDate(json['created_at']),
      reportedBy: _reportedBy(json['reported_by']),
      reporterId: _reporterId(json['reported_by']),
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : _placeholderImage,
      imageUrls: imageUrls,
      ticketNumber: json['ticket_number']?.toString(),
      area: json['area']?.toString(),
      nameInspector: json['name_inspector']?.toString() ?? json['inspector']?.toString(),
      notes: json['notes']?.toString(),
      checklistItems: checklistItems,
    );
  }

  static ReportLogEntry _mapLogEntry(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString();
    final rawSubStatus = json['sub_status']?.toString();
    final photoUrls = _parseImageUrls(json);
    final actorPhoto = normalizeStorageUrl(
      json['user_photo_url']?.toString() ??
          json['user_photo']?.toString() ??
          json['photo_url']?.toString(),
    );
    return ReportLogEntry(
      id: json['id']?.toString() ?? '',
      actorUserId: json['user_id']?.toString(),
      status: _statusFromApi(rawStatus),
      subStatus: _subStatusFromApi(rawSubStatus) ??
          (rawStatus == 'rejected' ? ReportSubStatus.rejected : null),
      timestamp: _parseDate(json['created_at']),
      actor: json['user_name']?.toString().trim().isNotEmpty == true
          ? json['user_name'].toString()
          : 'System',
      actorPhotoUrl: actorPhoto,
      note: json['message']?.toString(),
      photoUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
      photoUrls: photoUrls,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      latestReplyAt: _parseDateOrNull(json['latest_reply_at']),
      taggedUser: json['tagged_user'] != null
          ? TaggedUser.fromJson(json['tagged_user'] as Map<String, dynamic>)
          : null,
    );
  }

  static TimelineReply _mapTimelineReply(Map<String, dynamic> json) {
    final urls = <String>[];
    final rawList = json['attachment_urls'];
    if (rawList is List) {
      for (final item in rawList) {
        final normalized = normalizeStorageUrl(item?.toString());
        if (normalized != null && normalized.isNotEmpty) {
          urls.add(normalized);
        }
      }
    }
    final single = normalizeStorageUrl(json['attachment_url']?.toString());
    if (urls.isEmpty && single != null && single.isNotEmpty) {
      urls.add(single);
    }
    final parentRaw = json['parent_reply_id']?.toString();
    final roleRaw = json['user_role']?.toString();
    final actorPhoto = normalizeStorageUrl(
      json['user_photo_url']?.toString() ??
          json['user_photo']?.toString() ??
          json['photo_url']?.toString(),
    );
    return TimelineReply(
      id: json['id']?.toString() ?? '',
      logId: json['report_log_id']?.toString() ?? '',
      parentReplyId: (parentRaw != null && parentRaw.isNotEmpty) ? parentRaw : null,
      actor: json['user_name']?.toString().trim().isNotEmpty == true
          ? json['user_name'].toString()
          : 'Unknown User',
      actorPhotoUrl: actorPhoto,
      userRole: (roleRaw != null && roleRaw.isNotEmpty) ? roleRaw : null,
      message: json['message']?.toString() ?? '',
      attachmentUrl: urls.isNotEmpty ? urls.first : single,
      attachmentUrls: urls,
      timestamp: _parseDate(json['created_at']),
    );
  }

  static List<dynamic> _asList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) return raw.values.toList();
    return const [];
  }

  static String _reportedBy(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final name = raw['full_name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name;
    }
    return 'Unknown User';
  }

  static String? _reporterId(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['id']?.toString();
    }
    return null;
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    final parsed = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    return parsed?.toLocal() ?? DateTime.now();
  }

  static DateTime? _parseDateOrNull(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T'))?.toLocal();
  }

  static ReportStatus _statusFromApi(String? status) {
    switch (status) {
      case 'in_progress':
        return ReportStatus.inProgress;
      case 'closed':
      case 'rejected':
        return ReportStatus.closed;
      case 'pending':
        // Legacy compatibility: pending is treated as open.
        return ReportStatus.open;
      case 'open':
      default:
        return ReportStatus.open;
    }
  }

  static String _statusToApi(ReportStatus status) {
    switch (status) {
      case ReportStatus.inProgress:
        return 'in_progress';
      case ReportStatus.closed:
        return 'closed';
      case ReportStatus.open:
        return 'open';
    }
  }

  static ReportSubStatus? _subStatusFromApi(String? subStatus) {
    if (subStatus == null || subStatus.isEmpty) return null;
    for (final value in ReportSubStatus.values) {
      if (value.name == subStatus) return value;
    }
    return null;
  }

  static ReportSeverity? _severityFromApi(String? severity) {
    switch (severity) {
      case 'low':
        return ReportSeverity.low;
      case 'medium':
        return ReportSeverity.medium;
      case 'high':
        return ReportSeverity.high;
      case 'critical':
        return ReportSeverity.critical;
      default:
        return null;
    }
  }

  static ReportSeverity _severityFromInspectionResult(String? result) {
    switch (result) {
      case 'non_compliant':
        return ReportSeverity.high;
      case 'needs_follow_up':
        return ReportSeverity.medium;
      case 'compliant':
      default:
        return ReportSeverity.low;
    }
  }

  static HazardCategory? _hazardCategoryFromCodes(List<String> codes) {
    if (codes.isEmpty) return null;
    switch (codes.first) {
      case 'TTA':
        return HazardCategory.unsafeAct;
      case 'KTA':
        return HazardCategory.unsafeCondition;
      default:
        return null;
    }
  }

  static List<String> _parseHazardCategoryCodes(
      dynamic rawCodes, String? rawCategory) {
    return _parseCsvList(rawCodes, rawCategory, uppercase: true);
  }

  static List<String> _parseHazardCategoryNames(
      dynamic rawNames, List<String> fallbackCodes) {
    final names = _parseCsvList(rawNames, null);
    return names.isEmpty ? fallbackCodes : names;
  }

  static List<String> _parseCsvList(
    dynamic rawList,
    String? rawCsv, {
    bool uppercase = false,
  }) {
    final source = <String>[];
    if (rawList is List) {
      for (final item in rawList) {
        source.add(item?.toString() ?? '');
      }
    } else if (rawCsv != null) {
      source.addAll(rawCsv.split(RegExp(r'[,;]')));
    }

    final result = <String>[];
    final seen = <String>{};
    for (final item in source) {
      var normalized = item.trim();
      if (uppercase) normalized = normalized.toUpperCase();
      if (normalized.isEmpty) continue;
      final key = uppercase ? normalized : normalized.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(normalized);
    }
    return result;
  }

  static HazardCategory _inspectionCategoryFromArea(String? area) {
    final normalized = (area ?? '').toLowerCase();
    if (normalized.contains('listrik') || normalized.contains('electrical')) {
      return HazardCategory.electricalInspection;
    }
    if (normalized.contains('alat') || normalized.contains('equipment')) {
      return HazardCategory.equipmentInspection;
    }
    return HazardCategory.routineInspection;
  }
}

class ReportListResult {
  final bool success;
  final List<Report> reports;
  final String? errorMessage;

  ReportListResult._({
    required this.success,
    this.reports = const [],
    this.errorMessage,
  });

  factory ReportListResult.success(List<Report> reports) =>
      ReportListResult._(success: true, reports: reports);

  factory ReportListResult.error(String message) =>
      ReportListResult._(success: false, errorMessage: message);
}

class ReportActionResult {
  final bool success;
  final Report? report;
  final String? errorMessage;

  ReportActionResult._({
    required this.success,
    this.report,
    this.errorMessage,
  });

  factory ReportActionResult.success(Report report) =>
      ReportActionResult._(success: true, report: report);

  factory ReportActionResult.error(String message) =>
      ReportActionResult._(success: false, errorMessage: message);
}

class ReportLogsResult {
  final bool success;
  final List<ReportLogEntry> logs;
  final String? errorMessage;

  ReportLogsResult._({
    required this.success,
    this.logs = const [],
    this.errorMessage,
  });

  factory ReportLogsResult.success(List<ReportLogEntry> logs) =>
      ReportLogsResult._(success: true, logs: logs);

  factory ReportLogsResult.error(String message) =>
      ReportLogsResult._(success: false, errorMessage: message);
}

class UserEntry {
  final String id;
  final String fullName;
  final String? department;
  final String? photoUrl;

  const UserEntry({
    required this.id,
    required this.fullName,
    this.department,
    this.photoUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class HazardSubcategoryData {
  final String id;
  final String name;
  final String? abbreviation;
  final String? description;
  final bool isActive;
  final String status;
  final String? categoryId;
  final String? categoryName;
  final String? proposedByName;

  const HazardSubcategoryData({
    required this.id,
    required this.name,
    this.abbreviation,
    this.description,
    this.isActive = true,
    this.status = 'approved',
    this.categoryId,
    this.categoryName,
    this.proposedByName,
  });
}

class HazardCategoryData {
  final String id;
  final String name;
  final String code;
  final List<HazardSubcategoryData> subcategories;
  const HazardCategoryData({
    required this.id,
    required this.name,
    required this.code,
    required this.subcategories,
  });
}
