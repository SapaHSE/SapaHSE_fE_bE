import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../models/report.dart';
import '../data/news_data.dart';
import '../services/news_service.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';
import '../services/inbox_service.dart';
import '../services/storage_service.dart';
import 'report_detail_screen.dart';
import 'news_detail_screen.dart';
import '../data/report_store.dart';
import '../widgets/sapa_hse_header.dart';
import '../widgets/minimal_dropdown.dart';
import '../widgets/app_safe_insets.dart';
import '../app_globals.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  static const String _announcementFallbackAsset = 'assets/logo.png';

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedType = 'All Report';
  String _statusFilter = 'Aktif';

  int _displayedCount = 25;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Loading & error states
  bool _isLoading = true;
  String? _error;
  bool _routeAwareSubscribed = false;
  String? _currentCompanyName;

  // ── Featured News & Announcements Carousel ───────────────────────────────
  List<Object> _carouselItems = [];
  bool _urgentDialogShowing = false;
  final Set<String> _locallyReadAnnouncementIds = <String>{};

  // ── Only Hazard & Inspection ──────────────────────────────────────────────
  final List<String> _reportTypes = [
    'All Report',
    'Hazard',
    'Inspection',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserCompany();
    _refreshData();
    _scrollController.addListener(_onScroll);
    AnnouncementService.refreshNotifier.addListener(_loadCarouselData);
  }

  Future<void> _loadCurrentUserCompany() async {
    final user = await StorageService.getUser();
    if (!mounted) return;
    setState(() {
      _currentCompanyName = user?['company']?.toString();
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Future.wait([
        ReportStore.instance.refreshReports(),
        _loadCarouselData(),
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

  Future<void> _loadCarouselData() async {
    final newsResult = await NewsService.getNews();
    final announcements = await AnnouncementService.getAnnouncements();
    if (!mounted) return;

    final merged = <Object>[];
    if (newsResult.success) {
      merged.addAll(newsResult.articles);
    }
    merged.addAll(announcements);
    merged.sort((a, b) => _carouselDate(b).compareTo(_carouselDate(a)));

    setState(() {
      _currentPage = 0;
      _carouselItems = merged.take(3).toList();
    });

    await _checkUrgentAnnouncement(announcements);

    if (_carouselItems.isNotEmpty) {
      _startCarousel();
    }
  }

  DateTime _carouselDate(Object item) {
    if (item is NewsArticle) {
      return item.createdAt ?? DateTime(2000);
    }
    if (item is Announcement) {
      return item.createdAt;
    }
    return DateTime(2000);
  }

  Future<void> _checkUrgentAnnouncement(
    List<Announcement> announcements,
  ) async {
    if (_urgentDialogShowing) return;

    final urgent = announcements.where((a) => a.isUrgent).toList();
    for (final announcement in urgent) {
      if (_locallyReadAnnouncementIds.contains(announcement.id)) continue;
      if (announcement.isRead) continue;
      final locallyRead =
          await StorageService.isAnnouncementRead(announcement.id);
      if (locallyRead) continue;
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_urgentDialogShowing) {
          _showUrgentPopup(announcement);
        }
      });
      break;
    }
  }

  void _showUrgentPopup(Announcement announcement) {
    if (_urgentDialogShowing) return;
    _urgentDialogShowing = true;
    bool isChecked = false;
    final isAlreadyRead =
        announcement.isRead || _locallyReadAnnouncementIds.contains(announcement.id);
    final remainingDays = announcement.remainingDays;
    final remainingDaysText = remainingDays == null
        ? 'Berlaku: Segera'
        : 'Berlaku: $remainingDays hari lagi';
    final warningDaysText =
        remainingDays == null ? 'beberapa hari' : '$remainingDays hari';
    final creatorName = announcement.creatorName ?? 'Admin';
    final companyName =
        (announcement.creatorCompany?.trim().isNotEmpty ?? false)
            ? announcement.creatorCompany!.trim()
            : ((_currentCompanyName?.trim().isNotEmpty ?? false)
                ? _currentCompanyName!.trim()
                : null);
    final senderText = companyName == null
        ? 'Dari: $creatorName - ${_formatDate(announcement.createdAt)}'
        : 'Dari: $creatorName - $companyName - ${_formatDate(announcement.createdAt)}';
    final descriptionScrollController = ScrollController();
    final screenSize = MediaQuery.of(context).size;
    final popupWidth = (screenSize.width - 16).clamp(0.0, 320.0);
    final popupHeight = (screenSize.height - 24).clamp(0.0, 560.0);
    final headerImageUrl =
        (announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty)
            ? announcement.imageUrl
            : null;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: popupWidth,
                maxHeight: popupHeight,
              ),
              child: SingleChildScrollView(
                child: Container(
                  width: popupWidth,
                  height: popupHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 140,
                        child: GestureDetector(
                          onTap: () => _showAnnouncementImagePreview(headerImageUrl),
                          child: headerImageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: headerImageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFFB71C1C),
                                          Color(0xFFC62828)
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Image.asset(
                                    _announcementFallbackAsset,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  _announcementFallbackAsset,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 12,
                                          color: Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'URGENSI TINGGI',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      remainingDaysText,
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                announcement.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 110),
                                child: Scrollbar(
                                  controller: descriptionScrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: descriptionScrollController,
                                    child: SelectableText.rich(
                                      TextSpan(
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                        children: _buildDescriptionSpans(
                                          announcement.body,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3F3),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFFFCDD2)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Color(0xFFF44336),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Pengumuman ini akan muncul setiap hari selama $warningDaysText hingga kamu mengonfirmasi telah membaca.',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFC62828),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              senderText,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                            const Divider(height: 24),
                            if (!isAlreadyRead) ...[
                              GestureDetector(
                                onTap: () =>
                                    setModalState(() => isChecked = !isChecked),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: isChecked,
                                        activeColor: const Color(0xFF1A56C4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        onChanged: (v) => setModalState(
                                            () => isChecked = v ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Saya sudah membaca dan mengerti isi pengumuman ini',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: isAlreadyRead || isChecked
                                    ? () async {
                                        if (!isAlreadyRead) {
                                          await StorageService
                                              .markAnnouncementRead(
                                            announcement.id,
                                          );
                                          await InboxService.markRead(
                                            itemId: announcement.id,
                                            itemType: 'announcement',
                                          );
                                          if (mounted) {
                                            setState(() {
                                              _locallyReadAnnouncementIds
                                                  .add(announcement.id);
                                            });
                                            _loadCarouselData();
                                          }
                                        }
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A56C4),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade200,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isChecked) const SizedBox(width: 8),
                                    const Text(
                                      'Tutup',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
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
                )
                    .animate()
                    .scale(duration: 400.ms, curve: Curves.easeOutBack)
                    .fadeIn(),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      _urgentDialogShowing = false;
    });
  }

  void _showAnnouncementImagePreview(String? imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => Image.asset(
                          _announcementFallbackAsset,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        _announcementFallbackAsset,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildDescriptionSpans(String text) {
    final regex = RegExp(r'((https?:\/\/|www\.)[^\s]+)', caseSensitive: false);
    final matches = regex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final rawLink = text.substring(match.start, match.end);
      final cleanLink = rawLink.replaceAll(RegExp(r'[),.;!?]+$'), '');
      spans.add(
        TextSpan(
          text: cleanLink,
          style: const TextStyle(
            color: Color(0xFF1565C0),
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _openUrlInBrowser(cleanLink);
            },
        ),
      );

      lastEnd = match.start + cleanLink.length;
      if (match.end > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.end)));
        lastEnd = match.end;
      }
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return spans;
  }

  Future<void> _openUrlInBrowser(String rawUrl) async {
    final normalized = rawUrl.toLowerCase().startsWith('http')
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

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

  String _carouselMetaText(Object item) {
    if (item is NewsArticle) return '${item.author}  •  ${item.date}';
    if (item is Announcement) {
      final time =
          item.timeAgo.isNotEmpty ? item.timeAgo : _formatDate(item.createdAt);
      return '${item.creatorName ?? 'Admin'}  •  $time';
    }
    return '';
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final filteredCount =
          _getFilteredReports(ReportStore.instance.reports.value).length;
      if (!_isLoadingMore && _displayedCount < filteredCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoadingMore = true;
            });
          }
        });
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _displayedCount += 5;
                  _isLoadingMore = false;
                });
              }
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeAwareSubscribed && route is PageRoute) {
      routeObserver.subscribe(this, route);
      _routeAwareSubscribed = true;
    }
  }

  @override
  void didPopNext() {
    // Force a lightweight rebuild after returning from details to keep
    // bottom-FAB visuals consistent on some devices.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_routeAwareSubscribed) {
      routeObserver.unsubscribe(this);
      _routeAwareSubscribed = false;
    }
    AnnouncementService.refreshNotifier.removeListener(_loadCarouselData);
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
        bottom: false,
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
                                            _FadePageRoute(
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
            onPageChanged: (i) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _currentPage = i);
              });
            },
            itemCount: _carouselItems.length,
            itemBuilder: (_, index) {
              final item = _carouselItems[index];
              final String title;
              final String? rawImageUrl;
              if (item is NewsArticle) {
                title = item.title;
                rawImageUrl = item.imageUrl;
              } else {
                final announcement = item as Announcement;
                title = announcement.title;
                rawImageUrl = announcement.imageUrl;
              }
              final imageUrl = rawImageUrl != null && rawImageUrl.isNotEmpty
                  ? rawImageUrl
                  : null;

              return GestureDetector(
                onTap: () {
                  if (item is NewsArticle) {
                    Navigator.push(
                      context,
                      _FadePageRoute(
                        builder: (_) => NewsDetailScreen(article: item),
                      ),
                    );
                  } else if (item is Announcement) {
                    _showUrgentPopup(item);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
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
                      )
                    else
                      Image.asset(
                        _announcementFallbackAsset,
                        fit: BoxFit.cover,
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
                        title,
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

          // Dots + author/date
          Positioned(
            left: 16,
            right: 100, // Make room for the floating badge on the bottom right
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
                    _carouselMetaText(_carouselItems[_currentPage]),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Type badge — rendered last so it floats above everything
          Positioned(
            bottom: 10,
            right: 10,
            child: Builder(builder: (_) {
              final item = _carouselItems[_currentPage];
              final isNews = item is NewsArticle;
              final label = isNews ? 'BERITA' : 'PENGUMUMAN';
              final labelColor = isNews ? Colors.blue : Colors.purple;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
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
          MinimalDropdown<String>(
            value: _selectedType,
            items: _reportTypes
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, style: kMinimalDropdownTextStyle),
                    ))
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
    switch (report.displayStatus) {
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
    if (report.status == ReportStatus.closed) return null;
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
    final dueChip = _dueChip();
    final double cardBodyHeight = dueChip != null ? 156 : 138;

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
                height: cardBodyHeight,
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
                              width: double.infinity,
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
                          mainAxisSize: MainAxisSize.min,
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
                                const Icon(Icons.calendar_today_outlined,
                                    size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(_formatDate(report.createdAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey)),
                                ),
                                const SizedBox(width: 8),
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
                            if (dueChip != null) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: dueChip,
                              ),
                            ],
                            const SizedBox(height: 8),

                            // Status & Priority
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
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
                                      report.displayStatusLabel,
                                      style: TextStyle(
                                          color: _statusColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
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
