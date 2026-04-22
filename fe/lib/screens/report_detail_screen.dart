import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/report.dart';
import '../data/report_store.dart';
import '../services/report_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Report _report;
  late Future<List<TimelineEvent>> _timelineFuture;

  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);

  @override
  void initState() {
    super.initState();
    _report = ReportStore.instance.getById(widget.report.id) ?? widget.report;
    _timelineFuture = ReportStore.instance.loadTimeline(_report.id);
  }

  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
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
        ReportStatus.open => const Color(0xFF2196F3),
        ReportStatus.inProgress => const Color(0xFF9C27B0),
        ReportStatus.closed => const Color(0xFF757575),
      };

  IconData _statusIcon(ReportStatus s) => switch (s) {
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

  @override
  Widget build(BuildContext context) {
    final List<String> images = [_report.imageUrl];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
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
      ),
      body: SingleChildScrollView(
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
                    _badge(_report.status.label, _statusColor(_report.status)),
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
                      child: Text('${_currentImageIndex + 1}/${images.length}',
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

            // ── Info card (Detail Lanjutan) ────────────────────────────────
            _card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                      icon: Icons.category_outlined,
                      label: 'Kategori',
                      value: _report.category?.label ?? _report.type.label),
                  if (_report.subkategori != null &&
                      _report.subkategori!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.subdirectory_arrow_right,
                        label: 'Subkategori',
                        value: _report.subkategori!),
                  ],
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Lokasi Kejadian',
                      value: _report.location),
                  if (_report.departemen != null &&
                      _report.departemen!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.apartment_outlined,
                        label: 'Departemen',
                        value: _report.departemen!),
                  ],
                  if (_report.tagOrang != null &&
                      _report.tagOrang!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.manage_accounts_outlined,
                        label: 'PJA (Penanggung Jawab Area)',
                        value: _report.tagOrang!),
                  ],
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Dilaporkan oleh',
                      value: _report.reportedBy),
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.access_time,
                      label: 'Waktu Laporan',
                      value: _formatDate(_report.createdAt)),
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
                      if (snapshot.connectionState == ConnectionState.waiting &&
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<Report>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UpdateStatusPage(report: _report)),
                    );
                    if (result != null) {
                      setState(() {
                        _report = result;
                        _timelineFuture =
                            ReportStore.instance.loadTimeline(_report.id);
                      });
                    }
                  },
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

// ── Detail row ────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ]),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// UPDATE STATUS PAGE (FULLSCREEN)
// ══════════════════════════════════════════════════════════════════════════════
class UpdateStatusPage extends StatefulWidget {
  final Report report;
  const UpdateStatusPage({super.key, required this.report});

  @override
  State<UpdateStatusPage> createState() => _UpdateStatusPageState();
}

class _UpdateStatusPageState extends State<UpdateStatusPage> {
  late ReportStatus _selectedStatus;
  ReportSubStatus? _selectedSub;
  final _noteCtrl = TextEditingController();
  final _deferredKeteranganCtrl = TextEditingController();

  // User tagging — single selection (API takes one taggedUserId)
  UserEntry? _selectedUser;

  // Departments fetched from API
  List<String> _departments = [];
  String? _selectedDepartment;

  XFile? _attachedPhoto;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _selectedSub = widget.report.subStatus;
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

  void _showTagPeopleSheet() {
    String query = '';
    List<UserEntry> users = [];
    bool isLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Load users on first open
          if (isLoading) {
            ReportService.getUsers(search: query.isEmpty ? null : query)
                .then((result) {
              setSheetState(() {
                users = result;
                isLoading = false;
              });
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                const SizedBox(height: 12),
                const Text('Pilih PJA',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    onChanged: (val) {
                      setSheetState(() {
                        query = val;
                        isLoading = true;
                      });
                      ReportService.getUsers(search: val.isEmpty ? null : val)
                          .then((result) {
                        setSheetState(() {
                          users = result;
                          isLoading = false;
                        });
                      });
                    },
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : users.isEmpty
                          ? const Center(
                              child: Text('Tidak ada pengguna ditemukan.',
                                  style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (_, i) {
                                final user = users[i];
                                final isSelected = _selectedUser?.id == user.id;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFEFF4FF),
                                    child: Text(
                                      user.fullName.isNotEmpty
                                          ? user.fullName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Color(0xFF1A56C4),
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(user.fullName,
                                      style: const TextStyle(fontSize: 14)),
                                  subtitle: user.department != null
                                      ? Text(user.department!,
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey))
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Color(0xFF1A56C4))
                                      : const Icon(Icons.radio_button_unchecked,
                                          color: Colors.grey),
                                  onTap: () {
                                    setState(() => _selectedUser =
                                        isSelected ? null : user);
                                    setSheetState(() {});
                                  },
                                );
                              },
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56C4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _selectedUser == null
                            ? 'Tutup'
                            : 'Selesai (${_selectedUser!.fullName})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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

      if (_selectedSub == ReportSubStatus.assigned ||
          _selectedSub == ReportSubStatus.deferred) {
        final dept = _selectedDepartment == null
            ? ''
            : 'Departemen: $_selectedDepartment';
        final pjaTag =
            _selectedUser == null ? '' : 'PJA: ${_selectedUser!.fullName}';
        final ket = _deferredKeteranganCtrl.text.trim().isEmpty
            ? ''
            : 'Keterangan: ${_deferredKeteranganCtrl.text.trim()}';
        final addInfo =
            [dept, pjaTag, ket].where((s) => s.isNotEmpty).join('\n');
        if (addInfo.isNotEmpty) {
          finalNote = finalNote == null ? addInfo : '$finalNote\n\n$addInfo';
        }
      }

      final updated = await ReportStore.instance.updateStatus(
        widget.report.id,
        _selectedStatus,
        newSubStatus: _selectedSub,
        note: finalNote,
        photoPath: _attachedPhoto?.path,
        taggedUserId: _selectedUser?.id,
      );

      if (mounted) {
        Navigator.pop(context, updated);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Status berhasil diperbarui ke ${_selectedStatus.label}'),
          backgroundColor: _statusColor(_selectedStatus),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
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
              final color = _statusColor(s);
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedStatus = s;
                  _selectedSub = null;
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color: isSelected ? color : Colors.grey.shade300,
                        width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: color),
                      const SizedBox(width: 12),
                      Text(s.label,
                          style: TextStyle(
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
                final color = _statusColor(_selectedStatus);
                return GestureDetector(
                  onTap: () => setState(() => _selectedSub = sub),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSubSelected
                          ? color.withValues(alpha: 0.1)
                          : Colors.white,
                      border: Border.all(
                          color: isSubSelected ? color : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(sub.label,
                            style: TextStyle(
                                color: isSubSelected ? color : Colors.black87,
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
            if (_selectedSub == ReportSubStatus.assigned ||
                _selectedSub == ReportSubStatus.deferred) ...[
              const _Label('Departemen'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _departments.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                            child: SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDepartment,
                          isExpanded: true,
                          hint: const Text('Pilih departemen...',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14)),
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.grey),
                          items: _departments
                              .map((d) =>
                                  DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedDepartment = val),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              const _Label('Tag PJA'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedUser != null) ...[
                      Chip(
                        label: Text(_selectedUser!.fullName,
                            style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => setState(() => _selectedUser = null),
                        backgroundColor: const Color(0xFFEFF4FF),
                        side: const BorderSide(color: Color(0xFF1A56C4)),
                        labelStyle: const TextStyle(color: Color(0xFF1A56C4)),
                        deleteIconColor: const Color(0xFF1A56C4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      const SizedBox(height: 8),
                    ],
                    GestureDetector(
                      onTap: () => _showTagPeopleSheet(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.person_add_outlined,
                                size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('Cari dan pilih PJA...',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
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
