import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/report.dart';
import '../data/report_store.dart';
import '../services/report_service.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/supabase_storage_service.dart';
import '../config/supabase_config.dart';
import '../main.dart';

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

/// A curve that wraps another curve and clamps the input t to [0.0, 1.0].
/// This prevents assertions when the parent animation's value goes slightly out of bounds.
class _ClampedCurve extends Curve {
  final Curve curve;
  const _ClampedCurve(this.curve);
  @override
  double transform(double t) => curve.transform(t.clamp(0.0, 1.0));
}



class ReportDetailScreen extends StatefulWidget {
  final Report report;
  final bool isDialog;
  const ReportDetailScreen(
      {super.key, required this.report, this.isDialog = false});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen>
    with SingleTickerProviderStateMixin {
  late Report _report;
  late Future<List<TimelineEvent>> _timelineFuture;
  bool _didBackgroundTimelineRefresh = false;
  bool _isLoading = false;
  UserModel? _currentUser;
  bool _showScrollToBottom = false;
  bool _isScrolledToBottom = false;
  bool _showTimeline = false;

  final ScrollController _scrollController = ScrollController();
  late final AnimationController _updateStatusFabController;

  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);

  @override
  void initState() {
    super.initState();
    _report = ReportStore.instance.getById(widget.report.id) ?? widget.report;
    _timelineFuture = ReportStore.instance.loadTimeline(_report.id);
    // Rebuild after timeline first loads so carousel can include log images.
    _timelineFuture.whenComplete(() {
      if (mounted) setState(() {});
    });
    _refreshTimelineInBackground();
    _prefetchAllTimelineReplies();
    _loadUserAndRefresh();
    _updateStatusFabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canUpdate) {
        _updateStatusFabController.forward();
      }
    });
  }

  /// Evaluates scroll metrics and shows/hides the FAB accordingly.
  /// Called by NotificationListener on every scroll AND content-size change.
  void _updateScrollVisibility(ScrollMetrics metrics) {
    final maxScroll = metrics.maxScrollExtent;
    final currentScroll = metrics.pixels;
    final remaining = maxScroll - currentScroll;
    // Show whenever the page is meaningfully scrollable. The button toggles
    // its action (down ↔ up) based on whether the user is at the bottom.
    final shouldShow = maxScroll > 300;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
    // Track if scrolled to (or very near) the bottom.
    final atBottom = remaining < 50;
    if (atBottom != _isScrolledToBottom) {
      setState(() => _isScrolledToBottom = atBottom);
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _onTabTapped(int index) {
    Navigator.pushReplacement(
      context,
      _FadePageRoute(builder: (_) => MainScreen(initialIndex: index)),
    );
  }

  Future<void> _loadUserAndRefresh() async {
    final userData = await StorageService.getUser();
    if (userData != null && mounted) {
      setState(() => _currentUser = UserModel.fromJson(userData));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_canUpdate) return;
        _updateStatusFabController
          ..reset()
          ..forward();
      });
    }
    _refreshData();
  }

  // Superadmin = platform-level, full bypass.
  // Admin = role-level update authority ONLY if also tagged (dept or name).
  // This mirrors the backend authorization in HazardReportController/InspectionReportController.
  bool get _isSuperadmin => _currentUser?.isSuperadmin ?? false;
  bool get _isAdmin => (_currentUser?.isAdmin ?? false) && _isTaggedUser;
  bool get _isTaggedUser {
    if (_currentUser == null) return false;
    final fullName = _currentUser!.fullName.toLowerCase();
    final dept = (_currentUser!.department ?? '').toLowerCase();

    // Hazard: match nama di picDepartment
    final pic = _report.picDepartment?.toLowerCase() ?? '';
    final isTaggedByName = pic.contains(fullName);

    // Inspection & Hazard: match dept di reported_department (departemen tagigan)
    final repDept = _report.departemen?.toLowerCase() ?? '';
    final isTaggedByDept = dept.isNotEmpty && repDept.contains(dept);

    return isTaggedByName || isTaggedByDept;
  }

  bool get _isApprovedOrLater {
    final sub = _report.subStatus;
    if (sub == null) {
      return _report.status == ReportStatus.inProgress ||
          _report.status == ReportStatus.closed;
    }
    return sub != ReportSubStatus.validating;
  }

  bool get _canUpdate =>
      _isSuperadmin || _isAdmin || (_isTaggedUser && _isApprovedOrLater);
  // FAB selalu tampil di detail laporan; saat user tidak berwenang, ia greyed-out
  // dan tidak bisa dipencet (lihat _canTapUpdateFab).
  bool get _canTapUpdateFab =>
      _canUpdate && (_report.status != ReportStatus.closed || _isSuperadmin);

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final updated =
          await ReportStore.instance.fetchReport(_report.id, _report.type);
      if (mounted) {
        setState(() {
          _report = updated;
          _timelineFuture =
              ReportStore.instance.loadTimeline(_report.id, force: true);
        });
        _prefetchAllTimelineReplies();
      }
    } catch (e) {
      debugPrint('Error refreshing report: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _prefetchAllTimelineReplies() async {
    try {
      final timeline = await _timelineFuture;
      if (!_canViewRepliesInThread(timeline)) return;
      final logIds = timeline
          .map((e) => e.timelineLogId)
          .where((id) =>
              id.isNotEmpty &&
              !id.startsWith('implicit-') &&
              !id.startsWith('fallback-'))
          .toSet()
          .toList();
      await Future.wait(
        logIds.map((id) => ReportStore.instance.loadReplies(_report.id, id)),
      );
      if (mounted) setState(() {});
    } catch (_) {
      // keep timeline usable even if reply prefetch fails
    }
  }

  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _updateStatusFabController.dispose();
    super.dispose();
  }

  // ── Colors ─────────────────────────────────────────────────────────────────
  Color _severityColor(ReportSeverity s) => switch (s) {
        ReportSeverity.low => const Color(0xFF4CAF50),
        ReportSeverity.medium => const Color(0xFFFF9800),
        ReportSeverity.high => const Color(0xFFF44336),
        ReportSeverity.critical => const Color(0xFF880E4F),
      };

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.open => const Color(0xFF2196F3),
        ReportStatus.inProgress => const Color(0xFF9C27B0),
        ReportStatus.closed => const Color(0xFF757575),
      };

  IconData _statusIcon(ReportStatus s) => switch (s) {
        ReportStatus.open => Icons.flag_outlined,
        ReportStatus.inProgress => Icons.autorenew,
        ReportStatus.closed => Icons.check_circle_outline,
      };

  String _categoryDisplayValue(Report report) {
    if (report.type == ReportType.hazard) {
      if (report.hazardCategoryNames.isNotEmpty) {
        return report.hazardCategoryNames.join(', ');
      }
      if (report.hazardCategoryCodes.isNotEmpty) {
        return report.hazardCategoryCodes.join(', ');
      }
    }
    return report.category?.label ?? report.type.label;
  }

  String _formatDate(DateTime dt) {
    final m = [
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
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime dt) {
    final m = [
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
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _formatDueLabel(DateTime due) {
    final dateStr = _formatDateShort(due);
    final diff = due.difference(DateTime.now());
    final abs = diff.abs();

    String span;
    if (abs < const Duration(days: 1)) {
      final hours = abs.inHours;
      final minutes = abs.inMinutes.remainder(60);
      span = '$hours jam $minutes menit';
    } else {
      final days = abs.inDays;
      final hours = abs.inHours.remainder(24);
      span = '$days hari $hours jam';
    }

    if (diff.isNegative) return '$dateStr — Terlambat $span';
    return '$dateStr — $span lagi';
  }

  Future<void> _showImagePreview(
      BuildContext context, List<String> images, int initialIndex) async {
    await precacheImage(
      CachedNetworkImageProvider(images[initialIndex]),
      context,
    );
    if (!context.mounted) return;
    final previewController = PageController(initialPage: initialIndex);
    final Map<int, TransformationController> controllers = {};
    final Map<int, VoidCallback> listeners = {};
    var doubleTapPosition = Offset.zero;
    const doubleTapZoomScale = 2.5;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          var currentIndex = initialIndex;
          var isZoomed = false;
          return StatefulBuilder(
            builder: (context, setPreviewState) {
              TransformationController controllerFor(int i) {
                final existing = controllers[i];
                if (existing != null) return existing;
                final c = TransformationController();
                void listener() {
                  final scale = c.value.getMaxScaleOnAxis();
                  final zoomed = scale > 1.0;
                  if (zoomed != isZoomed) {
                    setPreviewState(() => isZoomed = zoomed);
                  }
                }

                c.addListener(listener);
                controllers[i] = c;
                listeners[i] = listener;
                return c;
              }

              void handleDoubleTap(int i) {
                final c = controllerFor(i);
                final currentScale = c.value.getMaxScaleOnAxis();
                if (currentScale > 1.0) {
                  c.value = Matrix4.identity();
                } else {
                  const s = doubleTapZoomScale;
                  final x = -doubleTapPosition.dx * (s - 1);
                  final y = -doubleTapPosition.dy * (s - 1);
                  // Column-major: scale on diagonal, translation in last column.
                  c.value = Matrix4(
                    s,
                    0,
                    0,
                    0,
                    0,
                    s,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                    x,
                    y,
                    0,
                    1,
                  );
                }
              }

              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  iconTheme: const IconThemeData(color: Colors.white),
                  elevation: 0,
                  title: Text(
                    '${currentIndex + 1}/${images.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
                extendBodyBehindAppBar: true,
                body: PageView.builder(
                  controller: previewController,
                  physics: isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (idx) {
                    final old = currentIndex;
                    setPreviewState(() {
                      currentIndex = idx;
                      isZoomed = false;
                    });
                    controllers[old]?.value = Matrix4.identity();
                  },
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final image = CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          const CircularProgressIndicator(color: Colors.white),
                      errorWidget: (_, __, ___) => const Icon(Icons.image,
                          color: Colors.white54, size: 80),
                    );
                    return Center(
                      child: GestureDetector(
                        onDoubleTapDown: (details) =>
                            doubleTapPosition = details.localPosition,
                        onDoubleTap: () => handleDoubleTap(index),
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          transformationController: controllerFor(index),
                          child: image,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    ).then((_) {
      for (final entry in controllers.entries) {
        final l = listeners[entry.key];
        if (l != null) entry.value.removeListener(l);
        entry.value.dispose();
      }
      previewController.dispose();
    });
  }

  void _showUpdateStatusModal() {
    if (!_canTapUpdateFab) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UpdateStatusSheet(
        report: _report,
        isAdmin: _isAdmin || _isSuperadmin,
        isSuperadmin: _isSuperadmin,
        onUpdate: (updatedReport) {
          setState(() {
            _report = updatedReport;
            _timelineFuture =
                ReportStore.instance.loadTimeline(_report.id, force: true);
          });
          _refreshData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timelineEvents = ReportStore.instance.getTimeline(_report.id);
    final replyImages = <String>[];
    for (final event in timelineEvents) {
      if (event.timelineLogId.startsWith('implicit-') ||
          event.timelineLogId.startsWith('fallback-')) {
        continue;
      }
      final replies = ReportStore.instance.getReplies(event.timelineLogId);
      for (final reply in replies) {
        replyImages.addAll(reply.attachmentUrls);
      }
    }
    final List<String> images = <String>{
      ..._report.imageUrls,
      ...timelineEvents
          .where((e) => e.photoPaths.isNotEmpty)
          .expand((e) => e.photoPaths),
      ...replyImages,
    }.toList();
    if (images.isEmpty) {
      images.add('https://placehold.co/600x400?text=No+Image');
    }
    final int safeIndex =
        images.isEmpty ? 0 : _currentImageIndex.clamp(0, images.length - 1);
    final bool isDueRed =
        _report.type == ReportType.hazard && ((_report.sisaHari ?? 0) <= 0);

    return Scaffold(
      backgroundColor: widget.isDialog ? Colors.white : const Color(0xFFF0F0F0),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButtonLocation: widget.isDialog
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'report_detail_fab',
        onPressed: _canTapUpdateFab ? _showUpdateStatusModal : null,
        backgroundColor:
            _canTapUpdateFab ? const Color(0xFF1A56C4) : Colors.grey.shade400,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: _canTapUpdateFab ? 4 : 0,
        tooltip: _canTapUpdateFab
            ? 'Update status laporan'
            : 'Anda tidak berwenang mengubah status laporan ini',
        child: const Icon(Icons.edit_outlined, size: 26),
      ),
      bottomNavigationBar: widget.isDialog
          ? null
          : BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              color: Colors.white,
              elevation: 8,
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ReportDetailNavItem(
                        icon: Icons.home,
                        label: 'Home',
                        index: 0,
                        currentIndex: -1,
                        onTap: _onTabTapped),
                    _ReportDetailNavItem(
                        icon: Icons.article_outlined,
                        label: 'News',
                        index: 1,
                        currentIndex: -1,
                        onTap: _onTabTapped),
                    const SizedBox(width: 48),
                    _ReportDetailNavItem(
                        icon: Icons.inbox_outlined,
                        label: 'Inbox',
                        index: 3,
                        currentIndex: -1,
                        onTap: _onTabTapped),
                    _ReportDetailNavItem(
                        icon: Icons.menu,
                        label: 'Menu',
                        index: 4,
                        currentIndex: -1,
                        onTap: _onTabTapped),
                  ],
                ),
              ),
            ),
      appBar: widget.isDialog
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Detail Laporan',
                  style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              centerTitle: true,
              actions: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _blue),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black87),
                  onPressed: _refreshData,
                ),
              ],
            ),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _updateScrollVisibility(notification.metrics);
              return false; // don't consume the notification
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero image ─────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Stack(fit: StackFit.expand, children: [
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: (idx) =>
                            setState(() => _currentImageIndex = idx),
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final imgUrl = images[index];
                          return GestureDetector(
                            onTap: () async =>
                                _showImagePreview(context, images, index),
                            child: CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFF37474F),
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white38, strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF37474F),
                                child: const Icon(Icons.image,
                                    color: Colors.white24, size: 80),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.65),
                                Colors.transparent
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        child: Row(children: [
                          _badge(_report.displayStatusLabel,
                              _statusColor(_report.displayStatus)),
                          const SizedBox(width: 8),
                          _badge(_report.severity.label,
                              _severityColor(_report.severity)),
                        ]),
                      ),
                      if (images.length > 1) ...[
                        Positioned(
                          bottom: 12,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('${safeIndex + 1}/${images.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: CircleAvatar(
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.3),
                              radius: 18,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.arrow_back_ios_new,
                                    color: Colors.white, size: 18),
                                onPressed: () {
                                  if (safeIndex > 0) {
                                    _pageController.previousPage(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: CircleAvatar(
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.3),
                              radius: 18,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.arrow_forward_ios,
                                    color: Colors.white, size: 18),
                                onPressed: () {
                                  if (safeIndex < images.length - 1) {
                                    _pageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),

                  // ── Info card ──────────────────────────────────────────────────
                  _card(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_report.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_report.type.label,
                            style: const TextStyle(
                                fontSize: 13,
                                color: _blue,
                                fontWeight: FontWeight.w500)),
                        const Divider(height: 24),
                        _DetailRow(
                            icon: Icons.description_outlined,
                            label: 'Deskripsi',
                            value: _report.description),
                        if (_report.saran != null &&
                            _report.saran!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                              icon: Icons.lightbulb_outline,
                              label: 'Saran',
                              value: _report.saran!),
                        ],
                        const SizedBox(height: 12),
                        _DetailRow(
                            icon: Icons.category_outlined,
                            label: 'Kategori',
                            value: _categoryDisplayValue(_report)),
                        if (_report.subkategori != null &&
                            _report.subkategori!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                              icon: Icons.subdirectory_arrow_right,
                              label: 'Sub-kategori',
                              value: _report.subkategori!),
                        ],
                        if (_report.company != null &&
                            _report.company!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                              icon: Icons.business_outlined,
                              label: 'Perusahaan',
                              value: _report.company!),
                        ],
                        if (_report.pelaporLocation != null &&
                            _report.pelaporLocation!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.my_location_outlined,
                            label: 'Koordinat Pelapor',
                            value: _report.pelaporLocation!,
                            onTap: () async {
                              final coords =
                                  _report.pelaporLocation!.split(',');
                              if (coords.length != 2) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Format koordinat tidak valid')),
                                  );
                                }
                                return;
                              }
                              final lat = double.tryParse(coords[0].trim());
                              final lng = double.tryParse(coords[1].trim());
                              if (lat == null || lng == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Format koordinat tidak valid')),
                                  );
                                }
                                return;
                              }
                              final googleMapsUrl = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                              final appleMapsUrl =
                                  Uri.parse('apple:0,0?q=$lat,$lng');
                              if (await canLaunchUrl(googleMapsUrl)) {
                                await launchUrl(googleMapsUrl,
                                    mode: LaunchMode.externalApplication);
                              } else if (!kIsWeb &&
                                  Platform.isIOS &&
                                  await canLaunchUrl(appleMapsUrl)) {
                                await launchUrl(appleMapsUrl);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Tidak dapat membuka aplikasi peta')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                        if (_report.ticketNumber != null &&
                            _report.ticketNumber!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                              icon: Icons.confirmation_number_outlined,
                              label: 'No. Tiket',
                              value: _report.ticketNumber!),
                        ],
                      ],
                    ),
                  ),

                  // ── Card: Informasi Pelapor ────────────────────────────────────
                  _card(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                            icon: Icons.person_outline,
                            title: 'Informasi Pelapor'),
                        const SizedBox(height: 12),
                        _DetailRow(
                            icon: Icons.person_outline,
                            label: 'Pelapor',
                            value: _report.reportedBy),
                        const SizedBox(height: 12),
                        _DetailRow(
                            icon: Icons.access_time,
                            label: 'Waktu Laporan',
                            value: _formatDate(_report.createdAt)),
                        if (_report.dueDate != null) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                              icon: Icons.alarm_outlined,
                              label: 'Tenggat Waktu',
                              value: _formatDueLabel(_report.dueDate!),
                              valueColor:
                                  isDueRed ? const Color(0xFFF44336) : null),
                        ],
                        if (_report.pelakuPelanggaran != null &&
                            _report.pelakuPelanggaran!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                              icon: Icons.warning_amber_outlined,
                              label: 'Tersangka Pelanggaran',
                              value: _report.pelakuPelanggaran!),
                        ],
                      ],
                    ),
                  ),

                  // ── Card: Penugasan ────────────────────────────────────────────
                  _card(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                            icon: Icons.assignment_ind_outlined,
                            title: 'Informasi Penugasan'),
                        const SizedBox(height: 12),
                        if (_report.departemen != null &&
                            _report.departemen!.isNotEmpty) ...[
                          _DetailRow(
                              icon: Icons.manage_accounts_outlined,
                              label: 'Petugas Utama (PIC)',
                              value: _report.departemen!),
                        ],
                        if (_report.picDepartment != null &&
                            _report.picDepartment!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                              icon: Icons.group_outlined,
                              label: 'Petugas Lainnya',
                              value: _report.picDepartment!),
                        ],
                        if (_report.subStatus == ReportSubStatus.deferred) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                              icon: Icons.schedule_outlined,
                              label: 'Penugasan Lanjutan',
                              value: _report.subStatus!.label),
                        ],
                        const SizedBox(height: 12),
                        _DetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'Lokasi Penugasan',
                            value: _report.location),
                        if (_report.kejadianLocation != null &&
                            _report.kejadianLocation!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.my_location_outlined,
                            label: 'Koordinat Penugasan',
                            value: _report.kejadianLocation!,
                            onTap: () async {
                              final coords =
                                  _report.kejadianLocation!.split(',');
                              if (coords.length != 2) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Format koordinat tidak valid')),
                                  );
                                }
                                return;
                              }
                              final lat = double.tryParse(coords[0].trim());
                              final lng = double.tryParse(coords[1].trim());
                              if (lat == null || lng == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Format koordinat tidak valid')),
                                  );
                                }
                                return;
                              }
                              final googleMapsUrl = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                              final appleMapsUrl =
                                  Uri.parse('apple:0,0?q=$lat,$lng');
                              if (await canLaunchUrl(googleMapsUrl)) {
                                await launchUrl(googleMapsUrl,
                                    mode: LaunchMode.externalApplication);
                              } else if (!kIsWeb &&
                                  Platform.isIOS &&
                                  await canLaunchUrl(appleMapsUrl)) {
                                await launchUrl(appleMapsUrl);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Tidak dapat membuka aplikasi peta')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Card: Informasi Inspeksi ───────────────────────────────────
                  if (_report.type == ReportType.inspection)
                    _card(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                              icon: Icons.assignment_outlined,
                              title: 'Informasi Inspeksi'),
                          const SizedBox(height: 12),
                          if (_report.nameInspector != null &&
                              _report.nameInspector!.isNotEmpty) ...[
                            _DetailRow(
                                icon: Icons.person_search_outlined,
                                label: 'Inspektur',
                                value: _report.nameInspector!),
                            const SizedBox(height: 12),
                          ],
                          if (_report.area != null &&
                              _report.area!.isNotEmpty) ...[
                            _DetailRow(
                                icon: Icons.area_chart_outlined,
                                label: 'Area Inspeksi',
                                value: _report.area!),
                            const SizedBox(height: 12),
                          ],
                          if (_report.notes != null &&
                              _report.notes!.isNotEmpty) ...[
                            _DetailRow(
                                icon: Icons.note_outlined,
                                label: 'Catatan Inspeksi',
                                value: _report.notes!),
                          ],
                        ],
                      ),
                    ),

                  // ── Card: Checklist Inspeksi ───────────────────────────────────
                  if (_report.type == ReportType.inspection &&
                      _report.checklistItems != null &&
                      _report.checklistItems!.isNotEmpty)
                    _card(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                              icon: Icons.checklist_outlined,
                              title: 'Checklist Inspeksi'),
                          const SizedBox(height: 12),
                          ..._report.checklistItems!.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.isChecked
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      color: item.isChecked
                                          ? Colors.green
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: item.isChecked
                                              ? Colors.black87
                                              : Colors.black54,
                                          decoration: item.isChecked
                                              ? null
                                              : TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),

                  // ── Progress Timeline ──────────────────────────────────────────
                  FutureBuilder<List<TimelineEvent>>(
                    future: _timelineFuture,
                    builder: (context, snapshot) {
                      final timeline = snapshot.data ??
                          ReportStore.instance.getTimeline(_report.id);

                      return _card(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.timeline,
                                  color: _blue, size: 20),
                              const SizedBox(width: 8),
                              const Text('Progress Laporan',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                    color: _blueLight,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('${timeline.length} aktivitas',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _blue,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            _buildStepBar(timeline),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _showTimeline = !_showTimeline),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _blueLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: _blue.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _showTimeline
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: _blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _showTimeline
                                          ? 'Sembunyikan Detail'
                                          : 'Lihat Detail Aktivitas',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showTimeline) ...[
                              const SizedBox(height: 16),
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  timeline.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (timeline.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Text('Belum ada aktivitas.',
                                        style: TextStyle(color: Colors.grey)),
                                  ),
                                )
                              else
                                ..._buildGroupedTimeline(timeline),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 112),
                ],
              ),
            ),
          ),
          // Scroll-to-bottom / scroll-to-top FAB. Lives in the body Stack so
          // we can position it independently of the centered/notched main FAB.
          Positioned(
            right: 16,
            bottom: 84.0,
            child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: const _ClampedCurve(Curves.easeOutBack),
                switchOutCurve: const _ClampedCurve(Curves.easeInCubic),
                transitionBuilder: (child, animation) {
                  final clampedAnim = CurvedAnimation(
                    parent: animation,
                    curve: const _ClampedCurve(Curves.linear),
                  );
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.22),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: const _ClampedCurve(Curves.easeOutCubic),
                  ));
                  final scale = Tween<double>(begin: 0.9, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const _ClampedCurve(Curves.easeOutBack),
                    ),
                  );
                  return FadeTransition(
                    opacity: clampedAnim,
                    child: SlideTransition(
                      position: slide,
                      child: ScaleTransition(scale: scale, child: child),
                    ),
                  );
                },
                child: _showScrollToBottom
                    ? FloatingActionButton.small(
                        heroTag: 'report_detail_scroll_fab',
                        key: ValueKey(
                            'scroll_fab_${_isScrolledToBottom ? 'up' : 'down'}'),
                        onPressed: _isScrolledToBottom
                            ? _scrollToTop
                            : _scrollToBottom,
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        tooltip: _isScrolledToBottom
                            ? 'Gulir ke atas'
                            : 'Gulir ke bawah',
                        child: Icon(
                          _isScrolledToBottom
                              ? Icons.keyboard_double_arrow_up
                              : Icons.keyboard_double_arrow_down,
                          size: 22,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('scroll_fab_hidden')),
              ),
          ),
        ],
      ),
    );
  }

  // ── Build grouped timeline ──────────────────────────────────────────────────
  List<Widget> _buildGroupedTimeline(List<TimelineEvent> timeline) {
    final canViewRepliesInThread = _canViewRepliesInThread(timeline);
    final canReplyInThread = _canReplyInThread(timeline);
    final groups = _buildTimelineStatusGroups(timeline);
    final result = <Widget>[];

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final isFirstGroup = i == 0;
      final statusColor = _statusColor(group.status);
      final isLastGroup = i == groups.length - 1;

      result.add(_TimelineStatusGroupSection(
        reportId: _report.id,
        canViewReplies: canViewRepliesInThread,
        canReply: canReplyInThread,
        group: group,
        isFirstGroup: isFirstGroup,
        isLastGroup: isLastGroup,
        isCurrentGroup: isLastGroup,
        statusColor: statusColor,
        statusIcon: _statusIcon(group.status),
        formatDate: _formatDate,
      ));
    }

    return result;
  }

  List<_TimelineStatusGroup> _buildTimelineStatusGroups(
    List<TimelineEvent> timeline,
  ) {
    final groups = <_TimelineStatusGroup>[];
    for (final event in timeline) {
      if (groups.isEmpty || !groups.last.accepts(event)) {
        groups.add(_TimelineStatusGroup(
          status: event.status,
          subStatus: event.subStatus,
          firstEvent: event,
        ));
      } else {
        groups.last.add(event);
      }
    }
    return groups;
  }

  Future<void> _refreshTimelineInBackground() async {
    if (_didBackgroundTimelineRefresh) return;
    _didBackgroundTimelineRefresh = true;
    try {
      await _timelineFuture;
      if (!mounted) return;
      setState(() {
        _timelineFuture = ReportStore.instance.loadTimeline(_report.id, force: true);
      });
      await _timelineFuture;
      if (!mounted) return;
      setState(() {});
      _prefetchAllTimelineReplies();
    } catch (_) {
      // Keep cached timeline visible when background refresh fails.
    }
  }

  bool _canViewRepliesInThread(List<TimelineEvent> timeline) {
    final user = _currentUser;
    if (user == null) return false;
    if (timeline.any((e) => e.replyCount > 0)) return true;

    if (user.isAdmin || user.isSuperadmin) return true;
    if (_report.reporterId == user.id) return true;

    final fullName = user.fullName.toLowerCase();
    final dept = (user.department ?? '').toLowerCase();
    final picDepartment = (_report.picDepartment ?? '').toLowerCase();
    final inspector = (_report.nameInspector ?? '').toLowerCase();
    final reportedDepartment = (_report.departemen ?? '').toLowerCase();

    final isAssignee = picDepartment.contains(fullName) ||
        inspector.contains(fullName) ||
        (dept.isNotEmpty && reportedDepartment.contains(dept));
    if (isAssignee) return true;

    return timeline.any((e) => e.actorUserId == user.id);
  }

  bool _canReplyInThread(List<TimelineEvent> timeline) {
    return _canViewRepliesInThread(timeline) &&
        _report.status != ReportStatus.closed;
  }

  // ── Step bar (Open → In Progress → Closed) ─────────────────────────────────
  Widget _buildStepBar(List<TimelineEvent> timeline) {
    final steps = [
      ReportStatus.open,
      ReportStatus.inProgress,
      ReportStatus.closed
    ];
    final reached = timeline.map((e) => e.status).toSet();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftStep = steps[i ~/ 2];
          final rightStep = steps[i ~/ 2 + 1];
          final active =
              reached.contains(leftStep) && reached.contains(rightStep);
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 17),
              height: 3,
              decoration: BoxDecoration(
                color: active ? _blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
        final step = steps[i ~/ 2];
        final isDone = reached.contains(step);
        final isCur = _report.status == step;
        final color = _statusColor(step);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDone ? color : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDone ? color : Colors.grey.shade300,
                    width: isCur ? 3 : 1.5),
                boxShadow: isCur
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: Icon(_statusIcon(step),
                  size: 16,
                  color: isDone ? Colors.white : Colors.grey.shade400),
            ),
            const SizedBox(height: 5),
            Text(
              step.label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? color : Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            if (isCur && _report.subStatus != null) ...[
              const SizedBox(height: 2),
              Text(_report.subStatus!.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        );
      }),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _card({required Widget child, EdgeInsets margin = EdgeInsets.zero}) =>
      Container(
        margin: margin,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      );
}

class _TimelineStatusGroup {
  final ReportStatus status;
  final ReportSubStatus? subStatus;
  final List<TimelineEvent> events;

  _TimelineStatusGroup({
    required this.status,
    required this.subStatus,
    required TimelineEvent firstEvent,
  }) : events = [firstEvent];

  String get label => subStatus?.label ?? status.label;
  DateTime get startedAt => events.first.timestamp;

  bool accepts(TimelineEvent event) {
    return event.status == status && event.subStatus == subStatus;
  }

  void add(TimelineEvent event) => events.add(event);
}

class _TimelineStatusGroupSection extends StatelessWidget {
  final String reportId;
  final bool canViewReplies;
  final bool canReply;
  final _TimelineStatusGroup group;
  final bool isFirstGroup;
  final bool isLastGroup;
  final bool isCurrentGroup;
  final Color statusColor;
  final IconData statusIcon;
  final String Function(DateTime) formatDate;

  const _TimelineStatusGroupSection({
    required this.reportId,
    required this.canViewReplies,
    required this.canReply,
    required this.group,
    required this.isFirstGroup,
    required this.isLastGroup,
    required this.isCurrentGroup,
    required this.statusColor,
    required this.statusIcon,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = statusColor.withValues(alpha: 0.18);

    return Stack(
        children: [
          Positioned(
            top: isFirstGroup ? 24 : 0,
            bottom: 0,
            left: 19,
            width: 2,
            child: ColoredBox(color: lineColor),
          ),
          Positioned(
            top: 24,
            left: 20,
            width: 28,
            height: 1.5,
            child: ColoredBox(color: lineColor),
          ),
          Positioned(
            top: 18,
            left: 14,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 2),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 40),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              flex: 11,
                              child: ClipPath(
                                clipper: const _TimelineStatusBannerClipper(),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        statusColor,
                                        Color.lerp(
                                              statusColor,
                                              Colors.black,
                                              0.12,
                                            ) ??
                                            statusColor,
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.1,
                                          ),
                                          color: Colors.white
                                              .withValues(alpha: 0.14),
                                        ),
                                        child: Icon(
                                          statusIcon,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          group.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 9,
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  formatDate(group.startedAt),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...group.events.asMap().entries.map((entry) {
                final index = entry.key;
                final event = entry.value;
                final isLastInGroup = index == group.events.length - 1;
                return _TimelineItem(
                  reportId: reportId,
                  canViewReplies: canViewReplies,
                  canReply: canReply,
                  event: event,
                  isLastInGroup: isLastInGroup,
                  isCurrent: isCurrentGroup && isLastInGroup,
                  statusColor: statusColor,
                  formatDate: formatDate,
                );
              }),
              if (!isLastGroup) const SizedBox(height: 18),
            ],
          ),
        ],
      );
  }
}

class _TimelineStatusBannerClipper extends CustomClipper<Path> {
  const _TimelineStatusBannerClipper();

  @override
  Path getClip(Size size) {
    const slashInset = 16.0;
    final cut = slashInset.clamp(0, size.width / 2).toDouble();
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _TimelineStatusBannerClipper oldClipper) {
    return false;
  }
}

// ── Timeline item ─────────────────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final String reportId;
  final bool canViewReplies;
  final bool canReply;
  final TimelineEvent event;
  final bool isLastInGroup;
  final bool isCurrent;
  final Color statusColor;
  final String Function(DateTime) formatDate;

  const _TimelineItem({
    required this.reportId,
    required this.canViewReplies,
    required this.canReply,
    required this.event,
    required this.isLastInGroup,
    required this.isCurrent,
    required this.statusColor,
    required this.formatDate,
  });

  Future<void> _openTimelinePreview(
      BuildContext context, List<String> images, int initialIndex) async {
    await precacheImage(
      CachedNetworkImageProvider(images[initialIndex]),
      context,
    );
    if (!context.mounted) return;
    final previewController = PageController(initialPage: initialIndex);
    final Map<int, TransformationController> controllers = {};
    final Map<int, VoidCallback> listeners = {};
    var doubleTapPosition = Offset.zero;
    const doubleTapZoomScale = 2.5;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          var currentIndex = initialIndex;
          var isZoomed = false;
          return StatefulBuilder(
            builder: (context, setPreviewState) {
              TransformationController controllerFor(int i) {
                final existing = controllers[i];
                if (existing != null) return existing;
                final c = TransformationController();
                void listener() {
                  final scale = c.value.getMaxScaleOnAxis();
                  final zoomed = scale > 1.0;
                  if (zoomed != isZoomed) {
                    setPreviewState(() => isZoomed = zoomed);
                  }
                }

                c.addListener(listener);
                controllers[i] = c;
                listeners[i] = listener;
                return c;
              }

              void handleDoubleTap(int i) {
                final c = controllerFor(i);
                final currentScale = c.value.getMaxScaleOnAxis();
                if (currentScale > 1.0) {
                  c.value = Matrix4.identity();
                } else {
                  const s = doubleTapZoomScale;
                  final x = -doubleTapPosition.dx * (s - 1);
                  final y = -doubleTapPosition.dy * (s - 1);
                  // Column-major: scale on diagonal, translation in last column.
                  c.value = Matrix4(
                    s,
                    0,
                    0,
                    0,
                    0,
                    s,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                    x,
                    y,
                    0,
                    1,
                  );
                }
              }

              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  iconTheme: const IconThemeData(color: Colors.white),
                  elevation: 0,
                  title: Text(
                    '${currentIndex + 1}/${images.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
                extendBodyBehindAppBar: true,
                body: PageView.builder(
                  controller: previewController,
                  physics: isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (idx) {
                    final old = currentIndex;
                    setPreviewState(() {
                      currentIndex = idx;
                      isZoomed = false;
                    });
                    controllers[old]?.value = Matrix4.identity();
                  },
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: GestureDetector(
                        onDoubleTapDown: (details) =>
                            doubleTapPosition = details.localPosition,
                        onDoubleTap: () => handleDoubleTap(index),
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          transformationController: controllerFor(index),
                          child: CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.contain,
                            placeholder: (_, __) =>
                                const CircularProgressIndicator(
                                    color: Colors.white),
                            errorWidget: (_, __, ___) => const Icon(Icons.image,
                                color: Colors.white54, size: 80),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    ).then((_) {
      for (final entry in controllers.entries) {
        final l = listeners[entry.key];
        if (l != null) entry.value.removeListener(l);
        entry.value.dispose();
      }
      previewController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canViewReplies = this.canViewReplies &&
        !event.timelineLogId.startsWith('implicit-') &&
        !event.timelineLogId.startsWith('fallback-') &&
        event.timelineLogId.isNotEmpty;
    final canReply = this.canReply && canViewReplies;

    return _TimelineThreadCard(
      reportId: reportId,
      canViewReplies: canViewReplies,
      canReply: canReply,
      event: event,
      isLastInGroup: isLastInGroup,
      isCurrent: isCurrent,
      statusColor: statusColor,
      formatDate: formatDate,
      openTimelinePreview: _openTimelinePreview,
    );
  }
}

class _TimelineThreadCard extends StatefulWidget {
  final String reportId;
  final bool canViewReplies;
  final bool canReply;
  final TimelineEvent event;
  final bool isLastInGroup;
  final bool isCurrent;
  final Color statusColor;
  final String Function(DateTime) formatDate;
  final Future<void> Function(BuildContext, List<String>, int)
      openTimelinePreview;

  const _TimelineThreadCard({
    required this.reportId,
    required this.canViewReplies,
    required this.canReply,
    required this.event,
    required this.isLastInGroup,
    required this.isCurrent,
    required this.statusColor,
    required this.formatDate,
    required this.openTimelinePreview,
  });

  @override
  State<_TimelineThreadCard> createState() => _TimelineThreadCardState();
}

class _ReplyNode {
  final TimelineReply reply;
  final List<_ReplyNode> children;
  _ReplyNode(this.reply) : children = [];
}

class _TimelineThreadCardState extends State<_TimelineThreadCard> {
  final TextEditingController _replyCtrl = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  final List<XFile> _replyAttachments = [];
  bool _expanded = false;
  bool _showComposer = false;
  bool _loadingReplies = false;
  bool _posting = false;
  bool _showAllReplies = false;
  TimelineReply? _replyingTo;
  List<TimelineReply> _replies = const [];
  bool _loadRepliesFailed = false;

  @override
  void initState() {
    super.initState();
    final cached = ReportStore.instance.getReplies(widget.event.timelineLogId);
    if (cached.isNotEmpty) {
      _replies = cached;
    }
  }

  List<_ReplyNode> _buildReplyTree() {
    final byId = <String, _ReplyNode>{
      for (final r in _replies) r.id: _ReplyNode(r),
    };
    final roots = <_ReplyNode>[];
    for (final r in _replies) {
      final node = byId[r.id]!;
      final pid = r.parentReplyId;
      if (pid != null && byId.containsKey(pid)) {
        byId[pid]!.children.add(node);
      } else {
        roots.add(node);
      }
    }
    int byTs(_ReplyNode a, _ReplyNode b) =>
        a.reply.timestamp.compareTo(b.reply.timestamp);
    roots.sort(byTs);
    for (final r in roots) {
      r.children.sort(byTs);
    }
    return roots;
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadReplies({bool force = false}) async {
    if (!widget.canViewReplies) return;
    setState(() {
      _loadingReplies = true;
      _loadRepliesFailed = false;
    });
    try {
      final replies = await ReportStore.instance.loadReplies(
        widget.reportId,
        widget.event.timelineLogId,
        force: force,
      );
      if (!mounted) return;
      setState(() {
        _replies = replies;
        _loadingReplies = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingReplies = false;
        _loadRepliesFailed = true;
      });
    }
  }

  Future<void> _submitReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      String? attachmentUrl;
      final attachmentUrls = <String>[];
      for (final file in _replyAttachments) {
        final uploaded = await SupabaseStorageService.uploadImage(
          imagePath: file.path,
          folder: SupabaseConfig.reportLogsFolder,
        );
        if (uploaded == null || uploaded.isEmpty) {
          throw Exception('upload_failed');
        }
        attachmentUrls.add(uploaded);
      }
      if (attachmentUrls.isNotEmpty) attachmentUrl = attachmentUrls.first;
      await ReportStore.instance.postReply(
        widget.reportId,
        widget.event.timelineLogId,
        text,
        parentReplyId: _replyingTo?.id,
        attachmentUrl: attachmentUrl,
        attachmentUrls: attachmentUrls,
      );
      _replyCtrl.clear();
      _replyAttachments.clear();
      await _loadReplies(force: true);
      if (!mounted) return;
      setState(() {
        _expanded = true;
        _showComposer = false;
        _replyingTo = null;
        _loadRepliesFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim balasan.')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _pickReplyAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Sumber Foto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1A56C4)),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF1A56C4)),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (source == ImageSource.gallery) {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _replyAttachments.addAll(picked);
      });
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (!mounted || picked == null) return;
    setState(() => _replyAttachments.add(picked));
  }

  Future<void> _toggleTopLevelComposer() async {
    if (_replies.isEmpty) await _loadReplies(force: true);
    if (!mounted) return;
    final showComposer = !_showComposer || _replyingTo != null;
    setState(() {
      _showComposer = showComposer;
      _replyingTo = null;
    });
  }

  void _cancelReplyComposer() {
    if (_posting) return;
    setState(() {
      _showComposer = false;
      _replyingTo = null;
      _replyCtrl.clear();
      _replyAttachments.clear();
    });
  }

  Widget _buildInlineMeta({
    required IconData icon,
    required String text,
    required TextStyle style,
    Color iconColor = Colors.grey,
    double iconSize = 12,
    bool expandText = false,
  }) {
    return Row(
      mainAxisSize: expandText ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 4),
        if (expandText)
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          )
        else
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
      ],
    );
  }

  Widget _buildUserAvatar({
    required String actor,
    String? photoUrl,
    required double radius,
    required double fontSize,
  }) {
    final safePhotoUrl = photoUrl?.trim();
    final hasPhoto = safePhotoUrl != null && safePhotoUrl.isNotEmpty;
    final initial =
        actor.trim().isNotEmpty ? actor.trim()[0].toUpperCase() : '?';

    Widget avatarFallback() {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE3ECFF),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: fontSize,
            color: Color(0xFF1A56C4),
          ),
        ),
      );
    }

    if (!hasPhoto) return avatarFallback();

    final size = radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: CachedNetworkImage(
          imageUrl: safePhotoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => avatarFallback(),
        ),
      ),
    );
  }

  Widget _buildActorMeta({
    required String actor,
    String? photoUrl,
    required TextStyle style,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildUserAvatar(
          actor: actor,
          photoUrl: photoUrl,
          radius: 9,
          fontSize: 9,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            actor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _buildReplyTile({
    required TimelineReply reply,
    required Color threadLineColor,
    required int indentLevel,
    required bool isLastInGroup,
  }) {
    // The vertical group line is painted once by the status section at x ≈ 20
    // (centered in the parent's 40-px timeline column). Each reply
    // row only renders a horizontal arm from x=20 to its box's left edge so
    // the thread reads as one continuous line from the parent dot down
    // through every reply.
    const lineCenterX = 20.0;
    const armTopY = 18.0;
    const armThickness = 1.4;
    final leftColWidth = 56.0 + 12.0 * indentLevel;
    final itemGap = isLastInGroup ? 0.0 : 6.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: leftColWidth,
            child: Stack(
              children: [
                const Positioned.fill(child: SizedBox.shrink()),
                Positioned(
                  top: armTopY,
                  left: lineCenterX,
                  width: leftColWidth - lineCenterX,
                  height: armThickness,
                  child: ColoredBox(color: threadLineColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: itemGap),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserAvatar(
                      actor: reply.actor,
                      photoUrl: reply.actorPhotoUrl,
                      radius: 12,
                      fontSize: 11,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reply.actor,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            widget.formatDate(reply.timestamp),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reply.message,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (reply.attachmentUrls.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: reply.attachmentUrls.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (_, imgIdx) {
                                  final url = reply.attachmentUrls[imgIdx];
                                  return GestureDetector(
                                    onTap: () async =>
                                        widget.openTimelinePreview(
                                      context,
                                      reply.attachmentUrls,
                                      imgIdx,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: CachedNetworkImage(
                                        imageUrl: url,
                                        height: 90,
                                        width: 90,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          height: 90,
                                          width: 90,
                                          color: Colors.grey.shade200,
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          height: 90,
                                          width: 90,
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyHeader({
    required int replyCount,
    required bool expanded,
    required Future<void> Function() onTap,
  }) {
    final label = replyCount > 0
        ? (expanded
            ? 'Sembunyikan $replyCount balasan'
            : 'Tampilkan $replyCount balasan')
        : (expanded ? 'Sembunyikan balasan' : 'Tampilkan balasan');

    // Forum-thread style: no box, no horizontal arm — only a plain
    // "show replies" link indented past the vertical timeline line so the
    // line keeps reading as one continuous stroke behind the text.
    return Padding(
      padding: const EdgeInsets.only(left: 36, bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: const Color(0xFF1A56C4),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1A56C4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyThread(
    _ReplyNode root, {
    required Color threadLineColor,
    required bool isLastRoot,
  }) {
    return Column(
      children: [
        _buildReplyTile(
          reply: root.reply,
          threadLineColor: threadLineColor,
          indentLevel: 0,
          isLastInGroup: isLastRoot && root.children.isEmpty,
        ),
        for (var i = 0; i < root.children.length; i++)
          _buildReplyTile(
            reply: root.children[i].reply,
            threadLineColor: threadLineColor,
            indentLevel: 1,
            isLastInGroup: isLastRoot && i == root.children.length - 1,
          ),
      ],
    );
  }

  String? _activityMessage() {
    final note = widget.event.note?.trim();
    if (note != null && note.isNotEmpty) return widget.event.note;

    final taggedUserName = widget.event.taggedUserName?.trim();
    if (widget.event.subStatus == ReportSubStatus.assigned &&
        taggedUserName != null &&
        taggedUserName.isNotEmpty) {
      return 'Ditugaskan ke $taggedUserName';
    }

    final subStatus = widget.event.subStatus;
    if (subStatus != null) return 'Tahap ${subStatus.label} dilakukan';

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final threadLineColor = Colors.blueGrey.shade100;
    final replyCount =
        _replies.isEmpty ? widget.event.replyCount : _replies.length;
    final replyRoots = _buildReplyTree();
    final visibleReplyRoots = _showAllReplies
        ? replyRoots
        : replyRoots.take(3).toList(growable: false);
    final hasHiddenReplyRoots = replyRoots.length > visibleReplyRoots.length;
    final activityMessage = _activityMessage();

    return Padding(
      padding: EdgeInsets.only(bottom: widget.isLastInGroup ? 0 : 10),
      child: Stack(
        children: [
          Positioned(
            top: 18,
            left: 19,
            width: 29,
            height: 1.4,
            child: ColoredBox(color: threadLineColor),
          ),
          Positioned(
            top: 14,
            left: 15,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.statusColor.withValues(alpha: 0.7),
                  width: 2,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueGrey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.025),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildActorMeta(
                                      actor: widget.event.actor,
                                      photoUrl: widget.event.actorPhotoUrl,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildInlineMeta(
                                      icon: Icons.access_time,
                                      text: widget.formatDate(
                                        widget.event.timestamp,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (widget.isCurrent) ...[
                                Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 22),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF1A56C4)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'TERKINI',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A56C4),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              TextButton.icon(
                                onPressed: widget.canReply
                                    ? _toggleTopLevelComposer
                                    : null,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 30),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 3,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: const Color(0xFF1A56C4),
                                  disabledForegroundColor:
                                      Colors.grey.shade700,
                                ),
                                icon: const Icon(
                                  Icons.reply_rounded,
                                  size: 17,
                                ),
                                label: const Text(
                                  'Balas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (activityMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                activityMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                          if (widget.event.photoPaths.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 112,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: widget.event.photoPaths.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, idx) {
                                  final imageUrl = widget.event.photoPaths[idx];
                                  return GestureDetector(
                                    onTap: () async =>
                                        widget.openTimelinePreview(
                                      context,
                                      widget.event.photoPaths,
                                      idx,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        height: 112,
                                        width: 112,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          height: 112,
                                          width: 112,
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          height: 112,
                                          width: 112,
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.canViewReplies &&
                  (widget.event.replyCount > 0 ||
                      _replies.isNotEmpty ||
                      _loadRepliesFailed)) ...[
                const SizedBox(height: 8),
                _buildReplyHeader(
                  replyCount: replyCount,
                  expanded: _expanded,
                  onTap: () async {
                    if (_replies.isEmpty) await _loadReplies(force: true);
                    if (!context.mounted) return;
                    if (_replies.isEmpty && widget.event.replyCount > 0) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Balasan tidak bisa dimuat. Coba refresh atau periksa akses akun.'),
                        ),
                      );
                    }
                    setState(() {
                      _expanded = !_expanded;
                      if (!_expanded) _showAllReplies = false;
                    });
                  },
                ),
              ],
              if (_loadingReplies)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 64),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _expanded && replyRoots.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...visibleReplyRoots.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final isLastRoot = !hasHiddenReplyRoots &&
                                idx == visibleReplyRoots.length - 1;
                            return _buildReplyThread(
                              entry.value,
                              threadLineColor: threadLineColor,
                              isLastRoot: isLastRoot,
                            );
                          }),
                          if (hasHiddenReplyRoots)
                            Row(
                              children: [
                                const SizedBox(width: 56),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () => setState(
                                          () => _showAllReplies = true),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                        ),
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor:
                                            const Color(0xFF1A56C4),
                                      ),
                                      child: Text(
                                        'Lihat ${replyRoots.length - 3} balasan lainnya',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              if (widget.canReply && _showComposer) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _posting ? null : _cancelReplyComposer,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            disabledForegroundColor: Colors.grey.shade400,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (_replyingTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                              left: BorderSide(
                                color: Color(0xFF1A56C4),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Membalas @${_replyingTo!.actor}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A56C4),
                                      ),
                                    ),
                                    if (_replyingTo!.message.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Text(
                                          _replyingTo!.message,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() => _replyingTo = null),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_replyAttachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            height: 60,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(
                                  top: 4, right: 4, bottom: 4),
                              itemCount: _replyAttachments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (_, idx) {
                                final att = _replyAttachments[idx];
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: kIsWeb
                                          ? Container(
                                              width: 52,
                                              height: 52,
                                              color: Colors.blueGrey.shade50,
                                              child: const Icon(
                                                Icons.photo_library,
                                                size: 22,
                                                color: Color(0xFF1A56C4),
                                              ),
                                            )
                                          : Image.file(
                                              File(att.path),
                                              width: 52,
                                              height: 52,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => setState(
                                            () =>
                                                _replyAttachments.removeAt(idx),
                                          ),
                                          customBorder: const CircleBorder(),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black87,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      TextField(
                        controller: _replyCtrl,
                        focusNode: _replyFocus,
                        minLines: 2,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Tulis balasan...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blueGrey.shade100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A56C4),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: _posting ? null : _pickReplyAttachment,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_file_rounded,
                                    size: 18,
                                    color: _posting
                                        ? Colors.grey.shade400
                                        : const Color(0xFF1A56C4),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Lampirkan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _posting
                                          ? Colors.grey.shade400
                                          : const Color(0xFF1A56C4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          Material(
                            color: _posting
                                ? const Color(0xFF8FB0EA)
                                : const Color(0xFF1A56C4),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: _posting ? null : _submitReply,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 9,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_posting)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.send_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _posting ? 'Mengirim...' : 'Kirim',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1A56C4)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A56C4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF1A56C4).withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18, color: const Color(0xFF1A56C4).withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? Colors.black87)),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    return content;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// UPDATE STATUS MODAL (COMPACT BOTTOM SHEET)
// ══════════════════════════════════════════════════════════════════════════════

class _UpdateStatusSheet extends StatefulWidget {
  final Report report;
  final bool isAdmin;
  final bool isSuperadmin;
  final Function(Report) onUpdate;

  const _UpdateStatusSheet({
    required this.report,
    required this.isAdmin,
    required this.isSuperadmin,
    required this.onUpdate,
  });

  @override
  State<_UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends State<_UpdateStatusSheet> {
  late ReportStatus _selectedStatus;
  ReportSubStatus? _selectedSub;
  final _noteCtrl = TextEditingController();

  // Separate sets for better sync and ID tracking
  final Set<String> _selectedDepts = {};
  final Set<UserEntry> _selectedUsers = {};
  static const _hseKeywords = ['hse', 'k3'];

  List<String> _departments = [];
  final List<XFile> _attachedPhotos = [];
  bool _isSaving = false;

  final _blue = const Color(0xFF1A56C4);
  final _purple = const Color(0xFF9C27B0);
  final _grey = const Color(0xFF757575);

  // Linear flow: must mirror BackfillsReportLogs::LINEAR_FLOW on the backend.
  static const List<ReportSubStatus> _linearFlow = [
    ReportSubStatus.validating,
    ReportSubStatus.approved,
    ReportSubStatus.assigned,
    ReportSubStatus.preparing,
    ReportSubStatus.executing,
    ReportSubStatus.reviewing,
    ReportSubStatus.resolved,
  ];

  // Sub-statuses that may be skipped over (auto-backfilled to the log).
  // Stages NOT listed here are mandatory checkpoints. Must mirror
  // BackfillsReportLogs::SKIPPABLE_SUB_STATUSES on the backend.
  static const Set<ReportSubStatus> _skippableSubStatuses = {
    ReportSubStatus.preparing,
  };

  bool get _canAdminSkipApprovedToAssigned =>
      widget.isAdmin &&
      _currentLinearIndex == _linearFlow.indexOf(ReportSubStatus.validating);

  /// Highest LINEAR_FLOW index already reached. Returns -1 if the report's
  /// current sub-status is null or terminal (rejected/deferred).
  int get _currentLinearIndex {
    final sub = widget.report.subStatus;
    if (sub == null) return -1;
    return _linearFlow.indexOf(sub);
  }

  /// Linear progression rule. Backward is always blocked.
  /// Forward skipping is allowed only when EVERY skipped intermediate stage
  /// is in [_skippableSubStatuses] — currently only `preparing` — except that
  /// admins may jump from `validating` straight to `assigned`. Mandatory
  /// checkpoints (`executing`, `reviewing`, etc.) must be reached explicitly.
  /// Skipped stages are auto-logged on the backend via backfillSkippedSubStatusLogs.
  /// Terminal exits (rejected/deferred) are always allowed when the report
  /// is not yet closed (parent screen guards via _canShowUpdateButton).
  /// Superadmin bypasses everything.
  bool _isTransitionAllowed(ReportSubStatus target) {
    if (widget.isSuperadmin) return true;
    if (target == ReportSubStatus.rejected ||
        target == ReportSubStatus.deferred) {
      return true;
    }
    final ti = _linearFlow.indexOf(target);
    if (ti == -1) return false;
    final cur = _currentLinearIndex;
    if (ti < cur) return false; // backward blocked
    if (ti == cur || ti == cur + 1) return true; // stay or advance one step
    if (_canAdminSkipApprovedToAssigned &&
        target == ReportSubStatus.assigned) {
      return true;
    }
    // Forward skip: every intermediate stage must be skippable.
    for (var i = cur + 1; i < ti; i++) {
      if (!_skippableSubStatuses.contains(_linearFlow[i])) return false;
    }
    return true;
  }

  bool _canSelectMainStatus(ReportStatus status) {
    // Existing role gate.
    if (!widget.isAdmin &&
        status != ReportStatus.open &&
        status != ReportStatus.inProgress) {
      return false;
    }
    if (widget.isSuperadmin) return true;
    return ReportSubStatusInfo.forStatus(status).any(_isTransitionAllowed);
  }

  List<ReportSubStatus> _allowedSubStatusesFor(ReportStatus status) {
    final all = ReportSubStatusInfo.forStatus(status);
    final roleGated = widget.isAdmin
        ? all
        : (status == ReportStatus.open
            ? all.where((s) => s == ReportSubStatus.assigned).toList()
            : all);
    if (widget.isSuperadmin) return roleGated;
    return roleGated.where(_isTransitionAllowed).toList();
  }

  void _syncSelectedSubStatus() {
    final allowed = _allowedSubStatusesFor(_selectedStatus);
    if (allowed.isEmpty) {
      _selectedSub = null;
      return;
    }
    if (_selectedSub == null || !allowed.contains(_selectedSub)) {
      _selectedSub = allowed.first;
    }
  }

  bool _isLockedDept(String dept) {
    final normalized = dept.toLowerCase();
    return _hseKeywords.any(normalized.contains);
  }

  Set<String> get _lockedDepts => _departments.where(_isLockedDept).toSet();

  void _ensureLockedDeptsSelected() {
    if (_lockedDepts.isEmpty) return;
    _selectedDepts.addAll(_lockedDepts);
  }

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    if (!_canSelectMainStatus(_selectedStatus)) {
      _selectedStatus = const [
        ReportStatus.open,
        ReportStatus.inProgress,
        ReportStatus.closed,
      ].firstWhere(
        _canSelectMainStatus,
        orElse: () => ReportStatus.inProgress,
      );
    }
    _selectedSub = widget.report.subStatus;
    _syncSelectedSubStatus();

    // Load initial tags from database - split by comma for individual tracking
    if (widget.report.departemen != null &&
        widget.report.departemen!.isNotEmpty) {
      final depts = widget.report.departemen!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      _selectedDepts.addAll(depts);
    }

    if (widget.report.picDepartment != null &&
        widget.report.picDepartment!.isNotEmpty) {
      final pjas = widget.report.picDepartment!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      for (final pja in pjas) {
        _selectedUsers.add(UserEntry(
          id: '', // ID unknown yet
          fullName: pja,
        ));
      }
    }

    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await ReportService.getDepartments();
      if (mounted) {
        setState(() {
          _departments = depts;
          _ensureLockedDeptsSelected();
        });
      }
    } catch (e) {
      debugPrint('Error loading departments: $e');
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final picked = await picker.pickMultiImage(imageQuality: 70);
      if (picked.isNotEmpty) {
        setState(() => _attachedPhotos.addAll(picked));
      }
    } else {
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() => _attachedPhotos.add(picked));
      }
    }
  }

  void _showPhotoOptions() {
    if (kIsWeb) {
      _pickPhoto(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Sumber Foto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1A56C4)),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF1A56C4)),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUnifiedPicker() {
    String query = '';
    List<UserEntry> users = [];
    bool isLoadingUsers = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (isLoadingUsers) {
            ReportService.getUsers().then((res) {
              if (ctx.mounted) {
                setSheetState(() {
                  users = res;
                  isLoadingUsers = false;
                });
              }
            }).catchError((e) {
              if (ctx.mounted) {
                setSheetState(() => isLoadingUsers = false);
              }
            });
          }

          final normalizedQuery = query.toLowerCase();
          final filteredDepts = _departments
              .where((d) => d.toLowerCase().contains(normalizedQuery))
              .toList();
          final filteredUsers = users
              .where((u) =>
                  u.fullName.toLowerCase().contains(normalizedQuery) ||
                  (u.department?.toLowerCase().contains(normalizedQuery) ??
                      false))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Tag Departemen / PJA',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari departemen atau nama...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      setSheetState(() {
                        query = v;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (_selectedDepts.isNotEmpty ||
                          _selectedUsers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('TERPILIH',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  letterSpacing: 0.5)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ..._selectedDepts.map((dept) => Chip(
                                    label: Text(dept,
                                        style: const TextStyle(fontSize: 12)),
                                    onDeleted: _isLockedDept(dept)
                                        ? null
                                        : () {
                                            setState(() =>
                                                _selectedDepts.remove(dept));
                                            setSheetState(() {});
                                          },
                                    deleteIcon: _isLockedDept(dept)
                                        ? null
                                        : const Icon(Icons.close, size: 14),
                                    backgroundColor: const Color(0xFF1A56C4)
                                        .withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    side: BorderSide(
                                        color: const Color(0xFF1A56C4)
                                            .withValues(alpha: 0.2)),
                                  )),
                              ..._selectedUsers.map((user) => Chip(
                                    label: Text(user.fullName,
                                        style: const TextStyle(fontSize: 12)),
                                    onDeleted: () {
                                      setState(() => _selectedUsers.removeWhere(
                                          (u) => u.fullName == user.fullName));
                                      setSheetState(() {});
                                    },
                                    deleteIcon:
                                        const Icon(Icons.close, size: 14),
                                    backgroundColor:
                                        Colors.orange.withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    side: BorderSide(
                                        color: Colors.orange
                                            .withValues(alpha: 0.2)),
                                  )),
                            ],
                          ),
                        ),
                        const Divider(height: 32),
                      ],
                      if (filteredDepts.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('DEPARTEMEN',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                        ...filteredDepts.map((dept) {
                          final isSelected = _selectedDepts.contains(dept);
                          final isLocked = _isLockedDept(dept);
                          return ListTile(
                            leading:
                                const Icon(Icons.business_outlined, size: 20),
                            title: Text(
                              dept,
                              style: TextStyle(
                                fontSize: 14,
                                color: isLocked ? Colors.grey.shade500 : null,
                              ),
                            ),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isLocked
                                  ? Colors.grey.shade400
                                  : isSelected
                                      ? _blue
                                      : Colors.grey,
                            ),
                            onTap: isLocked
                                ? null
                                : () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedDepts.remove(dept);
                                      } else {
                                        _selectedDepts.add(dept);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                          );
                        }),
                      ],
                      if (isLoadingUsers)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator())),
                      if (!isLoadingUsers && filteredUsers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('PJA (PERSON IN CHARGE)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                        ...filteredUsers.map((user) {
                          final isSelected = _selectedUsers
                              .any((u) => u.fullName == user.fullName);
                          return ListTile(
                            leading: const Icon(Icons.person_outline, size: 20),
                            title: Text(user.fullName,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: user.department != null
                                ? Text(user.department!,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey))
                                : null,
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSelected ? _blue : Colors.grey,
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUsers.removeWhere(
                                      (u) => u.fullName == user.fullName);
                                } else {
                                  _selectedUsers.add(user);
                                }
                              });
                              setSheetState(() {});
                            },
                          );
                        }),
                      ],
                      if (!isLoadingUsers &&
                          filteredUsers.isEmpty &&
                          filteredDepts.isEmpty)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text('Tidak ditemukan',
                                    style: TextStyle(color: Colors.grey)))),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Selesai',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_canSelectMainStatus(_selectedStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Anda tidak memiliki izin memilih status ini.')),
      );
      return;
    }
    final allowedSub = _allowedSubStatusesFor(_selectedStatus);
    if (_selectedSub != null && !allowedSub.contains(_selectedSub)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Anda tidak memiliki izin memilih sub-status ini.')),
      );
      return;
    }

    if (_selectedSub == ReportSubStatus.reviewing && _attachedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto bukti wajib dilampirkan!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalNote =
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

      // Collect all tags for the note
      final List<String> allTags = [
        ..._selectedDepts,
        ..._selectedUsers.map((u) => '${u.fullName} (PJA)')
      ];

      if (allTags.isNotEmpty) {
        final tagStr = 'Tag: ${allTags.join(", ")}';
        finalNote = finalNote == null ? tagStr : '$finalNote\n\n$tagStr';
      }

      // Extract values for dedicated database fields
      final String? department =
          _selectedDepts.isEmpty ? null : _selectedDepts.join(', ');
      final String? picDepartment = _selectedUsers.isEmpty
          ? null
          : _selectedUsers.map((u) => u.fullName).join(', ');
      final String? taggedUserId =
          _selectedUsers.isNotEmpty && _selectedUsers.first.id.isNotEmpty
              ? _selectedUsers.first.id
              : null;

      final updated = await ReportStore.instance.updateStatus(
        widget.report.id,
        _selectedStatus,
        newSubStatus: _selectedSub,
        note: finalNote,
        photoPaths: _attachedPhotos.map((f) => f.path).toList(),
        department: department,
        picDepartment: picDepartment,
        taggedUserId: taggedUserId,
      );

      if (mounted) {
        widget.onUpdate(updated);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Status berhasil diperbarui ke ${_selectedStatus.label}'),
          backgroundColor: _selectedStatus == ReportStatus.open
              ? _blue
              : (_selectedStatus == ReportStatus.inProgress ? _purple : _grey),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        final raw = e.toString();
        final cleaned = raw.startsWith('Exception: ')
            ? raw.substring('Exception: '.length)
            : raw;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status: $cleaned'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 12,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Perbarui Status Laporan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: _blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('STATUS SAAT INI',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(
                          widget.report.subStatus == ReportSubStatus.validating
                              ? ReportSubStatus.validating.label
                              : '${widget.report.status.label}${widget.report.subStatus != null ? ' → ${widget.report.subStatus!.label}' : ''}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('STATUS UTAMA',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusBtn(
                    label: 'Open',
                    color: _blue,
                    isSelected: _selectedStatus == ReportStatus.open,
                    isEnabled: _canSelectMainStatus(ReportStatus.open),
                    onTap: () => setState(() {
                          _selectedStatus = ReportStatus.open;
                          _syncSelectedSubStatus();
                        })),
                const SizedBox(width: 10),
                _StatusBtn(
                    label: 'In Progress',
                    color: _purple,
                    isSelected: _selectedStatus == ReportStatus.inProgress,
                    isEnabled: _canSelectMainStatus(ReportStatus.inProgress),
                    onTap: () => setState(() {
                          _selectedStatus = ReportStatus.inProgress;
                          _syncSelectedSubStatus();
                        })),
                const SizedBox(width: 10),
                _StatusBtn(
                    label: 'Closed',
                    color: _grey,
                    isSelected: _selectedStatus == ReportStatus.closed,
                    isEnabled: _canSelectMainStatus(ReportStatus.closed),
                    onTap: () => setState(() {
                          _selectedStatus = ReportStatus.closed;
                          _syncSelectedSubStatus();
                        })),
              ],
            ),
            const SizedBox(height: 24),
            const Text('SUB-STATUS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children:
                  ReportSubStatusInfo.forStatus(_selectedStatus).map((sub) {
                final isSelected = _selectedSub == sub;
                final isEnabled =
                    _allowedSubStatusesFor(_selectedStatus).contains(sub);
                final color = isSelected
                    ? (_selectedStatus == ReportStatus.open
                        ? _blue
                        : (_selectedStatus == ReportStatus.inProgress
                            ? _purple
                            : _grey))
                    : (isEnabled ? Colors.grey.shade400 : Colors.grey.shade300);
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 66) / 3,
                  child: ChoiceChip(
                    label: Center(
                      child: Text(sub.label,
                          style: TextStyle(
                              color: !isEnabled
                                  ? Colors.grey.shade500
                                  : isSelected
                                      ? Colors.white
                                      : Colors.black87,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    selected: isSelected,
                    onSelected: isEnabled
                        ? (val) =>
                            setState(() => _selectedSub = val ? sub : null)
                        : null,
                    selectedColor: color,
                    backgroundColor:
                        isEnabled ? Colors.white : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                            color: !isEnabled
                                ? Colors.grey.shade300
                                : isSelected
                                    ? color
                                    : Colors.grey.shade300)),
                    showCheckmark: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            if (_selectedSub == ReportSubStatus.assigned ||
                _selectedSub == ReportSubStatus.deferred) ...[
              const Text('TAG DEPARTEMEN / PJA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showUnifiedPicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 13),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300)),
                          child: Row(children: [
                            const Icon(Icons.person_add_outlined,
                                size: 20, color: Colors.grey),
                            const SizedBox(width: 12),
                            const Expanded(
                                child: Text(
                                    'Ketuk untuk tag orang atau departemen',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13))),
                            Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.grey.shade400),
                          ]),
                        ),
                        if (_selectedDepts.isNotEmpty ||
                            _selectedUsers.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ..._selectedDepts.map((dept) => Chip(
                                    label: Text(dept,
                                        style: const TextStyle(fontSize: 11)),
                                    onDeleted: _isLockedDept(dept)
                                        ? null
                                        : () => setState(
                                            () => _selectedDepts.remove(dept)),
                                    backgroundColor:
                                        _blue.withValues(alpha: 0.1),
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  )),
                              ..._selectedUsers.map((user) => Chip(
                                    label: Text('${user.fullName} (PJA)',
                                        style: const TextStyle(fontSize: 11)),
                                    onDeleted: () => setState(
                                        () => _selectedUsers.remove(user)),
                                    backgroundColor:
                                        _blue.withValues(alpha: 0.1),
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  )),
                            ],
                          ),
                        ],
                      ]),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PHOTO EVIDENCE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                if (_selectedSub == ReportSubStatus.reviewing)
                  const Text('* WAJIB UNTUK REVIEWING',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                height: 80,
                width: double.infinity,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: CustomPaint(
                  painter: _DashedRectPainter(color: Colors.grey.shade300),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _attachedPhotos.isEmpty
                              ? Icons.camera_alt
                              : Icons.add_a_photo,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _attachedPhotos.isEmpty
                              ? 'Tambah foto'
                              : 'Tambah foto lagi (${_attachedPhotos.length})',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_attachedPhotos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachedPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) {
                    final photo = _attachedPhotos[idx];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photo.path),
                            height: 72,
                            width: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _attachedPhotos.removeAt(idx)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tulis Catatan Di Sini...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Batal',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Perubahan',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;
  const _StatusBtn(
      {required this.label,
      required this.color,
      required this.isSelected,
      required this.isEnabled,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: !isEnabled
                ? Colors.grey.shade100
                : isSelected
                    ? color.withValues(alpha: 0.1)
                    : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: !isEnabled
                    ? Colors.grey.shade300
                    : isSelected
                        ? color
                        : Colors.grey.shade300,
                width: isSelected ? 2 : 1),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: !isEnabled
                        ? Colors.grey.shade500
                        : isSelected
                            ? color
                            : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  _DashedRectPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const double dashWidth = 5, dashSpace = 5;
    final Path path = Path();
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      path.moveTo(i, 0);
      path.lineTo(i + dashWidth, 0);
    }
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      path.moveTo(size.width, i);
      path.lineTo(size.width, i + dashWidth);
    }
    for (double i = size.width; i > 0; i -= dashWidth + dashSpace) {
      path.moveTo(i, size.height);
      path.lineTo(i - dashWidth, size.height);
    }
    for (double i = size.height; i > 0; i -= dashWidth + dashSpace) {
      path.moveTo(0, i);
      path.lineTo(0, i - dashWidth);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ── Bottom Nav Item for ReportDetailScreen ──────────────────────────────────
class _ReportDetailNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ReportDetailNavItem({
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
