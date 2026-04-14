import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../data/news_data.dart';
import 'news_detail_screen.dart';
import '../widgets/sapa_hse_header.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final PageController _carouselController = PageController();
  int _currentCarouselPage = 0;
  Timer? _carouselTimer;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All News';

  List<NewsArticle> get _featuredArticles =>
      dummyNews.where((a) => a.isFeatured).toList();

  List<NewsArticle> get _allFilteredArticles {
    return dummyNews.where((a) {
      final matchCat = _selectedCategory == 'All News' || a.category == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty || a.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _startCarousel();
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_carouselController.hasClients) return;
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
    _searchController.dispose();
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
    return Material(
      color: const Color(0xFFF2F2F2),
      child: SafeArea(
        child: Column(
          children: [
            SapaHseHeader(
              isSearching: _isSearching,
              searchController: _searchController,
              searchHint: 'Cari berita...',
              onSearchChanged: (v) => setState(() => _searchQuery = v),
              onSearchToggle: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image: category top-left, title + author + date bottom ──
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF37474F),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white38, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF37474F),
                        child: const Icon(Icons.image,
                            color: Colors.white38, size: 40),
                      ),
                    ),
                  ),

                  // Category badge — pojok kiri atas
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  // Gradient bawah + judul + author + tanggal
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 60, 12, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.88),
                            Colors.transparent
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Judul
                          Text(
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
                          const SizedBox(height: 6),
                          // Author + date row
                          Row(children: [
                            const Icon(Icons.person_outline,
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              article.author,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                    color: Colors.white38,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            const Icon(Icons.calendar_today_outlined,
                                size: 11, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              article.date,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white70),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Excerpt ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: Text(
                  article.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54, height: 1.5),
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
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.88)],
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