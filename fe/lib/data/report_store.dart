import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../services/cloud_save_service.dart';
import '../services/report_service.dart';

class TimelineEvent {
  final String timelineLogId;
  final ReportStatus status;
  final ReportSubStatus? subStatus;
  final DateTime timestamp;
  final String actor;
  final String? note;
  final List<String> photoPaths;
  final int replyCount;
  final DateTime? latestReplyAt;

  const TimelineEvent({
    required this.timelineLogId,
    required this.status,
    this.subStatus,
    required this.timestamp,
    required this.actor,
    this.note,
    this.photoPaths = const [],
    this.replyCount = 0,
    this.latestReplyAt,
  });

  /// Konvenien: ambil foto pertama (untuk UI lama yang baru perlu satu).
  String? get photoPath => photoPaths.isNotEmpty ? photoPaths.first : null;
}

class ReportStore {
  ReportStore._();
  static final ReportStore instance = ReportStore._();

  final ValueNotifier<List<Report>> reports = ValueNotifier<List<Report>>([]);
  final Map<String, List<TimelineEvent>> _timelines = {};
  final Map<String, List<TimelineReply>> _logReplies = {};

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

  Future<Report> fetchReport(String id, ReportType type) async {
    final result = await ReportService.getReportDetails(id, type);
    if (!result.success || result.report == null) {
      throw Exception(result.errorMessage ?? 'Gagal memuat detail laporan dari server.');
    }
    _upsertReport(result.report!);
    return result.report!;
  }

  Future<Report> createHazardReport({
    required String title,
    required String description,
    required String location,
    required String severity,
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
    final result = await ReportService.createHazardReport(
      title: title,
      description: description,
      location: location,
      severity: severity,
      company: company,
      area: area,
      picDepartment: picDepartment,
      department: department,
      hazardCategory: hazardCategory,
      hazardSubcategory: hazardSubcategory,
      suggestion: suggestion,
      pelakuPelanggaran: pelakuPelanggaran,
      pelaporLocation: pelaporLocation,
      kejadianLocation: kejadianLocation,
      imagePaths: imagePaths,
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
    String? reportedDepartment,
    String? result,
    String? notes,
    List<Map<String, dynamic>>? checklistItems,
    List<String> imagePaths = const [],
  }) async {
    final response = await ReportService.createInspectionReport(
      title: title,
      description: description,
      location: location,
      area: area,
      inspector: inspector,
      reportedDepartment: reportedDepartment,
      result: result,
      notes: notes,
      checklistItems: checklistItems,
      imagePaths: imagePaths,
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
    List<String> photoPaths = const [],
    String? taggedUserId,
    String? department,
    String? picDepartment,
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
      imagePaths: photoPaths,
      taggedUserId: taggedUserId,
      department: department,
      picDepartment: picDepartment,
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

  List<TimelineReply> getReplies(String logId) {
    return List.unmodifiable(_logReplies[logId] ?? const <TimelineReply>[]);
  }

  Future<List<TimelineReply>> loadReplies(String reportId, String logId, {bool force = false}) async {
    if (!force && _logReplies.containsKey(logId)) {
      return getReplies(logId);
    }
    final report = getById(reportId);
    if (report == null) return const <TimelineReply>[];
    final replies = await ReportService.getLogReplies(report: report, logId: logId);
    _logReplies[logId] = replies;
    return getReplies(logId);
  }

  Future<TimelineReply> postReply(
    String reportId,
    String logId,
    String message, {
    String? parentReplyId,
    String? attachmentUrl,
    List<String> attachmentUrls = const [],
  }) async {
    final report = getById(reportId);
    if (report == null) {
      throw Exception('Report $reportId tidak ditemukan.');
    }
    final reply = await ReportService.postLogReply(
      report: report,
      logId: logId,
      message: message,
      parentReplyId: parentReplyId,
      attachmentUrl: attachmentUrl,
      attachmentUrls: attachmentUrls,
    );
    if (reply == null) {
      throw Exception('Gagal mengirim balasan.');
    }
    _logReplies.remove(logId);
    await loadTimeline(reportId, force: true);
    await loadReplies(reportId, logId, force: true);
    return reply;
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
        timelineLogId: entry.id,
        status: entry.status,
        subStatus: entry.subStatus,
        timestamp: entry.timestamp,
        actor: entry.actor,
        note: entry.note,
        photoPaths: entry.photoUrls,
        replyCount: entry.replyCount,
        latestReplyAt: entry.latestReplyAt,
      );
    }).toList();

    _timelines[reportId] = _normalizeTimeline(
      events.isEmpty ? _buildFallbackTimeline(report) : events,
      report,
    );
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
          company: draft.data['perusahaan']?.toString(),
          area: draft.data['area']?.toString(),
          picDepartment: draft.data['pic']?.toString(),
          department: draft.data['departemen']?.toString(),
          hazardCategory: draft.data['kategori']?.toString(),
          hazardSubcategory: draft.data['subkategori']?.toString(),
          suggestion: draft.data['saran']?.toString(),
          pelakuPelanggaran: draft.data['pelakuPelanggaran']?.toString(),
          pelaporLocation: draft.data['pelaporLocation']?.toString(),
          kejadianLocation: draft.data['kejadianLocation']?.toString(),
          imagePaths: _draftPhotoPaths(draft),
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
          reportedDepartment: draft.data['reported_department']?.toString(),
          area: draft.data['area']?.toString(),
          result: _inspectionResultUiToApi(draft.data['result']?.toString()),
          notes: draft.data['notes']?.toString(),
          checklistItems: checklistItems,
          imagePaths: _draftPhotoPaths(draft),
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
    return _normalizeTimeline(
      [
        TimelineEvent(
          timelineLogId: 'fallback-${report.id}',
          status: report.status,
          subStatus: report.subStatus,
          timestamp: report.createdAt,
          actor: report.reportedBy,
          note: 'Laporan dibuat.',
        ),
      ],
      report,
    );
  }

  List<TimelineEvent> _normalizeTimeline(
    List<TimelineEvent> rawEvents,
    Report report,
  ) {
    final events = List<TimelineEvent>.from(rawEvents)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (events.isEmpty) return events;

    final normalized = <TimelineEvent>[];
    final seen = <ReportSubStatus>{};

    for (final event in events) {
      final subStatus = event.subStatus;
      if (subStatus != null) {
        final missing = _missingPrerequisites(subStatus, seen);
        for (var i = 0; i < missing.length; i++) {
          final sub = missing[i];
          normalized.add(_implicitTimelineEvent(
            sub,
            report,
            event.timestamp.subtract(
              Duration(milliseconds: missing.length - i),
            ),
          ));
          seen.add(sub);
        }
        seen.add(subStatus);
      }
      normalized.add(TimelineEvent(
        timelineLogId: event.timelineLogId,
        status: event.status,
        subStatus: event.subStatus,
        timestamp: event.timestamp,
        actor: event.actor,
        note: _sanitizeTimelineNote(event.note, event.subStatus),
        photoPaths: event.photoPaths,
        replyCount: event.replyCount,
        latestReplyAt: event.latestReplyAt,
      ));
    }

    return normalized;
  }

  List<ReportSubStatus> _missingPrerequisites(
    ReportSubStatus target,
    Set<ReportSubStatus> seen,
  ) {
    final index = _normalFlow.indexOf(target);
    if (index <= 0) return const <ReportSubStatus>[];
    return _normalFlow.take(index).where((sub) => !seen.contains(sub)).toList();
  }

  TimelineEvent _implicitTimelineEvent(
    ReportSubStatus subStatus,
    Report report,
    DateTime timestamp,
  ) {
    return TimelineEvent(
      timelineLogId: 'implicit-${report.id}-${subStatus.name}-${timestamp.millisecondsSinceEpoch}',
      status: subStatus.parentStatus,
      subStatus: subStatus,
      timestamp: timestamp,
      actor: subStatus == ReportSubStatus.assigned
          ? _assignmentActor(report)
          : (subStatus == ReportSubStatus.validating ? report.reportedBy : ''),
      note: null,
    );
  }

  String _assignmentActor(Report report) {
    final values = <String>[
      if (report.departemen?.trim().isNotEmpty == true) report.departemen!.trim(),
      if (report.picDepartment?.trim().isNotEmpty == true)
        report.picDepartment!.trim(),
      if (report.nameInspector?.trim().isNotEmpty == true)
        report.nameInspector!.trim(),
    ];
    return values.join(', ');
  }

  static const List<ReportSubStatus> _normalFlow = [
    ReportSubStatus.validating,
    ReportSubStatus.approved,
    ReportSubStatus.assigned,
    ReportSubStatus.preparing,
    ReportSubStatus.executing,
    ReportSubStatus.reviewing,
    ReportSubStatus.resolved,
  ];

  String? _sanitizeTimelineNote(String? note, ReportSubStatus? subStatus) {
    if (note == null || note.trim().isEmpty) return null;
    if (subStatus == ReportSubStatus.assigned) return note;

    final lines = note
        .split('\n')
        .where((line) => !line.trimLeft().toLowerCase().startsWith('tag:'))
        .toList();
    final cleaned = lines.join('\n').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Ambil daftar path foto dari draft offline.
  /// Mendukung key baru `photoPaths` (list) dan key lama `photoPath` (string).
  List<String> _draftPhotoPaths(ReportDraft draft) {
    final raw = draft.data['photoPaths'];
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final single = draft.data['photoPath']?.toString();
    if (single != null && single.isNotEmpty) return [single];
    return const [];
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
