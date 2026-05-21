import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../data/news_data.dart';
import '../services/news_service.dart';
import '../services/storage_service.dart';
import 'news_detail_screen.dart';
import '../widgets/sapa_hse_header.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/minimal_dropdown.dart';

class _FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget Function(BuildContext) builder;
  _FadePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
}

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

  bool _isAdmin = false;
  bool _showScheduledOnly = false;

  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String? _error;

  List<NewsArticle> get _featuredArticles =>
      _articles.where((a) => a.isFeatured).toList();

  List<NewsArticle> get _allFilteredArticles {
    return _articles.where((a) {
      final matchCat =
          _selectedCategory == 'All News' || a.category == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          a.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _detectRole();
    _loadNews();
  }

  Future<void> _detectRole() async {
    final user = await StorageService.getUser();
    final role = user?['role']?.toString().toLowerCase();
    if (mounted) {
      setState(() => _isAdmin = role == 'admin' || role == 'superadmin');
    }
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result =
        await NewsService.getNews(onlyScheduled: _showScheduledOnly);
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _articles = result.articles;
        _isLoading = false;
      });
      _startCarousel();
    } else {
      setState(() {
        _error = result.errorMessage;
        _isLoading = false;
      });
    }
  }

  void _toggleScheduled(bool value) {
    if (_showScheduledOnly == value) return;
    setState(() => _showScheduledOnly = value);
    _carouselTimer?.cancel();
    _currentCarouselPage = 0;
    _loadNews();
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    if (_featuredArticles.isEmpty) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_carouselController.hasClients) return;
      final featured = _featuredArticles;
      if (featured.isEmpty) return;
      final next = (_currentCarouselPage + 1) % featured.length;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_carouselController.hasClients) {
          _carouselController.animateToPage(
            next,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
          );
        }
      });
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
      _FadePageRoute(builder: (_) => NewsDetailScreen(article: article)),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'K3 / HSE':
        return const Color(0xFF1A56C4);
      case 'Operasional':
        return const Color(0xFF1565C0);
      case 'Regulasi':
        return const Color(0xFFE65100);
      case 'Prestasi':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF37474F);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F2F2),
      child: SafeArea(
        bottom: false,
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadNews,
                          child: CustomScrollView(
                            slivers: [
                              // ── Admin scheduled toggle ────────────────────
                              if (_isAdmin)
                                SliverToBoxAdapter(
                                    child: _buildScheduledToggleRow()),

                              // ── Carousel (hidden in scheduled view) ──────
                              if (!_showScheduledOnly)
                                SliverToBoxAdapter(child: _buildCarousel()),

                              // ── Category Filter (hidden in scheduled view)
                              if (!_showScheduledOnly)
                                SliverToBoxAdapter(child: _buildCategoryFilter()),

                              // ── Article List ──────────────────────────────
                              _allFilteredArticles.isEmpty
                                  ? SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: _buildEmptyState(),
                                    )
                                  : SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (_, i) => _buildArticleCard(
                                            _allFilteredArticles[i]),
                                        childCount: _allFilteredArticles.length,
                                      ),
                                    ),

                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height:
                                      AppSafeInsets.bottomNavScrollPadding(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Gagal memuat berita',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadNews,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final scheduled = _showScheduledOnly;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              scheduled ? Icons.schedule_outlined : Icons.article_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              scheduled
                  ? 'Tidak ada berita terjadwal'
                  : 'Tidak ada berita di kategori ini',
              style: const TextStyle(
                  color: Color(0xFF455A64),
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
            if (scheduled) ...[
              const SizedBox(height: 6),
              const Text(
                'Berita yang dijadwalkan ke masa depan akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── ADMIN SCHEDULED TOGGLE ──────────────────────────────────────────────────
  Widget _buildScheduledToggleRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: _ScheduledFilterPill(
              active: !_showScheduledOnly,
              label: 'Semua',
              icon: Icons.article_outlined,
              accent: const Color(0xFF1A56C4),
              onTap: () => _toggleScheduled(false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ScheduledFilterPill(
              active: _showScheduledOnly,
              label: 'Terjadwal',
              icon: Icons.schedule_outlined,
              accent: const Color(0xFFE65100),
              onTap: () => _toggleScheduled(true),
            ),
          ),
        ],
      ),
    );
  }

  // ── ADMIN ACTION SHEET ─────────────────────────────────────────────────────
  void _openAdminSheet(NewsArticle article) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminScheduledSheet(
        article: article,
        onPublishNow: () async {
          Navigator.pop(ctx);
          await _publishNow(article);
        },
        onDelete: () async {
          Navigator.pop(ctx);
          await _confirmDelete(article);
        },
      ),
    );
  }

  Future<void> _publishNow(NewsArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Mempublikasikan...'),
        duration: Duration(seconds: 1),
      ),
    );
    final result = await NewsService.publishNow(article.id);
    if (!mounted) return;
    if (result.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Berita "${article.title}" telah dipublikasikan.'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _loadNews();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Gagal mempublikasikan.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _confirmDelete(NewsArticle article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Berita'),
        content: Text(
            'Hapus "${article.title}"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final res = await NewsService.deleteNews(article.id);
    if (!mounted) return;
    if (res.success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Berita dihapus.')),
      );
      _loadNews();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Gagal menghapus berita.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  // ── CAROUSEL ────────────────────────────────────────────────────────────────
  Widget _buildCarousel() {
    final featured = _featuredArticles;
    if (featured.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(
            child: Text('Tidak ada berita unggulan',
                style: TextStyle(color: Colors.grey))),
      );
    }
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _carouselController,
            itemCount: featured.length,
            onPageChanged: (i) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _currentCarouselPage = i);
              });
            },
            itemBuilder: (_, i) => _CarouselItem(
              article: featured[i],
              onTap: () => _goToDetail(featured[i]),
            ),
          ),

          // Left arrow
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
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
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // Right arrow
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final next = (_currentCarouselPage + 1) % featured.length;
                  _carouselController.animateToPage(next,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // Dots + author/date
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Row(
              children: [
                // Dots
                Row(
                  children: List.generate(
                      featured.length,
                      (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: i == _currentCarouselPage ? 20 : 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: i == _currentCarouselPage
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.person_outline,
                    color: Colors.white70, size: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'NEWS TYPE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          MinimalDropdown<String>(
            value: _selectedCategory,
            items: newsCategories.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(cat, style: kMinimalDropdownTextStyle),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedCategory = val);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── ARTICLE CARD ─────────────────────────────────────────────────────────────
  Widget _buildArticleCard(NewsArticle article) {
    final catColor = _categoryColor(article.category);
    return GestureDetector(
      onTap: () => _goToDetail(article),
      onLongPress: _isAdmin ? () => _openAdminSheet(article) : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2)),
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

                  // Gradient + title + author + date
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 60, 100, 10),
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
                          Row(children: [
                            const Icon(Icons.person_outline,
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                article.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500),
                              ),
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

                  // Category badge — rendered LAST so it floats above the gradient
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.35,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          article.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),

                  // Scheduled pill — top-left
                  if (article.isScheduled)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule,
                                size: 11, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'TERJADWAL',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5),
                            ),
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
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.88)
                ],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
          // Title
          Positioned(
            left: 16,
            right: 52,
            bottom: 38,
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

// ── SCHEDULED FILTER PILL ─────────────────────────────────────────────────────
class _ScheduledFilterPill extends StatelessWidget {
  final bool active;
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ScheduledFilterPill({
    required this.active,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? accent : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? accent : const Color(0xFFE0E4EA),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: active ? Colors.white : const Color(0xFF455A64)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF455A64),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ADMIN SCHEDULED ACTION SHEET ──────────────────────────────────────────────
class _AdminScheduledSheet extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onPublishNow;
  final VoidCallback onDelete;

  const _AdminScheduledSheet({
    required this.article,
    required this.onPublishNow,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppSafeInsets.sheetBottomPadding(context, base: 32),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Kelola Berita Terjadwal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF607D8B)),
            ),
          ),
          if (article.isScheduled)
            _AdminMenuTile(
              icon: Icons.send_rounded,
              iconBgColor: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              title: 'Publikasikan Sekarang',
              subtitle: 'Tayangkan langsung & kirim notifikasi push',
              onTap: onPublishNow,
            ),
          if (article.isScheduled)
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _AdminMenuTile(
            icon: Icons.delete_outline_rounded,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: Colors.red.shade700,
            title: 'Hapus Berita',
            subtitle: 'Tindakan ini tidak dapat dibatalkan',
            onTap: onDelete,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminMenuTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
