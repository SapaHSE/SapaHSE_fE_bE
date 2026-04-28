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
  String _statusFilter = 'Aktif';

  int _displayedCount = 5;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Loading & error states
  bool _isLoading = true;
  String? _error;

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
    _refreshData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Future.wait([
        ReportStore.instance.refreshReports(),
        _loadCarouselNews(),
      ]);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
      final filteredCount =
          _getFilteredReports(ReportStore.instance.reports.value).length;
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
      bool matchStatus = true;
      if (_statusFilter == 'Aktif') {
        matchStatus = r.status != ReportStatus.closed;
      } else if (_statusFilter == 'Selesai') {
        matchStatus = r.status == ReportStatus.closed;
      }

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
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1A56C4)))
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _refreshData,
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
                                  final filtered =
                                      _getFilteredReports(allReports);
                                  return SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 8, 16, 8),
                                      child: Row(
                                        children: [
                                          const Text('Report List',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          const Spacer(),
                                          Text(
                                            '${filtered.length} laporan',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
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
                                  final filtered =
                                      _getFilteredReports(allReports);
                                  final displayList =
                                      filtered.take(_displayedCount).toList();

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
                                              Text(
                                                  'Tidak ada laporan ditemukan',
                                                  style: TextStyle(
                                                      color: Colors.grey)),
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
                                              builder: (_) =>
                                                  ReportDetailScreen(
                                                      report:
                                                          displayList[index]),
                                            ),
                                          ),
                                        );
                                      },
                                      childCount: displayList.length +
                                          (_isLoadingMore ? 1 : 0),
                                    ),
                                  );
                                },
                              ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 80)),
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
              _error ?? 'Gagal memuat laporan',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Coba Lagi'),
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

          // Dots +  author/date
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Row(
              children: [
                // dots
                Row(
                  children: List.generate(
                      _carouselItems.length,
                      (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: i == _currentPage ? 20 : 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: i == _currentPage
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
                    '${_carouselItems[_currentPage].author}  •  ${_carouselItems[_currentPage].date}',
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
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatusChip('Aktif')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusChip('Selesai')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final isSelected = _statusFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = label;
          _displayedCount = 5;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A56C4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A56C4) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A56C4).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              ValueListenableBuilder<List<Report>>(
                valueListenable: ReportStore.instance.reports,
                builder: (context, reports, _) {
                  final count = _getFilteredReports(reports).length;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color get _severityColor {
    switch (report.severity) {
      case ReportSeverity.low:
        return const Color(0xFF4CAF50);
      case ReportSeverity.medium:
        return const Color(0xFFFF9800);
      case ReportSeverity.high:
        return const Color(0xFFF44336);
      case ReportSeverity.critical:
        return const Color(0xFFB71C1C);
    }
  }

  Color get _statusColor {
    switch (report.status) {
      case ReportStatus.pending:
        return const Color(0xFFFF9800);
      case ReportStatus.open:
        return const Color(0xFF2196F3);
      case ReportStatus.inProgress:
        return const Color(0xFF9C27B0);
      case ReportStatus.closed:
        return const Color(0xFF757575);
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

  Widget? _dueChip() {
    if (report.type != ReportType.hazard) return null;
    if (report.dueDate == null) return null;
    final sisa = report.sisaHari ?? 0;

    Color color;
    IconData icon;
    String label;

    if (sisa < 0) {
      color = const Color(0xFFF44336);
      icon = Icons.warning_amber_rounded;
      label = 'Terlambat ${-sisa} hari';
    } else if (sisa == 0) {
      color = const Color(0xFFF44336);
      icon = Icons.today;
      label = 'Hari ini';
    } else if (sisa <= 3) {
      color = const Color(0xFFFF9800);
      icon = Icons.schedule;
      label = '$sisa hari lagi';
    } else {
      color = const Color(0xFF4CAF50);
      icon = Icons.event_available_outlined;
      label = '$sisa hari lagi';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
              SizedBox(
                height: report.type == ReportType.hazard &&
                        report.dueDate != null
                    ? 130
                    : 135,
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
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_outlined,
                                    color: Colors.grey),
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
                            Expanded(
                              child: Text(
                                report.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Date & Location
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_formatDate(report.createdAt),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 12),
                                const Icon(Icons.location_on_outlined,
                                    size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(report.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey))),
                              ],
                            ),
                            if (_dueChip() != null) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _dueChip()!,
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Status & Priority
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: _statusColor.withValues(
                                            alpha: 0.3)),
                                  ),
                                  child: Text(
                                    report.status.label,
                                    style: TextStyle(
                                        color: _statusColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _severityColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    report.severity.label,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
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
            ],
          ),
        ),
      ),
    );
  }
}
