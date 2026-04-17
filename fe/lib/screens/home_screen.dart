import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/report.dart';
import '../data/news_data.dart';
import '../services/news_service.dart';
import 'report_detail_screen.dart';
import 'news_detail_screen.dart';
import '../data/report_store.dart';
import '../widgets/sapa_hse_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedType = 'All Report';
  bool _showOpenInProgress = false;

  int _displayedCount = 5;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // ── Featured News Carousel ────────────────────────────────────────────────
  List<NewsArticle> _carouselItems = [];

  // ── Only Hazard & Inspection ──────────────────────────────────────────────
  final List<String> _reportTypes = [
    'All Report',
    'Hazard',
    'Inspection',
  ];

  @override
  void initState() {
    super.initState();
    _loadCarouselNews();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadCarouselNews() async {
    final result = await NewsService.getNews();
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _carouselItems = result.articles.where((a) => a.isFeatured).toList();
      });
      _startCarousel();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final filteredCount = _getFilteredReports(ReportStore.instance.reports.value).length;
      if (!_isLoadingMore && _displayedCount < filteredCount) {
        setState(() {
          _isLoadingMore = true;
        });
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _displayedCount += 5;
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    if (_carouselItems.isEmpty) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (!_pageController.hasClients) return;
      if (_carouselItems.isEmpty) return;
      final next = (_currentPage + 1) % _carouselItems.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Report> _getFilteredReports(List<Report> allReports) {
    return allReports.where((r) {
      final matchType =
          _selectedType == 'All Report' || r.type.label == _selectedType;
      final matchStatus =
          !_showOpenInProgress || r.status == ReportStatus.closed;
      final matchSearch = _searchQuery.isEmpty ||
          r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchType && matchStatus && matchSearch;
    }).toList();
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
              searchHint: 'Cari laporan...',
              onSearchChanged: (v) => setState(() {
                _searchQuery = v;
                _displayedCount = 5;
              }),
              onSearchToggle: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                    _displayedCount = 5;
                  }
                });
              },
            ),

            // ── Scrollable Body ─────────────────────────────────────────────
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // ── Carousel ───────────────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildCarousel()),

                  // ── Filters ────────────────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildFilters()),

                  // ── Report list section with state sync ─────────────────────────────
                  ValueListenableBuilder<List<Report>>(
                    valueListenable: ReportStore.instance.reports,
                    builder: (context, allReports, _) {
                      final filtered = _getFilteredReports(allReports);
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              const Text('Report List',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const Spacer(),
                              Text(
                                '${filtered.length} laporan',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  ValueListenableBuilder<List<Report>>(
                    valueListenable: ReportStore.instance.reports,
                    builder: (context, allReports, _) {
                      final filtered = _getFilteredReports(allReports);
                      final displayList = filtered.take(_displayedCount).toList();

                      if (filtered.isEmpty) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Tidak ada laporan ditemukan',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == displayList.length) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF1A56C4)),
                                ),
                              );
                            }
                            return _ReportCard(
                              report: displayList[index],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportDetailScreen(
                                      report: displayList[index]),
                                ),
                              ),
                            );
                          },
                          childCount: displayList.length + (_isLoadingMore ? 1 : 0),
                        ),
                      );
                    },
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

  // ── CAROUSEL ──────────────────────────────────────────────────────────────
  Widget _buildCarousel() {
    if (_carouselItems.isEmpty) {
      return Container(
        height: 240,
        color: const Color(0xFF263238),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _carouselItems.length,
            itemBuilder: (_, index) {
              final item = _carouselItems[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewsDetailScreen(article: item),
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.imageUrl,
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
                            color: Colors.white24, size: 60),
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
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Left arrow
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final prev = _currentPage > 0
                      ? _currentPage - 1
                      : _carouselItems.length - 1;
                  _pageController.animateToPage(prev,
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
                  final next = (_currentPage + 1) % _carouselItems.length;
                  _pageController.animateToPage(next,
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

          // Dots + Indicator (News Style)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Row(
              children: [
                Row(
                  children: List.generate(
                    _carouselItems.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _currentPage ? 20 : 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? const Color(0xFF1A56C4)
                            : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTERS ───────────────────────────────────────────────────────────────
  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPORT TYPE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                items: _reportTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedType = val;
                      _displayedCount = 5;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () =>
                setState(() {
                  _showOpenInProgress = !_showOpenInProgress;
                  _displayedCount = 5;
                }),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _showOpenInProgress
                        ? const Color(0xFF1A56C4)
                        : Colors.transparent,
                    border: Border.all(
                      color: _showOpenInProgress
                          ? const Color(0xFF1A56C4)
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: _showOpenInProgress
                      ? const Icon(Icons.check, color: Colors.white, size: 13)
                      : null,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Show Completed Only',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                if (_showOpenInProgress) ...[
                  const SizedBox(width: 8),
                    ValueListenableBuilder<List<Report>>(
                      valueListenable: ReportStore.instance.reports,
                      builder: (context, reports, _) {
                        final count = _getFilteredReports(reports).length;
                        return Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56C4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1A56C4),
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── REPORT CARD ───────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  Color get _severityColor {
    switch (report.severity) {
      case ReportSeverity.low:
        return const Color(0xFF4CAF50);
      case ReportSeverity.medium:
        return const Color(0xFFFF9800);
      case ReportSeverity.high:
        return const Color(0xFFF44336);
    }
  }

  Color get _statusColor {
    switch (report.status) {
      case ReportStatus.open:
        return const Color(0xFF2196F3); // Biru
      case ReportStatus.inProgress:
        return const Color(0xFF9C27B0); // Ungu
      case ReportStatus.closed:
        return const Color(0xFF757575); // Abu
    }
  }

  Color get _typeColor {
    switch (report.type) {
      case ReportType.hazard:
        return const Color(0xFFF44336);
      case ReportType.inspection:
        return const Color(0xFF1565C0);
    }
  }

  IconData get _typeIcon {
    switch (report.type) {
      case ReportType.hazard:
        return Icons.warning_amber_rounded;
      case ReportType.inspection:
        return Icons.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Thumbnail Image ───────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: SizedBox(
                  width: 100,
                  height: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: report.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF546E7A),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white38, strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF546E7A),
                      child: const Icon(Icons.image,
                          color: Colors.white38, size: 32),
                    ),
                  ),
                ),
              ),

            // ── Content ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type badge + Severity badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_typeIcon, size: 11, color: _typeColor),
                              const SizedBox(width: 3),
                              Text(
                                report.type.label,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _typeColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _severityColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            report.severity.label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      report.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 8),

                    // Status badge
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          report.status.label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _statusColor),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            color: Colors.grey.shade400, size: 16),
                      ],
                    ),
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
