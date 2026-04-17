import 'api_service.dart';
import '../data/news_data.dart';

class NewsService {
  // GET /news — loads all active news (client-side filtering in screen)
  static Future<NewsListResult> getNews() async {
    final response = await ApiService.get('/news?per_page=100');

    if (!response.success) {
      return NewsListResult.error(
          response.errorMessage ?? 'Gagal memuat berita.');
    }

    final data = response.data['data'] as List<dynamic>?;
    if (data == null) {
      return NewsListResult.error('Respons server tidak valid.');
    }

    final articles = data
        .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
        .toList();

    return NewsListResult.success(articles);
  }

  // GET /news/{id} — loads full article including content
  static Future<NewsDetailResult> getNewsDetail(String id) async {
    final response = await ApiService.get('/news/$id');

    if (!response.success) {
      return NewsDetailResult.error(
          response.errorMessage ?? 'Gagal memuat detail berita.');
    }

    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) {
      return NewsDetailResult.error('Respons server tidak valid.');
    }

    return NewsDetailResult.success(NewsArticle.fromJson(data));
  }
}

// ── RESULT WRAPPERS ───────────────────────────────────────────────────────────

class NewsListResult {
  final bool success;
  final List<NewsArticle> articles;
  final String? errorMessage;

  NewsListResult._({
    required this.success,
    this.articles = const [],
    this.errorMessage,
  });

  factory NewsListResult.success(List<NewsArticle> articles) =>
      NewsListResult._(success: true, articles: articles);

  factory NewsListResult.error(String message) =>
      NewsListResult._(success: false, errorMessage: message);
}

class NewsDetailResult {
  final bool success;
  final NewsArticle? article;
  final String? errorMessage;

  NewsDetailResult._({
    required this.success,
    this.article,
    this.errorMessage,
  });

  factory NewsDetailResult.success(NewsArticle article) =>
      NewsDetailResult._(success: true, article: article);

  factory NewsDetailResult.error(String message) =>
      NewsDetailResult._(success: false, errorMessage: message);
}
