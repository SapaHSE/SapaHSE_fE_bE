import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/report.dart';
import '../data/report_store.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Report _report;
  bool _isTimelineLoading = true;

  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);

  @override
  void initState() {
    super.initState();
    _report = ReportStore.instance.getById(widget.report.id) ?? widget.report;
    _loadTimeline(force: true);
  }

  Future<void> _loadTimeline({bool force = false}) async {
    try {
      await ReportStore.instance.loadTimeline(_report.id, force: force);
    } finally {
      if (mounted) {
        setState(() => _isTimelineLoading = false);
      }
    }
  }

  // ── Colors ─────────────────────────────────────────────────────────────────
  Color _severityColor(ReportSeverity s) => switch (s) {
        ReportSeverity.low => const Color(0xFF4CAF50),
        ReportSeverity.medium => const Color(0xFFFF9800),
        ReportSeverity.high => const Color(0xFFF44336),
        ReportSeverity.critical => const Color(0xFF880E4F),
      };

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.open => const Color(0xFF2196F3), // Biru
        ReportStatus.inProgress => const Color(0xFF9C27B0), // Ungu
        ReportStatus.closed => const Color(0xFF757575), // Abu
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

  // ── Update Status logic replaced by UpdateStatusPage ───────────────────────

  // ── Image Preview ──────────────────────────────────────────────────────────
  void _showImagePreview(BuildContext context) {
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
              child: Hero(
                tag: 'report_image_${_report.id}',
                child: CachedNetworkImage(
                  imageUrl: _report.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.image, color: Colors.white54, size: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ReportStore.instance.getTimeline(_report.id);

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
                GestureDetector(
                  onTap: () => _showImagePreview(context),
                  child: Hero(
                    tag: 'report_image_${_report.id}',
                    child: CachedNetworkImage(
                      imageUrl: _report.imageUrl,
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
                  ),
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
                    _badge(_report.severity.label,
                        _severityColor(_report.severity)),
                    const SizedBox(width: 8),
                    _badge(_report.status.label, _statusColor(_report.status)),
                  ]),
                ),
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
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Lokasi',
                        value: _report.location),
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
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Kategori',
                        value: _report.category?.label ?? _report.type.label),
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.confirmation_number_outlined,
                        label: 'No. Tiket',
                        value: '#TKT-${_report.id.padLeft(4, '0')}'),
                  ]),
            ),

            // ── Progress Timeline ──────────────────────────────────────────
            _card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${timeline.length} aktivitas',
                            style: const TextStyle(
                                fontSize: 11,
                                color: _blue,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 6),

                    // Step indicator bar
                    _buildStepBar(),

                    const SizedBox(height: 20),

                    // Timeline events (grouped by parent status)
                    if (_isTimelineLoading && timeline.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            color: Color(0xFF1A56C4),
                          ),
                        ),
                      )
                    else
                      ..._buildGroupedTimeline(timeline),
                  ]),
            ),

            // ── Action buttons ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<Report>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpdateStatusPage(report: _report),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _report = result;
                        _isTimelineLoading = true;
                      });
                      await _loadTimeline(force: true);
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

      // Group header
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

      // Sub-events under this group
      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final isLastInGroup = i == events.length - 1;
        final isVeryLast = status == (_report.status) && isLastInGroup;

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
  Widget _buildStepBar() {
    final steps = [
      ReportStatus.open,
      ReportStatus.inProgress,
      ReportStatus.closed
    ];
    final timeline = ReportStore.instance.getTimeline(_report.id);
    final reached = timeline.map((e) => e.status).toSet();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
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
        // Step circle
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
                  width: isCur ? 3 : 1.5,
                ),
                boxShadow: isCur
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: Icon(
                _statusIcon(step),
                size: 16,
                color: isDone ? Colors.white : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              step.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                color: isDone ? color : Colors.grey,
              ),
            ),
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
                // Dot
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
                      color: statusColor,
                      width: isCurrent ? 2.5 : 1.5,
                    ),
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
                // Vertical line
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
                  // Photo
                  if (event.photoPath != null) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      final path = event.photoPath!;
                      final isNetwork =
                          path.startsWith('http://') || path.startsWith('https://');
                      return GestureDetector(
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
                                    child: (kIsWeb || isNetwork)
                                        ? Image.network(path, fit: BoxFit.contain)
                                        : Image.file(
                                            File(path),
                                            fit: BoxFit.contain,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 140,
                            width: double.infinity,
                            child: (kIsWeb || isNetwork)
                                ? Image.network(path, fit: BoxFit.cover)
                                : Image.file(File(path), fit: BoxFit.cover),
                          ),
                        ),
                      );
                    }),
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
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

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

// ── Data orang yang bisa di-tag ────────────────────────────────────────────
const _allPeople = [
  'Budi Santoso',
  'Ahmad Fauzi',
  'Riko Pratama',
  'Hendra Wijaya',
  'Siti Rahayu',
  'Dian Permata',
  'Eko Susilo',
  'Novi Andriani',
  'Wahyu Hidayat',
  'Agus Setiawan',
  'Bambang Purnomo',
  'Lintang Bhaskara',
  'Maya Putri',
  'Reza Firmansyah',
  'Dewi Kusuma',
  'Rizki Fauzan',
  'Rina Marlina',
  'Kevin Alfarisi',
  'Deni Setiawan',
  'Putri Wulandari',
  'Faisal Rahman',
  'Guntur Prabowo',
  'Yuli Astuti',
];

class _UpdateStatusPageState extends State<UpdateStatusPage> {
  late ReportStatus _selectedStatus;
  ReportSubStatus? _selectedSub;
  final _noteCtrl = TextEditingController();
  final _deferredKeteranganCtrl = TextEditingController();
  final Set<String> _taggedPeople = {};
  XFile? _attachedPhoto;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _selectedSub = widget.report.subStatus;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _deferredKeteranganCtrl.dispose();
    super.dispose();
  }

  // Sequential logic: Open -> InProgress -> Closed
  List<ReportStatus> get _allowedStatuses {
    return ReportStatus.values;
  }

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.open => const Color(0xFF2196F3),
        ReportStatus.inProgress => const Color(0xFF9C27B0),
        ReportStatus.closed => const Color(0xFF757575),
      };

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() => _attachedPhoto = picked);
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

  void _showTagPeopleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Pilih Orang',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _allPeople.length,
                  itemBuilder: (_, i) {
                    final person = _allPeople[i];
                    final isTagged = _taggedPeople.contains(person);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEFF4FF),
                        child: Text(
                          person[0],
                          style: const TextStyle(
                              color: Color(0xFF1A56C4),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(person, style: const TextStyle(fontSize: 14)),
                      trailing: isTagged
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF1A56C4))
                          : const Icon(Icons.radio_button_unchecked,
                              color: Colors.grey),
                      onTap: () {
                        setState(() {
                          if (isTagged) {
                            _taggedPeople.remove(person);
                          } else {
                            _taggedPeople.add(person);
                          }
                        });
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
                      _taggedPeople.isEmpty
                          ? 'Tutup'
                          : 'Selesai (${_taggedPeople.length} dipilih)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _handleSave() async {
    final needsPhoto = _selectedSub == ReportSubStatus.reviewing ||
        _selectedSub == ReportSubStatus.executing;
    if (needsPhoto && _attachedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Foto bukti wajib dilampirkan untuk tahap Executing/Reviewing!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final note = [
        _noteCtrl.text.trim(),
        if (_selectedSub == ReportSubStatus.deferred)
          _deferredKeteranganCtrl.text.trim(),
      ].where((e) => e.isNotEmpty).join('\n\n');

      final updated = await ReportStore.instance.updateStatus(
        widget.report.id,
        _selectedStatus,
        newSubStatus: _selectedSub,
        note: note.isEmpty ? null : note,
        photoPath: _attachedPhoto?.path,
      );

      if (!mounted) return;
      Navigator.pop(context, updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status berhasil diperbarui ke ${_selectedStatus.label}'),
        backgroundColor: _statusColor(_selectedStatus),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

            // ── Sub Status List (Vertical) ───────────────────────────────
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
                                  : FontWeight.normal,
                            )),
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

            // ── Deferred: Tag Orang & Keterangan ─────────────────────────
            if (_selectedSub == ReportSubStatus.deferred) ...[
              const _Label('Tag Orang'),
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
                    if (_taggedPeople.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _taggedPeople
                            .map((p) => Chip(
                                  label: Text(p,
                                      style: const TextStyle(fontSize: 12)),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () =>
                                      setState(() => _taggedPeople.remove(p)),
                                  backgroundColor: const Color(0xFFEFF4FF),
                                  side: const BorderSide(
                                      color: Color(0xFF1A56C4)),
                                  labelStyle:
                                      const TextStyle(color: Color(0xFF1A56C4)),
                                  deleteIconColor: const Color(0xFF1A56C4),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                ))
                            .toList(),
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
                            Text('Tambah orang...',
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
                  hintText: 'Masukkan keterangan laporan yang ditangguhkan...',
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
            GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: _attachedPhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(_attachedPhoto!.path,
                                fit: BoxFit.cover)
                            : Image.file(File(_attachedPhoto!.path),
                                fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: Colors.grey, size: 40),
                          SizedBox(height: 8),
                          Text('Klik untuk ambil foto (Kamera/Galeri)',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
              ),
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
