import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/report.dart';
import '../utils/url_helper.dart';
import 'api_service.dart';
import 'supabase_storage_service.dart';

class ReportLogEntry {
  final ReportStatus status;
  final ReportSubStatus? subStatus;
  final DateTime timestamp;
  final String actor;
  final String? note;
  final String? photoUrl;

  const ReportLogEntry({
    required this.status,
    required this.timestamp,
    required this.actor,
    this.subStatus,
    this.note,
    this.photoUrl,
  });
}

class ReportService {
  static const String _placeholderImage =
      'https://placehold.co/600x400?text=No+Image';

  static Future<ReportListResult> getReports({int perPage = 50}) async {
    final responses = await Future.wait([
      ApiService.get('/hazard-reports?per_page=$perPage&sort=newest'),
      ApiService.get('/inspection-reports?per_page=$perPage&sort=newest'),
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
    String? picDepartment,
    String? department,
    String? hazardCategory,
    String? hazardSubcategory,
    String? suggestion,
    String? pelakuPelanggaran,
    String? pelaporLocation,
    String? kejadianLocation,
    String? imagePath,
    bool isPublic = true,
  }) async {
    final fields = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
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

    // 1) Upload image to Supabase Storage first (if provided)
    if (imagePath != null && imagePath.isNotEmpty) {
      final imageUrl = await SupabaseStorageService.uploadImage(
        imagePath: imagePath,
        folder: SupabaseConfig.hazardFolder,
      );
      if (imageUrl == null) {
        return ReportActionResult.error('Gagal mengunggah gambar ke Supabase.');
      }
      fields['image_url'] = imageUrl;
    }

    // 2) Send only JSON fields (including image_url) to Laravel
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

    return ReportActionResult.success(_mapHazardReport(rawData));
  }

  static Future<ReportActionResult> createInspectionReport({
    required String title,
    required String description,
    required String location,
    String? area,
    String? inspector,
    String? result,
    String? notes,
    List<Map<String, dynamic>>? checklistItems,
    String? imagePath,
  }) async {
    final fields = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      if (area != null && area.isNotEmpty) 'area': area,
      if (inspector != null && inspector.isNotEmpty) 'inspector': inspector,
      if (result != null && result.isNotEmpty) 'result': result,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (checklistItems != null)
        'checklist_items': jsonEncode(checklistItems),
    };

    // 1) Upload image to Supabase Storage first (if provided)
    if (imagePath != null && imagePath.isNotEmpty) {
      final imageUrl = await SupabaseStorageService.uploadImage(
        imagePath: imagePath,
        folder: SupabaseConfig.inspectionFolder,
      );
      if (imageUrl == null) {
        return ReportActionResult.error('Gagal mengunggah gambar ke Supabase.');
      }
      fields['image_url'] = imageUrl;
    }

    // 2) Send only JSON fields (including image_url) to Laravel
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

    return ReportActionResult.success(_mapInspectionReport(rawData));
  }

  static Future<ReportActionResult> updateReportStatus({
    required Report report,
    required ReportStatus status,
    ReportSubStatus? subStatus,
    String? message,
    String? imagePath,
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

    // Upload status-update image to Supabase Storage first (if provided)
    if (imagePath != null && imagePath.isNotEmpty) {
      final imageUrl = await SupabaseStorageService.uploadImage(
        imagePath: imagePath,
        folder: SupabaseConfig.reportLogsFolder,
      );
      if (imageUrl == null) {
        return ReportActionResult.error(
            'Gagal mengunggah gambar ke Supabase.');
      }
      fields['image_url'] = imageUrl;
    }

    debugPrint('Updating status for report ${report.id} to ${status.name}');
    final response = await ApiService.post(endpoint, fields);

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
    final response = await ApiService.get(endpoint);

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

    final response = await ApiService.get(endpoint);

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

    return ReportLogsResult.success(logs);
  }

  static Future<List<UserEntry>> getUsers({String? search}) async {
    final query = (search != null && search.trim().isNotEmpty)
        ? '?search=${Uri.encodeQueryComponent(search.trim())}'
        : '';
    final response = await ApiService.get('/users$query');
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
    }).where((u) => u.id.isNotEmpty).toList();
  }

  static Future<List<String>> getDepartments() async {
    final response = await ApiService.get('/departments');
    if (!response.success) return const [];
    final raw = _asList(response.data['data']);
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static Future<List<HazardCategoryData>> getHazardCategories() async {
    final response = await ApiService.get('/hazard-categories');
    if (!response.success) return const [];
    final raw = _asList(response.data['data']);
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e);
      final subs = _asList(m['subcategories']).map((s) {
        final sm = Map<String, dynamic>.from(s);
        return HazardSubcategoryData(
          id: sm['id']?.toString() ?? '',
          name: sm['name']?.toString() ?? '',
        );
      }).where((s) => s.name.isNotEmpty).toList();
      return HazardCategoryData(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        code: m['code']?.toString() ?? '',
        subcategories: subs,
      );
    }).where((c) => c.name.isNotEmpty).toList();
  }

  static Report _mapHazardReport(Map<String, dynamic> json) {
    final severity =
        _severityFromApi(json['severity']?.toString()) ?? ReportSeverity.medium;
    final rawStatus = json['status']?.toString();
    final rawSubStatus = json['sub_status']?.toString();
    return Report(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '-',
      description: json['description']?.toString() ?? '-',
      type: ReportType.hazard,
      category: _hazardCategoryFromApi(json['hazard_category']?.toString()),
      subkategori: json['hazard_subcategory']?.toString(),
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
      imageUrl: _safeImageUrl(json['image_url']?.toString()),
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
      createdAt: _parseDate(json['created_at']),
      reportedBy: _reportedBy(json['reported_by']),
      reporterId: _reporterId(json['reported_by']),
      imageUrl: _safeImageUrl(json['image_url']?.toString()),
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
    return ReportLogEntry(
      status: _statusFromApi(rawStatus),
      subStatus: _subStatusFromApi(rawSubStatus) ??
          (rawStatus == 'rejected' ? ReportSubStatus.rejected : null),
      timestamp: _parseDate(json['created_at']),
      actor: json['user_name']?.toString().trim().isNotEmpty == true
          ? json['user_name'].toString()
          : 'System',
      note: json['message']?.toString(),
      photoUrl: normalizeStorageUrl(json['image_url']?.toString()),
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

  static String _safeImageUrl(String? raw) {
    final normalized = normalizeStorageUrl(raw);
    if (normalized == null || normalized.trim().isEmpty) return _placeholderImage;
    return normalized;
  }

  static ReportStatus _statusFromApi(String? status) {
    switch (status) {
      case 'in_progress':
        return ReportStatus.inProgress;
      case 'closed':
      case 'rejected':
        return ReportStatus.closed;
      case 'pending':
        return ReportStatus.pending;
      case 'open':
      default:
        return ReportStatus.open;
    }
  }

  static String _statusToApi(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return 'pending';
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

  static HazardCategory? _hazardCategoryFromApi(String? value) {
    switch (value) {
      case 'TTA':
        return HazardCategory.unsafeAct;
      case 'KTA':
        return HazardCategory.unsafeCondition;
      default:
        return null;
    }
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
}

class HazardSubcategoryData {
  final String id;
  final String name;
  const HazardSubcategoryData({required this.id, required this.name});
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
