class NewsModel {
  final String id;
  final String title;
  final String excerpt;
  final String category;
  final String? authorName;
  final String? imageUrl;
  final bool isFeatured;
  final String? date;
  final String? publishDate;
  final String? publishDateLabel;
  final bool isScheduled;
  final String? content;
  final String? createdAt;
  final List<String> hashtags;

  const NewsModel({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.category,
    this.authorName,
    this.imageUrl,
    this.isFeatured = false,
    this.date,
    this.publishDate,
    this.publishDateLabel,
    this.isScheduled = false,
    this.content,
    this.createdAt,
    this.hashtags = const [],
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      authorName: json['author_name']?.toString(),
      imageUrl: json['image_url']?.toString(),
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
      date: json['date']?.toString(),
      publishDate: json['publish_date']?.toString(),
      publishDateLabel: json['publish_date_label']?.toString(),
      isScheduled: json['is_scheduled'] == true || json['is_scheduled'] == 1,
      content: json['content']?.toString(),
      createdAt: json['created_at']?.toString(),
      hashtags: _parseHashtags(json['hashtags']),
    );
  }

  static List<String> _parseHashtags(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim().toLowerCase() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    return const [];
  }
}
