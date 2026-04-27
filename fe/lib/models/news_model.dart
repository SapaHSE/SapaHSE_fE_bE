class NewsModel {
  final String id;
  final String title;
  final String excerpt;
  final String category;
  final String? authorName;
  final String? imageUrl;
  final bool isFeatured;
  final String? date;
  final String? content;
  final String? createdAt;

  const NewsModel({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.category,
    this.authorName,
    this.imageUrl,
    this.isFeatured = false,
    this.date,
    this.content,
    this.createdAt,
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
      content: json['content']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
