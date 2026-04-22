import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/report.dart';
import 'api_service.dart';
import 'storage_service.dart';

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
    String? namePja,
    String? department,
    String? hazardCategory,
    String? hazardSubcategory,
    String? suggestion,
    String? imagePath,
    bool isPublic = true,
  }) async {
    final payload = await _sendMultipart(
      endpoint: '/hazard-reports',
      method: 'POST',
      fields: {
        'title': title,
        'description': description,
        'location': location,
        if (severity != null && severity.isNotEmpty) 'severity': severity,
        if (namePja != null && namePja.isNotEmpty) 'name_pja': namePja,
        if (department != null && department.isNotEmpty)
          'reported_department': department,
        if (hazardCategory != null && hazardCategory.isNotEmpty)
          'hazard_category': hazardCategory,
        if (hazardSubcategory != null && hazardSubcategory.isNotEmpty)
          'hazard_subcategory': hazardSubcategory,
        if (suggestion != null && suggestion.isNotEmpty)
          'suggestion': suggestion,
        // Backend expects camelCase key `isPublic` and parses it as boolean.
        'isPublic': isPublic.toString(),
      },
      imagePath: imagePath,
    );

    if (!payload.success) {
      return ReportActionResult.error(
          payload.errorMessage ?? 'Gagal kirim laporan hazard.');
    }

    final rawData = payload.data['data'];
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
    final payload = await _sendMultipart(
      endpoint: '/inspection-reports',
      method: 'POST',
      fields: {
        'title': title,
        'description': description,
        'location': location,
        if (area != null && area.isNotEmpty) 'area': area,
        if (inspector != null && inspector.isNotEmpty) 'inspector': inspector,
        if (result != null && result.isNotEmpty) 'result': result,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (checklistItems != null)
          'checklist_items': jsonEncode(checklistItems),
      },
      imagePath: imagePath,
    );

    if (!payload.success) {
      return ReportActionResult.error(
        payload.errorMessage ?? 'Gagal kirim laporan inspeksi.',
      );
    }

    final rawData = payload.data['data'];
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
  }) async {
    final endpoint = report.type == ReportType.hazard
        ? '/hazard-reports/${report.id}/status'
        : '/inspection-reports/${report.id}/status';

    final payload = await _sendMultipart(
      endpoint: endpoint,
      method: 'POST',
      fields: {
        'status': _statusToApi(status),
        if (subStatus != null) 'sub_status': subStatus.name,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
        if (taggedUserId != null && taggedUserId.isNotEmpty)
          'tagged_user_id': taggedUserId,
      },
      imagePath: imagePath,
    );

    if (!payload.success) {
      return ReportActionResult.error(
        payload.errorMessage ?? 'Gagal memperbarui status laporan.',
      );
    }

    final rawData = payload.data['data'];
    if (rawData is! Map<String, dynamic>) {
      return ReportActionResult.error('Respons server tidak valid.');
    }

    return ReportActionResult.success(
      report.type == ReportType.hazard
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
        photoUrl: m['photo_url']?.toString(),
      );
    }).where((u) => u.id.isNotEmpty).toList();
  }

  static Future<List<String>> getDepartments() async {
    final response = await ApiService.get('/departments');
    if (!response.success) return const [];
    final raw = _asList(response.data['data']);
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static Report _mapHazardReport(Map<String, dynamic> json) {
    final severity =
        _severityFromApi(json['severity']?.toString()) ?? ReportSeverity.medium;
    return Report(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '-',
      description: json['description']?.toString() ?? '-',
      type: ReportType.hazard,
      category: _hazardCategoryFromApi(json['hazard_category']?.toString()),
      subkategori: json['hazard_subcategory']?.toString(),
      severity: severity,
      status: _statusFromApi(json['status']?.toString()),
      subStatus: _subStatusFromApi(json['sub_status']?.toString()),
      location: json['location']?.toString() ?? '-',
      saran: json['suggestion']?.toString(),
      departemen: json['reported_department']?.toString(),
      tagOrang: json['name_pja']?.toString(),
      createdAt: _parseDate(json['created_at']),
      reportedBy: _reportedBy(json['reported_by']),
      reporterId: _reporterId(json['reported_by']),
      imageUrl: _safeImageUrl(json['image_url']?.toString()),
      ticketNumber: json['ticket_number']?.toString(),
    );
  }

  static Report _mapInspectionReport(Map<String, dynamic> json) {
    final result = json['result']?.toString();
    return Report(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '-',
      description: json['description']?.toString() ?? '-',
      type: ReportType.inspection,
      category: _inspectionCategoryFromArea(json['area']?.toString()),
      severity: _severityFromInspectionResult(result),
      status: _statusFromApi(json['status']?.toString()),
      subStatus: _subStatusFromApi(json['sub_status']?.toString()),
      location: json['location']?.toString() ?? '-',
      createdAt: _parseDate(json['created_at']),
      reportedBy: _reportedBy(json['reported_by']),
      reporterId: _reporterId(json['reported_by']),
      imageUrl: _safeImageUrl(json['image_url']?.toString()),
      ticketNumber: json['ticket_number']?.toString(),
    );
  }

  static ReportLogEntry _mapLogEntry(Map<String, dynamic> json) {
    return ReportLogEntry(
      status: _statusFromApi(json['status']?.toString()),
      subStatus: _subStatusFromApi(json['sub_status']?.toString()),
      timestamp: _parseDate(json['created_at']),
      actor: json['user_name']?.toString().trim().isNotEmpty == true
          ? json['user_name'].toString()
          : 'System',
      note: json['message']?.toString(),
      photoUrl: json['image_url']?.toString(),
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

  static String _safeImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _placeholderImage;
    return raw;
  }

  static ReportStatus _statusFromApi(String? status) {
    switch (status) {
      case 'in_progress':
        return ReportStatus.inProgress;
      case 'closed':
        return ReportStatus.closed;
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

  static Future<_MultipartResult> _sendMultipart({
    required String endpoint,
    required String method,
    required Map<String, String> fields,
    String? imagePath,
  }) async {
    try {
      final token = await StorageService.getToken();
      final req = http.MultipartRequest(
        method,
        Uri.parse('${ApiService.baseUrl}$endpoint'),
      );

      req.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }

      req.fields.addAll(fields);
      if (imagePath != null && imagePath.isNotEmpty) {
        req.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed);

      final decoded = _safeDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map && decoded['status'] == 'success') {
          return _MultipartResult.success(Map<String, dynamic>.from(decoded));
        }
        return _MultipartResult.error(
          _extractMessage(decoded) ?? 'Respons server tidak valid.',
          response.statusCode,
        );
      }

      return _MultipartResult.error(
        _extractMessage(decoded) ?? 'Terjadi kesalahan server.',
        response.statusCode,
      );
    } catch (e) {
      return _MultipartResult.error('Unexpected error: $e', null);
    }
  }

  static dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String? _extractMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
      }
      final msg = body['message'];
      if (msg != null) return msg.toString();
    }
    return null;
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

class _MultipartResult {
  final bool success;
  final Map<String, dynamic> data;
  final String? errorMessage;
  final int? statusCode;

  _MultipartResult._({
    required this.success,
    this.data = const {},
    this.errorMessage,
    this.statusCode,
  });

  factory _MultipartResult.success(Map<String, dynamic> data) =>
      _MultipartResult._(success: true, data: data);

  factory _MultipartResult.error(String message, int? statusCode) =>
      _MultipartResult._(
        success: false,
        errorMessage: message,
        statusCode: statusCode,
      );
}
