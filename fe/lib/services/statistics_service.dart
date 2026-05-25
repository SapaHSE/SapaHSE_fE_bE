import 'api_service.dart';

class PersonalStatistics {
  final int total;
  final int accepted;
  final int rejected;
  final int inProgress;
  final int pending;
  final double accuracy;
  final int streak;
  final double categoryAccuracy;
  final int categoryTarget;
  final String categoryMessage;
  final int avgValidationMinutes;
  final double avgProcessingDays;
  final double avgTotalDays;
  final String avgValidationLabel;
  final String avgProcessingLabel;
  final String avgTotalLabel;
  final List<AwardItem> awards;
  final int needsCategoryAdjustment;

  const PersonalStatistics({
    required this.total,
    required this.accepted,
    required this.rejected,
    required this.inProgress,
    required this.pending,
    required this.accuracy,
    required this.streak,
    required this.categoryAccuracy,
    required this.categoryTarget,
    required this.categoryMessage,
    required this.avgValidationMinutes,
    required this.avgProcessingDays,
    required this.avgTotalDays,
    required this.avgValidationLabel,
    required this.avgProcessingLabel,
    required this.avgTotalLabel,
    required this.awards,
    required this.needsCategoryAdjustment,
  });

  factory PersonalStatistics.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final category = json['category_accuracy'] as Map<String, dynamic>? ?? {};
    final speed = json['handling_speed'] as Map<String, dynamic>? ?? {};
    final rawAwards = json['awards'] as List<dynamic>? ?? [];

    return PersonalStatistics(
      total: (summary['total'] as num?)?.toInt() ?? 0,
      accepted: (summary['accepted'] as num?)?.toInt() ?? 0,
      rejected: (summary['rejected'] as num?)?.toInt() ?? 0,
      inProgress: (summary['in_progress'] as num?)?.toInt() ?? 0,
      pending: (summary['pending'] as num?)?.toInt() ?? 0,
      accuracy: (summary['accuracy'] as num?)?.toDouble() ?? 0.0,
      streak: (summary['streak'] as num?)?.toInt() ?? 0,
      categoryAccuracy: (category['percentage'] as num?)?.toDouble() ?? 0.0,
      categoryTarget: (category['target'] as num?)?.toInt() ?? 90,
      categoryMessage: category['message']?.toString() ?? '',
      avgValidationMinutes: (speed['avg_validation_minutes'] as num?)?.toInt() ?? 0,
      avgProcessingDays: (speed['avg_processing_days'] as num?)?.toDouble() ?? 0.0,
      avgTotalDays: (speed['avg_total_days'] as num?)?.toDouble() ?? 0.0,
      avgValidationLabel: speed['avg_validation_label']?.toString() ?? '0 mnt',
      avgProcessingLabel: speed['avg_processing_label']?.toString() ?? '0 hari',
      avgTotalLabel: speed['avg_total_label']?.toString() ?? '0 hari',
      awards: rawAwards.map((e) => AwardItem.fromJson(e as Map<String, dynamic>)).toList(),
      needsCategoryAdjustment: (json['needs_category_adjustment'] as num?)?.toInt() ?? 0,
    );
  }
}

class AwardItem {
  final String title;
  final String date;
  final String type;
  final String icon;
  final String color;

  const AwardItem({
    required this.title,
    required this.date,
    required this.type,
    required this.icon,
    required this.color,
  });

  factory AwardItem.fromJson(Map<String, dynamic> json) {
    return AwardItem(
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'emoji_events',
      color: json['color']?.toString() ?? '#FFB300',
    );
  }
}

class StatisticsResult {
  final bool success;
  final PersonalStatistics? stats;
  final String? errorMessage;

  StatisticsResult._({required this.success, this.stats, this.errorMessage});

  factory StatisticsResult.success(PersonalStatistics stats) =>
      StatisticsResult._(success: true, stats: stats);

  factory StatisticsResult.error(String message) =>
      StatisticsResult._(success: false, errorMessage: message);
}

class StatisticsService {
  static Future<StatisticsResult> fetchPersonalStatistics({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String>[];
    if (startDate != null) params.add('start_date=$startDate');
    if (endDate != null) params.add('end_date=$endDate');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';

    final response = await ApiService.get('/profile/statistics$query');

    if (!response.success) {
      return StatisticsResult.error(
        response.errorMessage ?? 'Gagal memuat statistik.',
      );
    }

    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) {
      return StatisticsResult.error('Respons server tidak valid.');
    }

    return StatisticsResult.success(PersonalStatistics.fromJson(data));
  }
}
