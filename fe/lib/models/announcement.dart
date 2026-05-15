import 'package:intl/intl.dart';

import '../utils/url_helper.dart';

class Announcement {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final bool isUrgent;
  final bool isRead;
  final String? creatorName;
  final String? creatorCompany;
  final DateTime createdAt;
  final String timeAgo;
  final DateTime? expiresAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.isUrgent = false,
    this.isRead = false,
    this.creatorName,
    this.creatorCompany,
    required this.createdAt,
    required this.timeAgo,
    this.expiresAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final createdBy = json['created_by'];
    final creator = createdBy is Map
        ? Map<String, dynamic>.from(createdBy)
        : const <String, dynamic>{};

    return Announcement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      imageUrl: normalizeStorageUrl(json['image_url']?.toString()),
      isUrgent: json['is_urgent'] == true ||
          json['is_urgent'] == 1 ||
          json['is_urgent']?.toString() == '1',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      creatorName: creator['full_name']?.toString() ??
          json['from_name']?.toString() ??
          json['from']?.toString(),
      creatorCompany: creator['company']?.toString(),
      createdAt: _parseDate(json['created_at']),
      timeAgo: json['time_ago']?.toString() ?? '',
      expiresAt: _tryParseDate(json['expires_at']),
    );
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy, HH:mm').format(createdAt);
  }

  int? get remainingDays {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    final diff = expiresAt!.difference(now);
    if (diff.isNegative) return 0;
    final days = diff.inDays;
    return diff.inHours > (days * 24) ? days + 1 : days;
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    final parsed = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    return parsed?.toLocal() ?? DateTime.now();
  }

  static DateTime? _tryParseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'))?.toLocal();
  }
}
