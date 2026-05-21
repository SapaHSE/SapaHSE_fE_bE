import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/news_data.dart';
import '../services/news_service.dart';
import 'package:sapahse/main.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/fab_notched_bottom_bar.dart';

class _FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget Function(BuildContext) builder;
  _FadePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
}

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  const NewsDetailScreen({super.key, required this.article});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  NewsArticle? _fullArticle;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await NewsService.getNewsDetail(widget.article.id);
    if (!mounted) return;

    if (result.success && result.article != null) {
      setState(() {
        _fullArticle = result.article;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.errorMessage;
        _isLoading = false;
      });
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'K3 / HSE':
        return const Color(0xFF2E7D32);
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

  void _onTabTapped(int index) {
    Navigator.pushReplacement(
      context,
      _FadePageRoute(builder: (_) => MainScreen(initialIndex: index)),
    );
  }

  void _openFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NewsDetailFabMenuSheet(
        articleTitle: widget.article.title,
        onRefresh: _loadDetail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = _fullArticle ?? widget.article;
    final catColor = _categoryColor(article.category);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: CustomScrollView(
        slivers: [
          // SliverAppBar with hero image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.black87,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            actions: const [], // Actions moved to FAB
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFF37474F)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF37474F),
                      child: const Icon(Icons.image,
                          color: Colors.white38, size: 60),
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
                          Colors.black.withValues(alpha: 0.85)
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                  // Overlaid Category Chip, Title, Author & Date Row
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            article.category,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Title
                        Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                            shadows: [
                              Shadow(
                                  color: Colors.black87,
                                  blurRadius: 6,
                                  offset: Offset(0, 1.5))
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Author & date row
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              article.author,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600),
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
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                article.publishDateLabel ?? article.date,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Body content
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    Column(
                      children: [
                        Text(
                          article.excerpt,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.7,
                              color: Color(0xFF2D2D2D)),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadDetail,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Muat ulang konten'),
                        ),
                      ],
                    )
                  else
                    Html(
                      data: article.content.isNotEmpty
                          ? article.content
                          : article.excerpt,
                      style: {
                        'body': Style(
                          fontSize: FontSize(15),
                          lineHeight: LineHeight(1.7),
                          color: const Color(0xFF2D2D2D),
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        'h1': Style(
                          fontSize: FontSize(22),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(top: 12, bottom: 8),
                        ),
                        'h2': Style(
                          fontSize: FontSize(19),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(top: 10, bottom: 6),
                        ),
                        'h3': Style(
                          fontSize: FontSize(17),
                          fontWeight: FontWeight.w600,
                          margin: Margins.only(top: 8, bottom: 6),
                        ),
                        'p': Style(margin: Margins.only(bottom: 12)),
                        'a': Style(
                          color: const Color(0xFF1A56C4),
                          textDecoration: TextDecoration.underline,
                        ),
                        'blockquote': Style(
                          backgroundColor: const Color(0xFFF1F4FA),
                          padding: HtmlPaddings.all(12),
                          margin: Margins.symmetric(vertical: 10),
                          border: const Border(
                            left: BorderSide(
                                color: Color(0xFF1A56C4), width: 3),
                          ),
                        ),
                        'img': Style(width: Width(100, Unit.percent)),
                      },
                      onLinkTap: (url, _, __) {
                        if (url == null) return;
                        final uri = Uri.tryParse(url);
                        if (uri != null) launchUrl(uri);
                      },
                    ),

                  const SizedBox(height: 32),

                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      '#BatuBara',
                      '#BBE',
                      '#${article.category.replaceAll(' / ', '')}',
                      '#Energi'
                    ]
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(tag,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ))
                        .toList(),
                  ),

                  SizedBox(
                    height: AppSafeInsets.bottomNavScrollPadding(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFabMenu,
        backgroundColor: const Color(0xFF1A56C4),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 30),
      ),
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: FabNotchedBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NewsNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                currentIndex: 1,
                onTap: _onTabTapped),
            _NewsNavItem(
                icon: Icons.article,
                label: 'News',
                index: 1,
                currentIndex: 1,
                onTap: _onTabTapped),
            const SizedBox(width: 56),
            _NewsNavItem(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                index: 3,
                currentIndex: 1,
                onTap: _onTabTapped),
            _NewsNavItem(
                icon: Icons.menu,
                label: 'Menu',
                index: 4,
                currentIndex: 1,
                onTap: _onTabTapped),
          ],
        ),
      ),
    );
  }
}

// ── Nav Item Helper ───────────────────────────────────────────────────────────
class _NewsNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _NewsNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return GestureDetector(
      key: ValueKey('nav_$index'),
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB Menu Sheet ────────────────────────────────────────────────────────────
class _NewsDetailFabMenuSheet extends StatelessWidget {
  final String articleTitle;
  final VoidCallback onRefresh;

  const _NewsDetailFabMenuSheet({
    required this.articleTitle,
    required this.onRefresh,
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
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aksi Artikel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          _NewsMenuTile(
            icon: Icons.share_outlined,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1E88E5),
            title: 'Bagikan Berita',
            subtitle: 'Kirim artikel ini ke rekan kerja',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Artikel berhasil dibagikan')),
              );
            },
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _NewsMenuTile(
            icon: Icons.refresh_rounded,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Segarkan Konten',
            subtitle: 'Muat ulang detail berita terbaru',
            onTap: () {
              Navigator.pop(context);
              onRefresh();
            },
          ),
          const SizedBox(height: 16),
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

class _NewsMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NewsMenuTile({
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
