enum ReportType { hazard, inspection }
enum ReportSeverity { low, medium, high }
enum ReportStatus { open, inProgress, closed }

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

class Report {
  final String id;
  final String title;
  final String description;
  final ReportType type;
  final ReportSeverity severity;
  final ReportStatus status;
  final ReportSubStatus? subStatus;
  final String location;
  final DateTime createdAt;
  final String reportedBy;
  final String imageUrl;

  const Report({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.severity,
    required this.status,
    this.subStatus,
    required this.location,
    required this.createdAt,
    required this.reportedBy,
    required this.imageUrl,
  });
}

extension ReportTypeLabel on ReportType {
  String get label {
    switch (this) {
      case ReportType.hazard:     return 'Hazard';
      case ReportType.inspection: return 'Inspection';
    }
  }
}

extension ReportSeverityLabel on ReportSeverity {
  String get label {
    switch (this) {
      case ReportSeverity.low:    return 'Low';
      case ReportSeverity.medium: return 'Medium';
      case ReportSeverity.high:   return 'High';
    }
  }
}

extension ReportStatusLabel on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.open:       return 'Open';
      case ReportStatus.inProgress: return 'In Progress';
      case ReportStatus.closed:     return 'Closed';
    }
  }
}

extension ReportSubStatusInfo on ReportSubStatus {
  String get label {
    switch (this) {
      case ReportSubStatus.validating: return 'Validating';
      case ReportSubStatus.approved:   return 'Approved';
      case ReportSubStatus.assigned:   return 'Assigned';
      case ReportSubStatus.preparing:  return 'Preparing';
      case ReportSubStatus.executing:  return 'Executing';
      case ReportSubStatus.reviewing:  return 'Reviewing';
      case ReportSubStatus.resolved:   return 'Resolved';
      case ReportSubStatus.rejected:   return 'Rejected';
      case ReportSubStatus.deferred:   return 'Deferred';
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
      case ReportStatus.open:
        return [ReportSubStatus.validating, ReportSubStatus.approved, ReportSubStatus.assigned];
      case ReportStatus.inProgress:
        return [ReportSubStatus.preparing, ReportSubStatus.executing, ReportSubStatus.reviewing];
      case ReportStatus.closed:
        return [ReportSubStatus.resolved, ReportSubStatus.rejected, ReportSubStatus.deferred];
    }
  }
}