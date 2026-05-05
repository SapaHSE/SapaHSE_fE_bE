import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/news_data.dart';
import '../services/news_service.dart';
import 'package:sapahse/main.dart';

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
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)),
      (route) => false,
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
      backgroundColor: Colors.white,
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
                          Colors.black.withOpacity(0.7)
                        ],
                        stops: const [0.4, 1.0],
                      ),
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
                  // Category chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: catColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      article.category,
                      style: TextStyle(
                          color: catColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    article.title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.35),
                  ),
                  const SizedBox(height: 14),

                  // Author & date row
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.person,
                            size: 16, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(width: 8),
                      Text(article.author,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(article.date,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),

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
                    Text(
                      article.content.isNotEmpty
                          ? article.content
                          : article.excerpt,
                      style: const TextStyle(
                          fontSize: 15, height: 1.7, color: Color(0xFF2D2D2D)),
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
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(tag,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 80),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NewsNavItem(icon: Icons.home, label: 'Home', index: 0, currentIndex: 1, onTap: _onTabTapped),
              _NewsNavItem(icon: Icons.article, label: 'News', index: 1, currentIndex: 1, onTap: _onTabTapped),
              const SizedBox(width: 48),
              _NewsNavItem(icon: Icons.inbox_outlined, label: 'Inbox', index: 3, currentIndex: 1, onTap: _onTabTapped),
              _NewsNavItem(icon: Icons.menu, label: 'Menu', index: 4, currentIndex: 1, onTap: _onTabTapped),
            ],
          ),
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
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? const Color(0xFF1A56C4) : Colors.grey, size: 24),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
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
