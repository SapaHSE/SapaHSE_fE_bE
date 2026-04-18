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

  // ── Loading / error state ─────────────────────────────────────────────────
  bool _isLoadingReports = false;
  String? _reportsError;
  bool _isLoadingNews = false;
  String? _newsError;

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
    _loadReports();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadCarouselNews() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNews = true;
      _newsError = null;
    });
    try {
      final result = await NewsService.getNews();
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _carouselItems = result.articles.where((a) => a.isFeatured).toList();
        });
        _startCarousel();
      } else {
        setState(() {
          _newsError = result.errorMessage ?? 'Gagal memuat berita.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _newsError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _isLoadingReports = true;
      _reportsError = null;
    });
    try {
      await ReportStore.instance.refreshReports();
    } catch (e) {
      if (mounted) setState(() => _reportsError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadReports(), _loadCarouselNews()]);
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
              child: RefreshIndicator(
                color: const Color(0xFF1A56C4),
                onRefresh: _refreshAll,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
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
                        if (_isLoadingReports) {
                          return const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF1A56C4)),
                              ),
                            ),
                          );
                        }
                        if (_reportsError != null) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cloud_off,
                                        size: 48, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Gagal memuat laporan',
                                      style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _reportsError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _loadReports,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Coba Lagi'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF1A56C4),
                                        side: const BorderSide(
                                            color: Color(0xFF1A56C4)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
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
            ),
          ],
        ),
      ),
    );
  }

  // ── CAROUSEL ──────────────────────────────────────────────────────────────
  Widget _buildCarousel() {
    if (_carouselItems.isEmpty) {
      if (_isLoadingNews) {
        return Container(
          height: 240,
          color: const Color(0xFF263238),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white38),
          ),
        );
      }
      if (_newsError != null) {
        return Container(
          height: 240,
          color: const Color(0xFF263238),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: Colors.white54, size: 40),
                const SizedBox(height: 8),
                const Text(
                  'Gagal memuat berita',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loadCarouselNews,
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                  label: const Text('Coba Lagi',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Container(
        height: 240,
        color: const Color(0xFF263238),
        child: const Center(
          child: Text(
            'Belum ada berita unggulan',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
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

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color get _severityColor {
    switch (report.severity) {
      case ReportSeverity.low:      return const Color(0xFF4CAF50);
      case ReportSeverity.medium:   return const Color(0xFFFF9800);
      case ReportSeverity.high:     return const Color(0xFFF44336);
      case ReportSeverity.critical: return const Color(0xFFB71C1C);
    }
  }

  Color get _statusColor {
    switch (report.status) {
      case ReportStatus.open:       return const Color(0xFF2196F3);
      case ReportStatus.inProgress: return const Color(0xFF9C27B0);
      case ReportStatus.closed:     return const Color(0xFF757575);
    }
  }

  Color get _typeColor {
    switch (report.type) {
      case ReportType.hazard:       return const Color(0xFFF44336);
      case ReportType.inspection:   return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── LEFT SIDE: Image + Category ──────────────────────────
                    Container(
                      width: 110,
                      color: Colors.grey.shade50,
                      child: Column(
                        children: [
                          Expanded(
                            child: CachedNetworkImage(
                              imageUrl: report.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_outlined, color: Colors.grey),
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            color: _typeColor,
                            child: Text(
                              report.type.label.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── RIGHT SIDE: Details ──────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Date & Location
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_formatDate(report.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 12),
                                const Icon(Icons.location_on_outlined, size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(child: Text(report.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey))),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Status & Priority
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    report.status.label,
                                    style: TextStyle(color: _statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _severityColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    report.severity.label,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── BOTTOM: Status Banner (Always present for uniform size) ───────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: report.status == ReportStatus.open
                      ? const Color(0xFFFFF4E5)
                      : report.status == ReportStatus.inProgress
                          ? const Color(0xFFF3E5F5)
                          : const Color(0xFFE8F5E9),
                  border: Border(
                    top: BorderSide(
                      color: report.status == ReportStatus.open
                          ? Colors.orange.shade100
                          : report.status == ReportStatus.inProgress
                              ? Colors.purple.shade100
                              : Colors.green.shade100,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      report.status == ReportStatus.open
                          ? Icons.warning_amber_rounded
                          : report.status == ReportStatus.inProgress
                              ? Icons.pending_actions_rounded
                              : Icons.check_circle_outline_rounded,
                      size: 14,
                      color: report.status == ReportStatus.open
                          ? Colors.orange.shade900
                          : report.status == ReportStatus.inProgress
                              ? Colors.purple.shade900
                              : Colors.green.shade900,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.status == ReportStatus.open
                          ? 'BUTUH TINDAKAN SEGERA'
                          : report.status == ReportStatus.inProgress
                              ? 'LAPORAN SEDANG DIPROSES'
                              : 'LAPORAN TELAH SELESAI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: report.status == ReportStatus.open
                            ? Colors.orange.shade900
                            : report.status == ReportStatus.inProgress
                                ? Colors.purple.shade900
                                : Colors.green.shade900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}