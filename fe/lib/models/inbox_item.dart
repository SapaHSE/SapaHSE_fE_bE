import 'report.dart';

enum InboxItemType { report, announcement }

class InboxReporter {
  final String fullName;
  final String? employeeId;
  final String? department;
  final String? company;

  const InboxReporter({
    required this.fullName,
    this.employeeId,
    this.department,
    this.company,
  });

  factory InboxReporter.fromJson(Map<String, dynamic> json) {
    return InboxReporter(
      fullName: json['full_name']?.toString() ?? 'Unknown',
      employeeId: json['employee_id']?.toString(),
      department: json['department']?.toString(),
      company: json['company']?.toString(),
    );
  }
}

class InboxAuthor {
  final String fullName;
  final String? position;

  const InboxAuthor({required this.fullName, this.position});

  factory InboxAuthor.fromJson(Map<String, dynamic> json) {
    return InboxAuthor(
      fullName: json['full_name']?.toString() ?? 'Admin',
      position: json['position']?.toString(),
    );
  }
}

class InboxChecklistItem {
  final String id;
  final String label;
  final bool isChecked;
  final int sortOrder;

  const InboxChecklistItem({
    required this.id,
    required this.label,
    required this.isChecked,
    required this.sortOrder,
  });

  factory InboxChecklistItem.fromJson(Map<String, dynamic> json) {
    return InboxChecklistItem(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      isChecked: json['is_checked'] == true || json['is_checked'] == 1,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }
}

class InboxItem {
  final String id;
  final InboxItemType itemType;
  bool isRead; // mutable for optimistic updates
  final String title;
  final DateTime createdAt;
  final String? timeAgo;

  // Report-only
  final ReportType? reportType;
  final String? description;
  final ReportStatus? status;
  final String? location;
  final String? imageUrl;
  final ReportSeverity? severity;
  final String? namePja;
  final String? reportedDepartment;
  final String? area;
  final String? result;
  final String? notes;
  final List<InboxChecklistItem> checklistItems;
  final InboxReporter? reportedBy;
  final String? ticketNumber;

  // Announcement-only
  final String? body;
  final String? fromName;
  final InboxAuthor? createdBy;

  InboxItem({
    required this.id,
    required this.itemType,
    required this.isRead,
    required this.title,
    required this.createdAt,
    this.timeAgo,
    this.reportType,
    this.description,
    this.status,
    this.location,
    this.imageUrl,
    this.severity,
    this.namePja,
    this.reportedDepartment,
    this.area,
    this.result,
    this.notes,
    this.checklistItems = const [],
    this.reportedBy,
    this.ticketNumber,
    this.body,
    this.fromName,
    this.createdBy,
  });

  factory InboxItem.fromJson(Map<String, dynamic> json) {
    final type = json['item_type']?.toString() == 'announcement'
        ? InboxItemType.announcement
        : InboxItemType.report;

    final createdAt = _parseDate(json['created_at']);

    if (type == InboxItemType.announcement) {
      final rawCreator = json['created_by'];
      return InboxItem(
        id: json['id']?.toString() ?? '',
        itemType: InboxItemType.announcement,
        isRead: json['is_read'] == true,
        title: json['title']?.toString() ?? '-',
        createdAt: createdAt,
        timeAgo: json['time_ago']?.toString(),
        body: json['body']?.toString() ?? '',
        fromName: (json['from_name'] ?? json['from'] ?? 'Admin').toString(),
        createdBy: rawCreator is Map<String, dynamic>
            ? InboxAuthor.fromJson(rawCreator)
            : null,
      );
    }

    final rawReporter = json['reported_by'];
    final rawChecklist = json['checklist_items'];
    final checklistList = rawChecklist is List
        ? rawChecklist
            .whereType<Map>()
            .map((m) =>
                InboxChecklistItem.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : const <InboxChecklistItem>[];

    return InboxItem(
      id: json['id']?.toString() ?? '',
      itemType: InboxItemType.report,
      isRead: json['is_read'] == true,
      title: json['title']?.toString() ?? '-',
      createdAt: createdAt,
      timeAgo: json['time_ago']?.toString(),
      reportType: _parseReportType(json['type']?.toString()),
      description: json['description']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      location: json['location']?.toString() ?? '-',
      imageUrl: json['image_url']?.toString(),
      severity: _parseSeverity(json['severity']?.toString()),
      namePja: json['name_pja']?.toString(),
      reportedDepartment: json['reported_department']?.toString(),
      area: json['area']?.toString(),
      result: json['result']?.toString(),
      notes: json['notes']?.toString(),
      checklistItems: checklistList,
      reportedBy: rawReporter is Map<String, dynamic>
          ? InboxReporter.fromJson(rawReporter)
          : null,
      ticketNumber: json['ticket_number']?.toString(),
    );
  }

  /// Builds a minimal [Report] for navigation into ReportDetailScreen.
  Report toReport() {
    return Report(
      id: id,
      title: title,
      description: description ?? '',
      type: reportType ?? ReportType.hazard,
      severity: severity ?? ReportSeverity.medium,
      status: status ?? ReportStatus.open,
      location: location ?? '-',
      createdAt: createdAt,
      reportedBy: reportedBy?.fullName ?? 'Unknown User',
      imageUrl: (imageUrl == null || imageUrl!.isEmpty)
          ? 'https://placehold.co/600x400?text=No+Image'
          : imageUrl!,
      ticketNumber: ticketNumber,
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    final parsed = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    return parsed?.toLocal() ?? DateTime.now();
  }

  static ReportType? _parseReportType(String? raw) {
    switch (raw) {
      case 'hazard':
        return ReportType.hazard;
      case 'inspection':
        return ReportType.inspection;
      default:
        return null;
    }
  }

  static ReportStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'in_progress':
        return ReportStatus.inProgress;
      case 'closed':
        return ReportStatus.closed;
      case 'open':
      default:
        return ReportStatus.open;
    }
  }

  static ReportSeverity _parseSeverity(String? raw) {
    switch (raw) {
      case 'low':
        return ReportSeverity.low;
      case 'high':
        return ReportSeverity.high;
      case 'critical':
        return ReportSeverity.critical;
      case 'medium':
      default:
        return ReportSeverity.medium;
    }
  }
}
