import '../utils/url_helper.dart';

class NewsArticle {
  final String id;
  final String title;
  final String excerpt;
  final String content;
  final String category;
  final String author;
  final String date;
  final String imageUrl;
  final bool isFeatured;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.category,
    required this.author,
    required this.date,
    required this.imageUrl,
    this.isFeatured = false,
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
      imageUrl: normalizeStorageUrl(json['image_url']?.toString()) ?? '',
      isFeatured: json['is_featured'] == true,
    );
  }
}

const List<String> newsCategories = [
  'All News',
  'K3 / HSE',
  'Operasional',
  'Regulasi',
  'Prestasi',
];
