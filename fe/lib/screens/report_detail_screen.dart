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

class ReportDetailScreen extends StatefulWidget {
  final Report report;
  final bool isDialog;
  const ReportDetailScreen(
      {super.key, required this.report, this.isDialog = false});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Report _report;
  late Future<List<TimelineEvent>> _timelineFuture;
  bool _isLoading = false;
  UserModel? _currentUser;
  bool _showScrollToBottom = false;

  final ScrollController _scrollController = ScrollController();

  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);

  @override
  void initState() {
    super.initState();
    _report = ReportStore.instance.getById(widget.report.id) ?? widget.report;
    _timelineFuture = ReportStore.instance.loadTimeline(_report.id);
    _loadUserAndRefresh();
  }

  /// Evaluates scroll metrics and shows/hides the FAB accordingly.
  /// Called by NotificationListener on every scroll AND content-size change.
  void _updateScrollVisibility(ScrollMetrics metrics) {
    final maxScroll = metrics.maxScrollExtent;
    final currentScroll = metrics.pixels;
    final remaining = maxScroll - currentScroll;
    // Show only when total scrollable area is meaningful (>300px)
    // AND user is NOT near the bottom (>100px remaining)
    final shouldShow = maxScroll > 300 && remaining > 100;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadUserAndRefresh() async {
    final userData = await StorageService.getUser();
    if (userData != null && mounted) {
      setState(() => _currentUser = UserModel.fromJson(userData));
    }
    _refreshData();
  }

  // Admin and Superadmin both have full update authority — treat them the same here.
  bool get _isAdmin =>
      (_currentUser?.isAdmin ?? false) || (_currentUser?.isSuperadmin ?? false);
  bool get _isPJA =>
      _currentUser != null &&
      _report.picDepartment != null &&
      _report.picDepartment!
          .toLowerCase()
          .contains(_currentUser!.fullName.toLowerCase());
  bool get _canUpdate => _isAdmin || _isPJA;
  bool get _isRestrictedPJA => _isPJA && !_isAdmin;

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
      }
    } catch (e) {
      debugPrint('Error refreshing report: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
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
        ReportStatus.pending => const Color(0xFFFF9800), // Amber/Orange
        ReportStatus.open => const Color(0xFF2196F3),
        ReportStatus.inProgress => const Color(0xFF9C27B0),
        ReportStatus.closed => const Color(0xFF757575),
      };

  IconData _statusIcon(ReportStatus s) => switch (s) {
        ReportStatus.pending => Icons.hourglass_empty,
        ReportStatus.open => Icons.flag_outlined,
        ReportStatus.inProgress => Icons.autorenew,
        ReportStatus.closed => Icons.check_circle_outline,
      };

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

  String _formatDueLabel(DateTime due, int? sisa) {
    final dateStr = _formatDateShort(due);
    if (sisa == null) return dateStr;
    if (sisa < 0) return '$dateStr — Terlambat ${-sisa} hari';
    if (sisa == 0) return '$dateStr — Hari ini';
    return '$dateStr — $sisa hari lagi';
  }

  void _showImagePreview(BuildContext context, String imageUrl, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: index == 0
                  ? Hero(
                      tag: 'report_image_${_report.id}',
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const CircularProgressIndicator(
                            color: Colors.white),
                        errorWidget: (_, __, ___) => const Icon(Icons.image,
                            color: Colors.white54, size: 80),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          const CircularProgressIndicator(color: Colors.white),
                      errorWidget: (_, __, ___) => const Icon(Icons.image,
                          color: Colors.white54, size: 80),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUpdateStatusModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UpdateStatusSheet(
        report: _report,
        isRestrictedPJA: _isRestrictedPJA,
        onUpdate: (updatedReport) {
          setState(() {
            _report = updatedReport;
            _timelineFuture = ReportStore.instance.loadTimeline(_report.id);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = [_report.imageUrl];

    return Scaffold(
      backgroundColor: widget.isDialog ? Colors.white : const Color(0xFFF0F0F0),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _showScrollToBottom ? Offset.zero : const Offset(0, 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showScrollToBottom ? 1.0 : 0.0,
          child: FloatingActionButton.small(
            onPressed: _showScrollToBottom ? _scrollToBottom : null,
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            elevation: 4,
            child: const Icon(Icons.keyboard_double_arrow_down, size: 22),
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
      body: NotificationListener<ScrollNotification>(
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
                        onTap: () => _showImagePreview(context, imgUrl, index),
                        child: index == 0
                            ? Hero(
                                tag: 'report_image_${_report.id}',
                                child: CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: const Color(0xFF37474F),
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.white38,
                                            strokeWidth: 2)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF37474F),
                                    child: const Icon(Icons.image,
                                        color: Colors.white24, size: 80),
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: imgUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFF37474F),
                                  child: const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white38,
                                          strokeWidth: 2)),
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
                      _badge(
                          _report.status.label, _statusColor(_report.status)),
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
                        child: Text(
                            '${_currentImageIndex + 1}/${images.length}',
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
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                          radius: 18,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 18),
                            onPressed: () {
                              if (_currentImageIndex > 0) {
                                _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
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
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                          radius: 18,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.arrow_forward_ios,
                                color: Colors.white, size: 18),
                            onPressed: () {
                              if (_currentImageIndex < images.length - 1) {
                                _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
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
                    if (_report.saran != null && _report.saran!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.lightbulb_outline,
                          label: 'Saran Perbaikan',
                          value: _report.saran!),
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
                        icon: Icons.person_outline, title: 'Informasi Pelapor'),
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
                          icon: Icons.event_available_outlined,
                          label: 'Tenggat Waktu',
                          value: _formatDueLabel(
                              _report.dueDate!, _report.sisaHari)),
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
                        title: 'Penugasan'),
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
                    if (_report.location != null &&
                        _report.location!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Lokasi Penugasan',
                          value: _report.location!),
                    ],
                    if (_report.kejadianLocation != null &&
                        _report.kejadianLocation!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.my_location_outlined,
                        label: 'Koordinat Penugasan',
                        value: _report.kejadianLocation!,
                        onTap: () async {
                          final coords = _report.kejadianLocation!.split(',');
                          if (coords.length != 2) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Format koordinat tidak valid')),
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
                                    content:
                                        Text('Format koordinat tidak valid')),
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
                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.map_outlined,
                              color: Color(0xFF1A56C4), size: 18),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Card: Klasifikasi ──────────────────────────────────────────
              _card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                        icon: Icons.category_outlined, title: 'Klasifikasi'),
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Kategori',
                        value: _report.category?.label ?? _report.type.label),
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
                  ],
                ),
              ),

              // ── Card: Informasi Tambahan ───────────────────────────────────
              if ((_report.pelaporLocation != null &&
                      _report.pelaporLocation!.isNotEmpty) ||
                  (_report.ticketNumber != null &&
                      _report.ticketNumber!.isNotEmpty))
                _card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                          icon: Icons.info_outline,
                          title: 'Informasi Tambahan'),
                      if (_report.pelaporLocation != null &&
                          _report.pelaporLocation!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                            icon: Icons.my_location_outlined,
                            label: 'Koordinat Pelapor',
                            value: _report.pelaporLocation!),
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
                      if (_report.area != null && _report.area!.isNotEmpty) ...[
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
                          const Icon(Icons.timeline, color: _blue, size: 20),
                          const SizedBox(width: 8),
                          const Text('Progress Laporan',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
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
                        const SizedBox(height: 20),
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
                    ),
                  );
                },
              ),

              // ── Action button ──────────────────────────────────────────────
              if (_canUpdate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showUpdateStatusModal(),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Update Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build grouped timeline ──────────────────────────────────────────────────
  List<Widget> _buildGroupedTimeline(List<TimelineEvent> timeline) {
    final groups = <ReportStatus, List<TimelineEvent>>{};
    for (final e in timeline) {
      groups.putIfAbsent(e.status, () => []).add(e);
    }

    final result = <Widget>[];
    final statuses = [
      ReportStatus.open,
      ReportStatus.inProgress,
      ReportStatus.closed
    ];

    for (final status in statuses) {
      final events = groups[status];
      if (events == null) continue;

      final statusColor = _statusColor(status);
      final isCurrentGroup = _report.status == status;

      result.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentGroup
                    ? statusColor
                    : statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(status),
                    size: 12,
                    color: isCurrentGroup ? Colors.white : statusColor),
                const SizedBox(width: 5),
                Text(status.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrentGroup ? Colors.white : statusColor)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Container(
                    height: 1, color: statusColor.withValues(alpha: 0.2))),
          ]),
        ),
      );

      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final isLastInGroup = i == events.length - 1;
        final isVeryLast = status == _report.status && isLastInGroup;

        result.add(
          _TimelineItem(
            event: event,
            isLast: isLastInGroup,
            isCurrent: isVeryLast,
            statusColor: statusColor,
            statusIcon: _statusIcon(status),
            formatDate: _formatDate,
            formatShort: _formatDateShort,
          ),
        );
      }

      result.add(const SizedBox(height: 4));
    }

    return result;
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
            Text(step.label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                    color: isDone ? color : Colors.grey)),
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

// ── Timeline item ─────────────────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final TimelineEvent event;
  final bool isLast;
  final bool isCurrent;
  final Color statusColor;
  final IconData statusIcon;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatShort;

  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.isCurrent,
    required this.statusColor,
    required this.statusIcon,
    required this.formatDate,
    required this.formatShort,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left column: dot + line ──────────────────────────────────
          SizedBox(
            width: 40,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? statusColor
                        : statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: statusColor, width: isCurrent ? 2.5 : 1.5),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                                color: statusColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ]
                        : null,
                  ),
                  child: Icon(statusIcon,
                      size: 16, color: isCurrent ? Colors.white : statusColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Right column: content ────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sub-status label + "TERKINI" badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? statusColor
                            : statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.subStatus?.label ?? event.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : statusColor,
                        ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF1A56C4)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Text('TERKINI',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A56C4),
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 6),

                  // Actor + timestamp
                  Row(children: [
                    const Icon(Icons.person_outline,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(event.actor,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(formatDate(event.timestamp),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  ]),

                  // Note
                  if (event.note != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(event.note!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.4)),
                    ),
                  ],

                  // Photo (comes from API as URL)
                  if (event.photoPath != null &&
                      event.photoPath!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(
                                backgroundColor: Colors.transparent,
                                iconTheme:
                                    const IconThemeData(color: Colors.white),
                                elevation: 0,
                              ),
                              extendBodyBehindAppBar: true,
                              body: Center(
                                child: InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 4.0,
                                  child: CachedNetworkImage(
                                    imageUrl: event.photoPath!,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) =>
                                        const CircularProgressIndicator(
                                            color: Colors.white),
                                    errorWidget: (_, __, ___) => const Icon(
                                        Icons.image,
                                        color: Colors.white54,
                                        size: 80),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: event.photoPath!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 140,
                            color: Colors.grey.shade200,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 140,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image,
                                color: Colors.grey, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
  final Widget? trailing;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
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
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
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
  final bool isRestrictedPJA;
  final Function(Report) onUpdate;

  const _UpdateStatusSheet({
    required this.report,
    required this.isRestrictedPJA,
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

  List<String> _departments = [];
  XFile? _attachedPhoto;
  bool _isSaving = false;

  final _blue = const Color(0xFF1A56C4);
  final _purple = const Color(0xFF9C27B0);
  final _grey = const Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _selectedSub = widget.report.subStatus;

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
      if (mounted) setState(() => _departments = depts);
    } catch (e) {
      debugPrint('Error loading departments: $e');
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
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
            ReportService.getUsers(search: query.isEmpty ? null : query)
                .then((res) {
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

          final filteredDepts = _departments
              .where((d) => d.toLowerCase().contains(query.toLowerCase()))
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
                        isLoadingUsers = true;
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
                                    onDeleted: () {
                                      setState(
                                          () => _selectedDepts.remove(dept));
                                      setSheetState(() {});
                                    },
                                    deleteIcon:
                                        const Icon(Icons.close, size: 14),
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
                          return ListTile(
                            leading:
                                const Icon(Icons.business_outlined, size: 20),
                            title: Text(dept,
                                style: const TextStyle(fontSize: 14)),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSelected ? _blue : Colors.grey,
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected)
                                  _selectedDepts.remove(dept);
                                else
                                  _selectedDepts.add(dept);
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
                      if (!isLoadingUsers && users.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('PJA (PERSON IN CHARGE)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                        ...users.map((user) {
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
                          users.isEmpty &&
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
    if (_selectedSub == ReportSubStatus.reviewing && _attachedPhoto == null) {
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
        photoPath: _attachedPhoto?.path,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
            ),
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
            // Current status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(children: [
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
                          '${widget.report.status.label}${widget.report.subStatus != null ? ' → ${widget.report.subStatus!.label}' : ''}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _blue),
                        ),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // Main status buttons
            const Text('STATUS UTAMA',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Row(children: [
              _StatusBtn(
                  label: 'Open',
                  color: _blue,
                  isSelected: _selectedStatus == ReportStatus.open,
                  onTap: () => setState(() {
                        _selectedStatus = ReportStatus.open;
                        _selectedSub = null;
                      })),
              const SizedBox(width: 10),
              _StatusBtn(
                  label: 'In Progress',
                  color: _purple,
                  isSelected: _selectedStatus == ReportStatus.inProgress,
                  onTap: () => setState(() {
                        _selectedStatus = ReportStatus.inProgress;
                        _selectedSub = null;
                      })),
              const SizedBox(width: 10),
              _StatusBtn(
                  label: 'Closed',
                  color: _grey,
                  isSelected: _selectedStatus == ReportStatus.closed,
                  isDisabled: widget.isRestrictedPJA,
                  onTap: () => setState(() {
                        _selectedStatus = ReportStatus.closed;
                        _selectedSub = null;
                      })),
            ]),
            const SizedBox(height: 24),

            // Sub-status chips
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

                // Restriction logic for sub-statuses
                bool isSubDisabled = false;
                if (widget.isRestrictedPJA &&
                    _selectedStatus == ReportStatus.open) {
                  if (sub == ReportSubStatus.validating ||
                      sub == ReportSubStatus.approved) {
                    isSubDisabled = true;
                  }
                }

                final color = isSelected
                    ? (_selectedStatus == ReportStatus.open
                        ? _blue
                        : (_selectedStatus == ReportStatus.inProgress
                            ? _purple
                            : _grey))
                    : Colors.grey.shade400;

                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 66) / 3,
                  child: ChoiceChip(
                    label: Center(
                        child: Text(sub.label,
                            style: TextStyle(
                                color: isSubDisabled
                                    ? Colors.grey.shade400
                                    : (isSelected
                                        ? Colors.white
                                        : Colors.black87),
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis)),
                    selected: isSelected,
                    onSelected: isSubDisabled
                        ? null
                        : (val) =>
                            setState(() => _selectedSub = val ? sub : null),
                    selectedColor: color,
                    backgroundColor:
                        isSubDisabled ? Colors.grey.shade100 : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                            color: isSubDisabled
                                ? Colors.grey.shade200
                                : (isSelected ? color : Colors.grey.shade300))),
                    showCheckmark: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Tag Dept/PJA (shown for assigned/deferred)
            if (_selectedSub == ReportSubStatus.assigned ||
                _selectedSub == ReportSubStatus.deferred) ...[
              const Text('🏷️ TAG DEPARTEMEN / PJA',
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
                                    onDeleted: () => setState(
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

            // Photo evidence
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('📸 PHOTO EVIDENCE',
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
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final picked =
                    await picker.pickImage(source: ImageSource.camera);
                if (picked != null) setState(() => _attachedPhoto = picked);
              },
              child: Container(
                height: 80,
                width: double.infinity,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: CustomPaint(
                  painter: _DashedRectPainter(color: Colors.grey.shade300),
                  child: Center(
                    child: _attachedPhoto != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_attachedPhoto!.path),
                                height: 60, width: 60, fit: BoxFit.cover))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                const Icon(Icons.camera_alt,
                                    size: 20, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('Tambah foto bukti penyelesaian',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 14)),
                              ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Note field
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Notes for reviewer...',
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

            // Action buttons
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16)),
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
                      padding: const EdgeInsets.symmetric(vertical: 16)),
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
            ]),
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
  final bool isDisabled;
  final VoidCallback onTap;

  const _StatusBtn({
    required this.label,
    required this.color,
    required this.isSelected,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDisabled
                ? Colors.grey.shade100
                : (isSelected ? color.withValues(alpha: 0.1) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDisabled
                  ? Colors.grey.shade200
                  : (isSelected ? color : Colors.grey.shade300),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isDisabled
                    ? Colors.grey.shade400
                    : (isSelected ? color : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
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

// ══════════════════════════════════════════════════════════════════════════════
// UPDATE STATUS PAGE (FULLSCREEN)
// ══════════════════════════════════════════════════════════════════════════════
class UpdateStatusPage extends StatefulWidget {
  final Report report;
  final bool isRestrictedPJA;
  const UpdateStatusPage({
    super.key,
    required this.report,
    this.isRestrictedPJA = false,
  });

  @override
  State<UpdateStatusPage> createState() => _UpdateStatusPageState();
}

class _UpdateStatusPageState extends State<UpdateStatusPage> {
  late ReportStatus _selectedStatus;
  ReportSubStatus? _selectedSub;
  final _noteCtrl = TextEditingController();
  final _deferredKeteranganCtrl = TextEditingController();

  // Unified tagging
  final Set<String> _selectedDepts = {};
  final Set<UserEntry> _selectedUsers = {};
  List<String> _departments = [];

  XFile? _attachedPhoto;
  bool _isSaving = false;

  final _blue = const Color(0xFF1A56C4);
  final _purple = const Color(0xFF9C27B0);
  final _grey = const Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _selectedSub = widget.report.subStatus;

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
    final depts = await ReportService.getDepartments();
    if (mounted) setState(() => _departments = depts);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _deferredKeteranganCtrl.dispose();
    super.dispose();
  }

  List<ReportStatus> get _allowedStatuses => ReportStatus.values;

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.pending => const Color(0xFFFF9800),
        ReportStatus.open => const Color(0xFF2196F3),
        ReportStatus.inProgress => const Color(0xFF9C27B0),
        ReportStatus.closed => const Color(0xFF757575),
      };

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) setState(() => _attachedPhoto = picked);
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
            ReportService.getUsers(search: query.isEmpty ? null : query)
                .then((res) {
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

          final filteredDepts = _departments
              .where((d) => d.toLowerCase().contains(query.toLowerCase()))
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
                        isLoadingUsers = true;
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
                                    onDeleted: () {
                                      setState(
                                          () => _selectedDepts.remove(dept));
                                      setSheetState(() {});
                                    },
                                    deleteIcon:
                                        const Icon(Icons.close, size: 14),
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
                          return ListTile(
                            leading:
                                const Icon(Icons.business_outlined, size: 20),
                            title: Text(dept,
                                style: const TextStyle(fontSize: 14)),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSelected
                                  ? const Color(0xFF1A56C4)
                                  : Colors.grey,
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected)
                                  _selectedDepts.remove(dept);
                                else
                                  _selectedDepts.add(dept);
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
                      if (!isLoadingUsers && users.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('PJA (PERSON IN CHARGE)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                        ...users.map((user) {
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
                              color: isSelected
                                  ? const Color(0xFF1A56C4)
                                  : Colors.grey,
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
                          users.isEmpty &&
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
                        backgroundColor: const Color(0xFF1A56C4),
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
    if (_selectedSub == ReportSubStatus.reviewing && _attachedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Foto bukti wajib dilampirkan untuk tahap Reviewing!'),
        backgroundColor: Colors.red,
      ));
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

      if (_selectedSub == ReportSubStatus.assigned ||
          _selectedSub == ReportSubStatus.deferred) {
        final ket = _deferredKeteranganCtrl.text.trim().isEmpty
            ? ''
            : 'Keterangan: ${_deferredKeteranganCtrl.text.trim()}';
        if (ket.isNotEmpty) {
          finalNote = finalNote == null ? ket : '$finalNote\n\n$ket';
        }
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
        photoPath: _attachedPhoto?.path,
        department: department,
        picDepartment: picDepartment,
        taggedUserId: taggedUserId,
      );

      if (mounted) {
        Navigator.pop(context, updated);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Status berhasil diperbarui ke ${_selectedStatus.label}'),
          backgroundColor: _statusColor(_selectedStatus),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Update Status Laporan',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Selection ──────────────────────────────────────────
            const _Label('Status Utama (Berurutan)'),
            const SizedBox(height: 8),
            ..._allowedStatuses.map((s) {
              final isSelected = _selectedStatus == s;
              final isStatusDisabled =
                  widget.isRestrictedPJA && s == ReportStatus.closed;
              final color = isStatusDisabled ? Colors.grey : _statusColor(s);

              return GestureDetector(
                onTap: isStatusDisabled
                    ? null
                    : () => setState(() {
                          _selectedStatus = s;
                          _selectedSub = null;
                        }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isStatusDisabled ? Colors.grey.shade50 : Colors.white,
                    border: Border.all(
                        color: isStatusDisabled
                            ? Colors.grey.shade200
                            : (isSelected ? color : Colors.grey.shade300),
                        width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color:
                              isStatusDisabled ? Colors.grey.shade300 : color),
                      const SizedBox(width: 12),
                      Text(s.label,
                          style: TextStyle(
                              color: isStatusDisabled
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 15)),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle, color: color, size: 20),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // ── Sub Status ───────────────────────────────────────────────
            const _Label('Sub-Status'),
            const SizedBox(height: 8),
            Column(
              children:
                  ReportSubStatusInfo.forStatus(_selectedStatus).map((sub) {
                final isSubSelected = _selectedSub == sub;

                // Restriction logic for sub-statuses
                bool isSubDisabled = false;
                if (widget.isRestrictedPJA &&
                    _selectedStatus == ReportStatus.open) {
                  if (sub == ReportSubStatus.validating ||
                      sub == ReportSubStatus.approved) {
                    isSubDisabled = true;
                  }
                }

                final color =
                    isSubDisabled ? Colors.grey : _statusColor(_selectedStatus);

                return GestureDetector(
                  onTap: isSubDisabled
                      ? null
                      : () => setState(() => _selectedSub = sub),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSubDisabled
                          ? Colors.grey.shade50
                          : (isSubSelected
                              ? color.withValues(alpha: 0.1)
                              : Colors.white),
                      border: Border.all(
                          color: isSubDisabled
                              ? Colors.grey.shade200
                              : (isSubSelected ? color : Colors.grey.shade200)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(sub.label,
                            style: TextStyle(
                                color: isSubDisabled
                                    ? Colors.grey.shade400
                                    : (isSubSelected ? color : Colors.black87),
                                fontWeight: isSubSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        const Spacer(),
                        if (isSubSelected)
                          Icon(Icons.check, color: color, size: 18),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // ── Note ─────────────────────────────────────────────────────
            const _Label('Catatan Perubahan'),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Masukkan keterangan...',
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),

            const SizedBox(height: 20),

            // ── Assigned/Deferred: Departemen, Tag PJA, Keterangan ───────
            // ── Assigned/Deferred: Tagging ───────
            if (_selectedSub == ReportSubStatus.assigned ||
                _selectedSub == ReportSubStatus.deferred) ...[
              const _Label('Tag Departemen / PJA'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showUnifiedPicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
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
                                  onDeleted: () => setState(
                                      () => _selectedDepts.remove(dept)),
                                  backgroundColor: const Color(0xFF1A56C4)
                                      .withValues(alpha: 0.1),
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
                                  backgroundColor: const Color(0xFF1A56C4)
                                      .withValues(alpha: 0.1),
                                  side: BorderSide.none,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                )),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _Label('Keterangan Laporan'),
              const SizedBox(height: 8),
              TextField(
                controller: _deferredKeteranganCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Masukkan keterangan laporan...',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Photo ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Label('Bukti Foto'),
                if (_selectedSub == ReportSubStatus.reviewing)
                  const Text('* Wajib di tahap Reviewing',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.camera_alt_outlined,
                              color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _attachedPhoto != null
                                  ? _attachedPhoto!.name
                                  : 'Pilih / Ambil Foto...',
                              style: TextStyle(
                                  color: _attachedPhoto != null
                                      ? Colors.black87
                                      : Colors.grey,
                                  fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_attachedPhoto != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _attachedPhoto = null),
                              child: const Icon(Icons.close,
                                  size: 18, color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_attachedPhoto != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            appBar: AppBar(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                iconTheme:
                                    const IconThemeData(color: Colors.white)),
                            body: Center(
                              child: InteractiveViewer(
                                child: kIsWeb
                                    ? Image.network(_attachedPhoto!.path)
                                    : Image.file(File(_attachedPhoto!.path)),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(_attachedPhoto!.path,
                              width: 48, height: 48, fit: BoxFit.cover)
                          : Image.file(File(_attachedPhoto!.path),
                              width: 48, height: 48, fit: BoxFit.cover),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 40),

            // ── Save Button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56C4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Simpan Perubahan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54));
  }
}
