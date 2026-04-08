import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../data/news_data.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final PageController _carouselController = PageController();
  int _currentCarouselPage = 0;
  Timer? _carouselTimer;
  String _selectedCategory = 'All News';

  List<NewsArticle> get _featuredArticles =>
      dummyNews.where((a) => a.isFeatured).toList();

  List<NewsArticle> get _allFilteredArticles {
    if (_selectedCategory == 'All News') return dummyNews;
    return dummyNews.where((a) => a.category == _selectedCategory).toList();
  }

  @override
  void initState() {
    super.initState();
    _startCarousel();
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentCarouselPage + 1) % _featuredArticles.length;
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  void _goToDetail(NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article)),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'K3 / HSE':   return const Color(0xFF1A56C4);
      case 'Operasional': return const Color(0xFF1565C0);
      case 'Regulasi':   return const Color(0xFFE65100);
      case 'Prestasi':   return const Color(0xFF6A1B9A);
      default:           return const Color(0xFF37474F);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56C4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SapaHse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A56C4))),
                      Text('PT. Bukit Baiduri Energi', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: CustomScrollView(
                slivers: [
                  // ── Carousel ──────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildCarousel()),

                  // ── Category Filter Dropdown ───────────────────────────
                  SliverToBoxAdapter(child: _buildCategoryFilter()),

                  // ── Article List ──────────────────────────────────────
                  _allFilteredArticles.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Tidak ada berita di kategori ini',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _buildArticleCard(_allFilteredArticles[i]),
                            childCount: _allFilteredArticles.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CAROUSEL ────────────────────────────────────────────────────────────────
  Widget _buildCarousel() {
    final featured = _featuredArticles;
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _carouselController,
            itemCount: featured.length,
            onPageChanged: (i) => setState(() => _currentCarouselPage = i),
            itemBuilder: (_, i) => _CarouselItem(
              article: featured[i],
              onTap: () => _goToDetail(featured[i]),
            ),
          ),

          // Left arrow
          Positioned(
            left: 8, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final prev = _currentCarouselPage > 0
                      ? _currentCarouselPage - 1
                      : featured.length - 1;
                  _carouselController.animateToPage(prev,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // Right arrow
          Positioned(
            right: 8, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final next = (_currentCarouselPage + 1) % featured.length;
                  _carouselController.animateToPage(next,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // Dots + author/date
          Positioned(
            left: 16, right: 16, bottom: 12,
            child: Row(
              children: [
                // Dots
                Row(
                  children: List.generate(featured.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _currentCarouselPage ? 20 : 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == _currentCarouselPage ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.person_outline, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${featured[_currentCarouselPage].author}  •  ${featured[_currentCarouselPage].date}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── CATEGORY FILTER ─────────────────────────────────────────────────────────
  Widget _buildCategoryFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            items: newsCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
        ),
      ),
    );
  }

  // ── ARTICLE CARD ─────────────────────────────────────────────────────────────
  Widget _buildArticleCard(NewsArticle article) {
    final catColor = _categoryColor(article.category);
    return GestureDetector(
      onTap: () => _goToDetail(article),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image with title overlay ────────────────────────────
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 185,
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF37474F),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF37474F),
                        child: const Icon(Icons.image, color: Colors.white38, size: 40),
                      ),
                    ),
                  ),
                  // Gradient + title
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 50, 12, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.88), Colors.transparent],
                        ),
                      ),
                      child: Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Meta ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      article.author,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    Container(width: 3, height: 3,
                        decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(article.date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        article.category,
                        style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Excerpt ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
                    children: [
                      TextSpan(
                        text: '${article.title.split(',').first}  ',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      TextSpan(text: article.excerpt),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CAROUSEL ITEM ─────────────────────────────────────────────────────────────
class _CarouselItem extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  const _CarouselItem({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: article.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF263238)),
            errorWidget: (_, __, ___) => Container(
              color: const Color(0xFF263238),
              child: const Icon(Icons.image, color: Colors.white24, size: 60),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.88)],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
          // Title
          Positioned(
            left: 16, right: 52, bottom: 38,
            child: Text(
              article.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.35,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}