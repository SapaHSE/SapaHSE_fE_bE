import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../services/cloud_save_service.dart';
import '../services/report_service.dart';

class TimelineEvent {
  final ReportStatus status;
  final ReportSubStatus? subStatus;
  final DateTime timestamp;
  final String actor;
  final String? note;
  final String? photoPath;

  const TimelineEvent({
    required this.status,
    this.subStatus,
    required this.timestamp,
    required this.actor,
    this.note,
    this.photoPath,
  });
}

class ReportStore {
  ReportStore._();
  static final ReportStore instance = ReportStore._();

  final ValueNotifier<List<Report>> reports = ValueNotifier<List<Report>>([]);
  final Map<String, List<TimelineEvent>> _timelines = {};

  bool _isRefreshing = false;

  Future<void> refreshReports() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final result = await ReportService.getReports(perPage: 100);
      if (!result.success) {
        throw Exception(result.errorMessage ?? 'Gagal memuat laporan.');
      }
      reports.value = result.reports;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Report> createHazardReport({
    required String title,
    required String description,
    required String location,
    required String severity,
    String? namePja,
    String? department,
    String? hazardCategory,
    String? hazardSubcategory,
    String? suggestion,
    String? imagePath,
    bool isPublic = true,
  }) async {
    final result = await ReportService.createHazardReport(
      title: title,
      description: description,
      location: location,
      severity: severity,
      namePja: namePja,
      department: department,
      hazardCategory: hazardCategory,
      hazardSubcategory: hazardSubcategory,
      suggestion: suggestion,
      imagePath: imagePath,
      isPublic: isPublic,
    );
    if (!result.success || result.report == null) {
      throw Exception(result.errorMessage ?? 'Gagal mengirim laporan hazard.');
    }
    _upsertReport(result.report!, prepend: true);
    await loadTimeline(result.report!.id, force: true);
    return result.report!;
  }

  Future<Report> createInspectionReport({
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
    final response = await ReportService.createInspectionReport(
      title: title,
      description: description,
      location: location,
      area: area,
      inspector: inspector,
      result: result,
      notes: notes,
      checklistItems: checklistItems,
      imagePath: imagePath,
    );
    if (!response.success || response.report == null) {
      throw Exception(response.errorMessage ?? 'Gagal mengirim laporan inspeksi.');
    }
    _upsertReport(response.report!, prepend: true);
    await loadTimeline(response.report!.id, force: true);
    return response.report!;
  }

  Future<Report> updateStatus(
    String id,
    ReportStatus newStatus, {
    ReportSubStatus? newSubStatus,
    String? note,
    String? photoPath,
    String? taggedUserId,
  }) async {
    final report = getById(id);
    if (report == null) {
      throw Exception('Report $id tidak ditemukan.');
    }

    final result = await ReportService.updateReportStatus(
      report: report,
      status: newStatus,
      subStatus: newSubStatus,
      message: note,
      imagePath: photoPath,
      taggedUserId: taggedUserId,
    );
    if (!result.success || result.report == null) {
      throw Exception(result.errorMessage ?? 'Gagal memperbarui status laporan.');
    }

    _upsertReport(result.report!);
    await loadTimeline(id, force: true);
    return result.report!;
  }

  List<TimelineEvent> getTimeline(String reportId) {
    return List.unmodifiable(_timelines[reportId] ?? const <TimelineEvent>[]);
  }

  Future<List<TimelineEvent>> loadTimeline(
    String reportId, {
    bool force = false,
  }) async {
    if (!force && _timelines.containsKey(reportId)) {
      return getTimeline(reportId);
    }

    final report = getById(reportId);
    if (report == null) {
      return const <TimelineEvent>[];
    }

    final logsResult = await ReportService.getLogs(report);
    if (!logsResult.success) {
      final fallback = _buildFallbackTimeline(report);
      _timelines[reportId] = fallback;
      return fallback;
    }

    final events = logsResult.logs.map((entry) {
      return TimelineEvent(
        status: entry.status,
        subStatus: entry.subStatus,
        timestamp: entry.timestamp,
        actor: entry.actor,
        note: entry.note,
        photoPath: entry.photoUrl,
      );
    }).toList();

    _timelines[reportId] =
        events.isEmpty ? _buildFallbackTimeline(report) : events;
    return getTimeline(reportId);
  }

  Future<bool> submitDraft(ReportDraft draft) async {
    try {
      if (draft.type == DraftType.hazard) {
        final severityRaw = (draft.data['severity']?.toString() ?? '').trim();
        final severityApi =
            severityRaw.isEmpty ? 'medium' : severityRaw.toLowerCase();
        final isPublicRaw = draft.data['isPublic'];
        final isPublic = switch (isPublicRaw) {
          null => true,
          final bool v => v,
          _ => () {
              final s = isPublicRaw.toString().trim().toLowerCase();
              if (s == 'false' || s == '0' || s == 'no' || s == 'off') {
                return false;
              }
              return true;
            }(),
        };

        await createHazardReport(
          title: (draft.data['title']?.toString() ?? '').trim(),
          description: (draft.data['kronologi']?.toString() ?? '').trim(),
          location: (draft.data['location']?.toString() ?? '').trim(),
          severity: severityApi,
          namePja: draft.data['pja']?.toString(),
          department: draft.data['departemen']?.toString(),
          hazardCategory: draft.data['kategori']?.toString(),
          hazardSubcategory: draft.data['subkategori']?.toString(),
          suggestion: draft.data['saran']?.toString(),
          imagePath: draft.data['photoPath']?.toString(),
          isPublic: isPublic,
        );
      } else {
        final checklistRaw = draft.data['checklist'];
        final checklistItems = checklistRaw is List
            ? checklistRaw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : const <Map<String, dynamic>>[];

        await createInspectionReport(
          title: (draft.data['title']?.toString() ?? '').trim(),
          description: (draft.data['notes']?.toString() ?? '').trim().isEmpty
              ? 'Laporan inspeksi dari draft offline.'
              : (draft.data['notes']?.toString() ?? '').trim(),
          location: (draft.data['location']?.toString() ?? '').trim(),
          inspector: draft.data['inspector']?.toString(),
          area: draft.data['area']?.toString(),
          result: _inspectionResultUiToApi(draft.data['result']?.toString()),
          notes: draft.data['notes']?.toString(),
          checklistItems: checklistItems,
          imagePath: draft.data['photoPath']?.toString(),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Report? getById(String id) {
    try {
      return reports.value.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  void _upsertReport(Report report, {bool prepend = false}) {
    final current = List<Report>.from(reports.value);
    final idx = current.indexWhere((r) => r.id == report.id);
    if (idx >= 0) {
      current[idx] = report;
    } else if (prepend) {
      current.insert(0, report);
    } else {
      current.add(report);
    }
    current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    reports.value = current;
  }

  List<TimelineEvent> _buildFallbackTimeline(Report report) {
    return [
      TimelineEvent(
        status: report.status,
        subStatus: report.subStatus,
        timestamp: report.createdAt,
        actor: report.reportedBy,
        note: 'Laporan dibuat.',
      ),
    ];
  }

  String? _inspectionResultUiToApi(String? uiValue) {
    switch (uiValue) {
      case 'Sesuai':
      case 'compliant':
        return 'compliant';
      case 'Tidak Sesuai':
      case 'non_compliant':
        return 'non_compliant';
      case 'Perlu Tindak Lanjut':
      case 'needs_follow_up':
        return 'needs_follow_up';
      default:
        return null;
    }
  }
}
