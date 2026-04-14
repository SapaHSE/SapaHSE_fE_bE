import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../data/dummy_data.dart';

// ── Timeline event model ───────────────────────────────────────────────────────
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

// ── ReportStore ───────────────────────────────────────────────────────────────
class ReportStore {
  ReportStore._();
  static final ReportStore instance = ReportStore._();

  // Mutable report list
  final ValueNotifier<List<Report>> reports = ValueNotifier(
    dummyReports.map((r) => r).toList(),
  );

  // Timeline per report ID — seed awal dari status laporan dummy
  final Map<String, List<TimelineEvent>> _timelines = {};

  // ── Get timeline untuk satu report ────────────────────────────────────────
  List<TimelineEvent> getTimeline(String reportId) {
    if (!_timelines.containsKey(reportId)) {
      final report = getById(reportId);
      if (report != null) {
        _timelines[reportId] = _seedTimeline(report);
      }
    }
    return List.unmodifiable(_timelines[reportId] ?? []);
  }

  // ── Inisialisasi timeline awal dari dummy data ─────────────────────────────
  static List<TimelineEvent> _seedTimeline(Report r) {
    final base = r.createdAt;
    final events = <TimelineEvent>[
      TimelineEvent(
        status: ReportStatus.open,
        subStatus: ReportSubStatus.validating,
        timestamp: base,
        actor: r.reportedBy,
        note: 'Laporan dibuat dan sedang divalidasi.',
      ),
    ];

    if (r.status == ReportStatus.open) {
      // Seed sub-steps for open if subStatus tells us how far we are
      final sub = r.subStatus;
      if (sub == ReportSubStatus.approved || sub == ReportSubStatus.assigned) {
        events.add(TimelineEvent(
          status: ReportStatus.open,
          subStatus: ReportSubStatus.approved,
          timestamp: base.add(const Duration(hours: 1)),
          actor: 'Supervisor HSE',
          note: 'Laporan telah divalidasi dan disetujui.',
        ));
      }
      if (sub == ReportSubStatus.assigned) {
        events.add(TimelineEvent(
          status: ReportStatus.open,
          subStatus: ReportSubStatus.assigned,
          timestamp: base.add(const Duration(hours: 2)),
          actor: 'Admin HSE',
          note: 'Laporan ditugaskan kepada tim terkait.',
        ));
      }
    }

    if (r.status == ReportStatus.inProgress || r.status == ReportStatus.closed) {
      events.addAll([
        TimelineEvent(
          status: ReportStatus.open,
          subStatus: ReportSubStatus.approved,
          timestamp: base.add(const Duration(hours: 1)),
          actor: 'Supervisor HSE',
          note: 'Laporan telah divalidasi dan disetujui.',
        ),
        TimelineEvent(
          status: ReportStatus.open,
          subStatus: ReportSubStatus.assigned,
          timestamp: base.add(const Duration(hours: 2)),
          actor: 'Admin HSE',
          note: 'Laporan ditugaskan kepada tim terkait.',
        ),
        TimelineEvent(
          status: ReportStatus.inProgress,
          subStatus: ReportSubStatus.preparing,
          timestamp: base.add(const Duration(hours: 3)),
          actor: 'Tim HSE',
          note: 'Tim sedang mempersiapkan penanganan.',
        ),
      ]);

      final sub = r.subStatus;
      if (sub == ReportSubStatus.executing || sub == ReportSubStatus.reviewing) {
        events.add(TimelineEvent(
          status: ReportStatus.inProgress,
          subStatus: ReportSubStatus.executing,
          timestamp: base.add(const Duration(hours: 5)),
          actor: 'Tim HSE',
          note: 'Penanganan sedang dilaksanakan di lapangan.',
        ));
      }
      if (sub == ReportSubStatus.reviewing) {
        events.add(TimelineEvent(
          status: ReportStatus.inProgress,
          subStatus: ReportSubStatus.reviewing,
          timestamp: base.add(const Duration(hours: 7)),
          actor: 'Supervisor HSE',
          note: 'Hasil penanganan sedang direview.',
        ));
      }
    }

    if (r.status == ReportStatus.closed) {
      events.addAll([
        TimelineEvent(
          status: ReportStatus.inProgress,
          subStatus: ReportSubStatus.executing,
          timestamp: base.add(const Duration(hours: 5)),
          actor: 'Tim HSE',
          note: 'Penanganan sedang dilaksanakan di lapangan.',
        ),
        TimelineEvent(
          status: ReportStatus.inProgress,
          subStatus: ReportSubStatus.reviewing,
          timestamp: base.add(const Duration(hours: 7)),
          actor: 'Supervisor HSE',
          note: 'Hasil penanganan sedang direview.',
        ),
        TimelineEvent(
          status: ReportStatus.closed,
          subStatus: r.subStatus ?? ReportSubStatus.resolved,
          timestamp: base.add(const Duration(days: 1)),
          actor: 'Admin HSE',
          note: 'Penanganan selesai dan laporan ditutup.',
        ),
      ]);
    }

    return events;
  }

  // ── Update status + sub-status + tambah event ke timeline ─────────────────
  Report updateStatus(
    String id,
    ReportStatus newStatus, {
    ReportSubStatus? newSubStatus,
    String actor = 'User',
    String? note,
    String? photoPath,
  }) {
    final list = List<Report>.from(reports.value);
    final idx = list.indexWhere((r) => r.id == id);
    if (idx == -1) throw ArgumentError('Report $id tidak ditemukan');

    final old = list[idx];
    final updated = Report(
      id:          old.id,
      title:       old.title,
      description: old.description,
      type:        old.type,
      category:    old.category,
      severity:    old.severity,
      status:      newStatus,
      subStatus:   newSubStatus,
      location:    old.location,
      createdAt:   old.createdAt,
      reportedBy:  old.reportedBy,
      imageUrl:    old.imageUrl,
    );
    list[idx] = updated;
    reports.value = list;

    // Append timeline event
    _timelines.putIfAbsent(id, () => _seedTimeline(old));
    _timelines[id]!.add(TimelineEvent(
      status:    newStatus,
      subStatus: newSubStatus,
      timestamp: DateTime.now(),
      actor:     actor,
      note:      note ?? _defaultNote(newStatus, newSubStatus),
      photoPath: photoPath,
    ));

    return updated;
  }

  String _defaultNote(ReportStatus s, ReportSubStatus? sub) {
    if (sub != null) {
      switch (sub) {
        case ReportSubStatus.validating: return 'Laporan sedang divalidasi.';
        case ReportSubStatus.approved:   return 'Laporan telah disetujui.';
        case ReportSubStatus.assigned:   return 'Laporan telah ditugaskan.';
        case ReportSubStatus.preparing:  return 'Tim sedang mempersiapkan penanganan.';
        case ReportSubStatus.executing:  return 'Penanganan sedang dilaksanakan.';
        case ReportSubStatus.reviewing:  return 'Hasil penanganan sedang direview.';
        case ReportSubStatus.resolved:   return 'Laporan selesai ditangani dan ditutup.';
        case ReportSubStatus.rejected:   return 'Laporan ditolak.';
        case ReportSubStatus.deferred:   return 'Penanganan laporan ditunda.';
      }
    }
    switch (s) {
      case ReportStatus.open:       return 'Status dikembalikan ke Open.';
      case ReportStatus.inProgress: return 'Laporan sedang ditindaklanjuti.';
      case ReportStatus.closed:     return 'Laporan selesai ditangani dan ditutup.';
    }
  }

  // ── Get report by ID ───────────────────────────────────────────────────────
  Report? getById(String id) {
    try {
      return reports.value.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}