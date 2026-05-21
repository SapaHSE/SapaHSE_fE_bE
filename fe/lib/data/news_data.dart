import '../utils/url_helper.dart';

class NewsArticle {
  final String id;
  final String title;
  final String excerpt;
  final String content;
  final String category;
  final String author;
  final String date;
  final DateTime? createdAt;
  final DateTime? publishDate;
  final String? publishDateLabel;
  final String imageUrl;
  final bool isFeatured;
  final bool isScheduled;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.category,
    required this.author,
    required this.date,
    this.createdAt,
    this.publishDate,
    this.publishDateLabel,
    required this.imageUrl,
    this.isFeatured = false,
    this.isScheduled = false,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      author: json['author_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      publishDate: _parseDate(json['publish_date']),
      publishDateLabel: json['publish_date_label']?.toString(),
      imageUrl: normalizeStorageUrl(json['image_url']?.toString()) ?? '',
      isFeatured: json['is_featured'] == true,
      isScheduled: json['is_scheduled'] == true,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'))?.toLocal();
  }
}

const List<String> newsCategories = [
  'All News',
  'K3 / HSE',
  'Operasional',
  'Regulasi',
  'Prestasi',
];

// Sentinel used by the news_screen category dropdown to surface scheduled
// drafts as a status filter rather than a real backend category.
const String kScheduledFilterValue = '__scheduled__';
const String kScheduledFilterLabel = 'Terjadwal';
