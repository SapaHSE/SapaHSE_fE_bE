enum ReportType { hazard, inspection }
enum ReportSeverity { low, medium, high }
enum ReportStatus { open, inProgress, closed }

class Report {
  final String id;
  final String title;
  final String description;
  final ReportType type;
  final ReportSeverity severity;
  final ReportStatus status;
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