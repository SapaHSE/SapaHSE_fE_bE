import '../utils/url_helper.dart';

enum ReportType { hazard, inspection }

enum ReportSeverity { low, medium, high, critical }

enum ReportStatus { pending, open, inProgress, closed }

// Sub-kategori hazard / inspection
enum HazardCategory {
  unsafeAct,
  unsafeCondition,
  nearMiss,
  propertyDamage,
  environmentalHazard,
  spill,
  slipTripFall,
  fireSafety,
  // Inspection types
  routineInspection,
  electricalInspection,
  equipmentInspection,
}

// Sub-status per kategori utama
enum ReportSubStatus {
  // Open
  validating,
  approved,
  assigned,
  // In Progress
  preparing,
  executing,
  reviewing,
  // Closed
  resolved,
  rejected,
  deferred,
}

class ChecklistItem {
  final String id;
  final String label;
  final bool isChecked;
  final int sortOrder;

  const ChecklistItem({
    required this.id,
    required this.label,
    required this.isChecked,
    required this.sortOrder,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      isChecked: json['is_checked'] == true || json['is_checked'] == 1,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class Report {
  final String id;
  final String title;
  final String description;
  final ReportType type;
  final HazardCategory? category;
  final String? subkategori; // hazard_subcategory from API
  final ReportSeverity severity;
  final ReportStatus status;
  final ReportSubStatus? subStatus;
  final String location;
  final String? saran; // suggestion from API
  final String? departemen; // reported_department from API
  final String? picDepartment;
  final String? pelakuPelanggaran;
  final String? pelaporLocation;
  final String? kejadianLocation;
  final String? company;
  final bool? isPublic;
  final DateTime? dueDate;
  final int? sisaHari;
  final bool isOverdue;
  final DateTime createdAt;
  final String reportedBy;
  final String? reporterId;
  final String imageUrl;
  final String? ticketNumber;

  // Inspection specific fields
  final String? area;
  final String? nameInspector;
  final String? notes;
  final List<ChecklistItem>? checklistItems;

  const Report({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.category,
    this.subkategori,
    required this.severity,
    required this.status,
    this.subStatus,
    required this.location,
    this.saran,
    this.departemen,
    this.picDepartment,
    this.pelakuPelanggaran,
    this.pelaporLocation,
    this.kejadianLocation,
    this.company,
    this.isPublic,
    this.dueDate,
    this.sisaHari,
    this.isOverdue = false,
    required this.createdAt,
    required this.reportedBy,
    this.reporterId,
    required this.imageUrl,
    this.ticketNumber,
    this.area,
    this.nameInspector,
    this.notes,
    this.checklistItems,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() == 'inspection'
        ? ReportType.inspection
        : ReportType.hazard;
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
      type: type,
      category: _categoryFromApi(
          json['hazard_category']?.toString(), type, json['area']?.toString()),
      subkategori: json['hazard_subcategory']?.toString(),
      severity: _severityFromApi(
          json['severity']?.toString(), json['result']?.toString()),
      status: _statusFromApi(rawStatus),
      subStatus: _subStatusFromApi(rawSubStatus) ??
          (rawStatus == 'rejected' ? ReportSubStatus.rejected : null),
      location: json['location']?.toString() ?? '-',
      saran: json['suggestion']?.toString(),
      departemen: json['reported_department']?.toString(),
      picDepartment:
          json['pic_department']?.toString() ?? json['name_pja']?.toString(),
      pelakuPelanggaran: json['pelaku_pelanggaran']?.toString(),
      pelaporLocation: json['pelapor_location']?.toString(),
      kejadianLocation: json['kejadian_location']?.toString(),
      company: json['company']?.toString() ??
          (json['reported_by'] is Map
              ? json['reported_by']['company']?.toString()
              : null),
      isPublic: json['is_public'] as bool?,
      dueDate: _parseDateOrNull(json['due_date']),
      sisaHari: (json['sisa_hari'] as num?)?.toInt(),
      isOverdue: json['is_overdue'] == true ||
          ((json['sisa_hari'] as num?)?.toInt() ?? 0) < 0,
      createdAt: _parseDate(json['created_at']),
      reportedBy: _parseReportedBy(json['reported_by']),
      reporterId: _parseReporterId(json['reported_by']),
      imageUrl: normalizeStorageUrl(json['image_url']?.toString()) ??
          'https://placehold.co/600x400?text=No+Image',
      ticketNumber: json['ticket_number']?.toString(),
      area: json['area']?.toString(),
      nameInspector: json['name_inspector']?.toString(),
      notes: json['notes']?.toString(),
      checklistItems: checklistItems,
    );
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
      default:
        return ReportStatus.open;
    }
  }

  static ReportSubStatus? _subStatusFromApi(String? subStatus) {
    if (subStatus == null || subStatus.isEmpty) return null;
    try {
      return ReportSubStatus.values.firstWhere((e) => e.name == subStatus);
    } catch (_) {
      return null;
    }
  }

  static ReportSeverity _severityFromApi(String? severity, String? result) {
    if (severity != null) {
      switch (severity) {
        case 'low':
          return ReportSeverity.low;
        case 'medium':
          return ReportSeverity.medium;
        case 'high':
          return ReportSeverity.high;
        case 'critical':
          return ReportSeverity.critical;
      }
    }
    if (result != null) {
      switch (result) {
        case 'non_compliant':
          return ReportSeverity.high;
        case 'needs_follow_up':
          return ReportSeverity.medium;
        case 'compliant':
          return ReportSeverity.low;
      }
    }
    return ReportSeverity.medium;
  }

  static HazardCategory? _categoryFromApi(
      String? cat, ReportType type, String? area) {
    if (type == ReportType.hazard) {
      switch (cat) {
        case 'TTA':
          return HazardCategory.unsafeAct;
        case 'KTA':
          return HazardCategory.unsafeCondition;
      }
    } else {
      final normalized = (area ?? '').toLowerCase();
      if (normalized.contains('listrik') || normalized.contains('electrical')) {
        return HazardCategory.electricalInspection;
      }
      if (normalized.contains('alat') || normalized.contains('equipment')) {
        return HazardCategory.equipmentInspection;
      }
      return HazardCategory.routineInspection;
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

  static String _parseReportedBy(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['full_name']?.toString() ?? 'Unknown User';
    }
    return raw?.toString() ?? 'Unknown User';
  }

  static String? _parseReporterId(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['id']?.toString();
    }
    return null;
  }
}

extension ReportTypeLabel on ReportType {
  String get label {
    switch (this) {
      case ReportType.hazard:
        return 'Hazard';
      case ReportType.inspection:
        return 'Inspection';
    }
  }
}

extension HazardCategoryLabel on HazardCategory {
  String get label {
    switch (this) {
      case HazardCategory.unsafeAct:
        return 'Unsafe Act';
      case HazardCategory.unsafeCondition:
        return 'Unsafe Condition';
      case HazardCategory.nearMiss:
        return 'Near Miss';
      case HazardCategory.propertyDamage:
        return 'Property Damage';
      case HazardCategory.environmentalHazard:
        return 'Environmental Hazard';
      case HazardCategory.spill:
        return 'Spill';
      case HazardCategory.slipTripFall:
        return 'Slip, Trip, Fall';
      case HazardCategory.fireSafety:
        return 'Fire Safety';
      case HazardCategory.routineInspection:
        return 'Routine Inspection';
      case HazardCategory.electricalInspection:
        return 'Electrical Inspection';
      case HazardCategory.equipmentInspection:
        return 'Equipment Inspection';
    }
  }
}

extension ReportSeverityLabel on ReportSeverity {
  String get label {
    switch (this) {
      case ReportSeverity.low:
        return 'Low';
      case ReportSeverity.medium:
        return 'Medium';
      case ReportSeverity.high:
        return 'High';
      case ReportSeverity.critical:
        return 'Critical';
    }
  }
}

extension ReportStatusLabel on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.pending:
        return 'Dalam Pengecekan Admin';
      case ReportStatus.open:
        return 'Open';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.closed:
        return 'Closed';
    }
  }
}

extension ReportSubStatusInfo on ReportSubStatus {
  String get label {
    switch (this) {
      case ReportSubStatus.validating:
        return 'Validating';
      case ReportSubStatus.approved:
        return 'Approved';
      case ReportSubStatus.assigned:
        return 'Assigned';
      case ReportSubStatus.preparing:
        return 'Preparing';
      case ReportSubStatus.executing:
        return 'Executing';
      case ReportSubStatus.reviewing:
        return 'Reviewing';
      case ReportSubStatus.resolved:
        return 'Resolved';
      case ReportSubStatus.rejected:
        return 'Rejected';
      case ReportSubStatus.deferred:
        return 'Deferred';
    }
  }

  ReportStatus get parentStatus {
    switch (this) {
      case ReportSubStatus.validating:
      case ReportSubStatus.approved:
      case ReportSubStatus.assigned:
        return ReportStatus.open;
      case ReportSubStatus.preparing:
      case ReportSubStatus.executing:
      case ReportSubStatus.reviewing:
        return ReportStatus.inProgress;
      case ReportSubStatus.resolved:
      case ReportSubStatus.rejected:
      case ReportSubStatus.deferred:
        return ReportStatus.closed;
    }
  }

  static List<ReportSubStatus> forStatus(ReportStatus s) {
    switch (s) {
      case ReportStatus.pending:
        return [];
      case ReportStatus.open:
        return [
          ReportSubStatus.validating,
          ReportSubStatus.approved,
          ReportSubStatus.assigned
        ];
      case ReportStatus.inProgress:
        return [
          ReportSubStatus.preparing,
          ReportSubStatus.executing,
          ReportSubStatus.reviewing
        ];
      case ReportStatus.closed:
        return [
          ReportSubStatus.resolved,
          ReportSubStatus.rejected,
          ReportSubStatus.deferred
        ];
    }
  }
}
