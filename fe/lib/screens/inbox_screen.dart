import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/dummy_data.dart';
import '../models/report.dart';
import 'report_detail_screen.dart';
import '../widgets/sapa_hse_header.dart';

// ── Dummy announcements ───────────────────────────────────────────────────────
class Announcement {
  final String id;
  final String title;
  final String body;
  final String from;
  final DateTime createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.from,
    required this.createdAt,
  });
}

final List<Announcement> dummyAnnouncements = [
  Announcement(
    id: 'a1',
    title: 'Pelatihan K3 Wajib Maret 2026',
    body:
        'Seluruh karyawan diwajibkan mengikuti pelatihan K3 pada tanggal 28 Maret 2026 pukul 08.00 di Aula Utama. Kehadiran bersifat wajib.',
    from: 'Admin HSE',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  Announcement(
    id: 'a2',
    title: 'Inspeksi Rutin Area Tambang',
    body:
        'Akan dilaksanakan inspeksi rutin menyeluruh di seluruh area tambang pada minggu ini. Harap semua peralatan dalam kondisi siap periksa.',
    from: 'Supervisor K3',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Announcement(
    id: 'a3',
    title: 'Update SOP Penanganan Bahan B3',
    body:
        'SOP penanganan limbah B3 telah diperbarui sesuai regulasi KLHK terbaru. Silakan unduh dokumen terbaru di portal internal perusahaan.',
    from: 'Admin HSE',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Announcement(
    id: 'a4',
    title: 'Jadwal Pemeriksaan APAR Bulanan',
    body:
        'Pemeriksaan APAR bulanan akan dilaksanakan pada 30 Maret 2026. Pastikan semua unit APAR di area tanggung jawab Anda dalam kondisi baik.',
    from: 'Tim HSE',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
  ),
];

enum _SubFilter { unread, read }

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  _SubFilter _activeFilter = _SubFilter.unread;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        setState(() {
          _activeFilter = _SubFilter.unread; // Reset filter when switching tabs
        });
      }
    });
  }

  // Track read IDs (in-memory)
  final Set<String> _readReportIds = {};
  final Set<String> _readAnnouncementIds = {};

  // ── Filtered reports ───────────────────────────────────────────────────────
  List<Report> get _baseReports {
    if (_activeFilter == _SubFilter.unread) {
      return dummyReports.where((r) => !_readReportIds.contains(r.id)).toList();
    }
    return dummyReports.where((r) => _readReportIds.contains(r.id)).toList();
  }

  List<Report> get _activeReports {
    final base = _baseReports;
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.reportedBy.toLowerCase().contains(q) ||
            r.location.toLowerCase().contains(q))
        .toList();
  }

  // ── Filtered announcements ─────────────────────────────────────────────────
  List<Announcement> get _baseAnnouncements {
    if (_activeFilter == _SubFilter.unread) {
      return dummyAnnouncements
          .where((a) => !_readAnnouncementIds.contains(a.id))
          .toList();
    }
    return dummyAnnouncements
        .where((a) => _readAnnouncementIds.contains(a.id))
        .toList();
  }

  List<Announcement> get _activeAnnouncements {
    final base = _baseAnnouncements;
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base
        .where((a) =>
            a.title.toLowerCase().contains(q) ||
            a.body.toLowerCase().contains(q) ||
            a.from.toLowerCase().contains(q))
        .toList();
  }

  // ── Badge counts ───────────────────────────────────────────────────────────
  int get _unreadReportCount =>
      dummyReports.where((r) => !_readReportIds.contains(r.id)).length;

  int get _unreadAnnouncementCount => dummyAnnouncements
      .where((a) => !_readAnnouncementIds.contains(a.id))
      .length;

  int get _readReportCount => _readReportIds.length;
  int get _readAnnouncementCount => _readAnnouncementIds.length;

  @override
  void dispose() {
    _searchController.dispose();
    _mainTabController.dispose();
    super.dispose();
  }

  void _markReportRead(String id) {
    if (!_readReportIds.contains(id)) {
      setState(() => _readReportIds.add(id));
    }
  }

  void _markAnnouncementRead(String id) {
    if (!_readAnnouncementIds.contains(id)) {
      setState(() => _readAnnouncementIds.add(id));
    }
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
      'Des',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _levelResiko(ReportSeverity s) {
    switch (s) {
      case ReportSeverity.low:
        return 'P3 - Low';
      case ReportSeverity.medium:
        return 'P2 - Medium';
      case ReportSeverity.high:
        return 'P1 - High';
      case ReportSeverity.critical:
        return 'P0 - Critical';
    }
  }

  Color _statusColor(ReportStatus s) {
    switch (s) {
      case ReportStatus.open:
        return const Color(0xFF2196F3); // Biru
      case ReportStatus.inProgress:
        return const Color(0xFF9C27B0); // Ungu
      case ReportStatus.closed:
        return const Color(0xFF757575); // Abu
    }
  }

  Color _severityColor(ReportSeverity s) {
    switch (s) {
      case ReportSeverity.low:
        return const Color(0xFF4CAF50); // Green
      case ReportSeverity.medium:
        return const Color(0xFFFF9800); // Orange
      case ReportSeverity.high:
        return const Color(0xFFF44336); // Red
      case ReportSeverity.critical:
        return const Color(0xFFB71C1C); // Dark Red
    }
  }

  String _statusLabel(ReportStatus s) {
    switch (s) {
      case ReportStatus.open:
        return 'Open';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.closed:
        return 'Closed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        child: Column(
          children: [
            // ── Custom Header matching Profile design (Unified Container) ────
            Container(
              color: const Color(0xFFF8F8F8),
              child: Column(
                children: [
                  SapaHseHeader(
                    isSearching: _isSearching,
                    searchController: _searchController,
                    searchHint: 'Cari...',
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                    onSearchToggle: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                  ),
                  TabBar(
                    controller: _mainTabController,
                    labelColor: const Color(0xFF1565C0),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xFF1565C0),
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 14),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Personal'),
                            if (_unreadReportCount > 0) ...[
                              const SizedBox(width: 6),
                              _TabBadge(count: _unreadReportCount),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Announcement'),
                            if (_unreadAnnouncementCount > 0) ...[
                              const SizedBox(width: 6),
                              _TabBadge(count: _unreadAnnouncementCount),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Sub-filter: Unread | Read ──────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _SubFilterChip(
                      label: 'Unread',
                      isActive: _activeFilter == _SubFilter.unread,
                      badge: _mainTabController.index == 0
                          ? (_unreadReportCount > 0 ? _unreadReportCount : null)
                          : (_unreadAnnouncementCount > 0
                              ? _unreadAnnouncementCount
                              : null),
                      onTap: () =>
                          setState(() => _activeFilter = _SubFilter.unread),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SubFilterChip(
                      label: 'Read',
                      isActive: _activeFilter == _SubFilter.read,
                      badge: _mainTabController.index == 0
                          ? (_readReportCount > 0 ? _readReportCount : null)
                          : (_readAnnouncementCount > 0
                              ? _readAnnouncementCount
                              : null),
                      onTap: () =>
                          setState(() => _activeFilter = _SubFilter.read),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content (TabBarView for smooth animations) ───────────────
            Expanded(
              child: TabBarView(
                controller: _mainTabController,
                children: [
                  _buildListTab(false),
                  _buildListTab(true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab(bool isAnnouncement) {
    final list = isAnnouncement ? _activeAnnouncements : _activeReports;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _activeFilter == _SubFilter.unread
                  ? Icons.mark_email_read_outlined
                  : Icons.drafts_outlined,
              size: 52,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _activeFilter == _SubFilter.unread
                  ? 'Semua sudah dibaca!'
                  : 'Belum ada yang dibaca.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, i) {
        if (isAnnouncement) {
          final ann = list[i] as Announcement;
          return _AnnouncementCard(
            announcement: ann,
            isRead: _readAnnouncementIds.contains(ann.id),
            formatDate: _formatDate,
            onTap: () {
              _markAnnouncementRead(ann.id);
              _showAnnouncementDetail(context, ann);
            },
          );
        } else {
          final r = list[i] as Report;
          return _InboxCard(
            report: r,
            isRead: _readReportIds.contains(r.id),
            formatDate: _formatDate,
            levelResiko: _levelResiko,
            statusColor: _statusColor,
            statusLabel: _statusLabel,
            severityColor: _severityColor,
            onDetail: () {
              _markReportRead(r.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ReportDetailScreen(report: r)),
              );
            },
          );
        }
      },
    );
  }

  void _showAnnouncementDetail(BuildContext context, Announcement ann) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: sc,
                  children: [
                    // Icon
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1A56C4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.campaign,
                              color: Color(0xFF1A56C4), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ann.from,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF1A56C4))),
                              Text(_formatDate(ann.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(ann.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            height: 1.3)),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(ann.body,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87, height: 1.6)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TAB BADGE Widget ─────────────────────────────────────────────────────────
class _TabBadge extends StatelessWidget {
  final int count;
  const _TabBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── SUB FILTER CHIP (All | Unread) ─────────────────────────────────────────────
class _SubFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const _SubFilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1A56C4);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? blue.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? blue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? blue : Colors.black54,
              ),
            ),
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? blue : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── INBOX CARD (Report) ───────────────────────────────────────────────────────
class _InboxCard extends StatelessWidget {
  final Report report;
  final bool isRead;
  final String Function(DateTime) formatDate;
  final String Function(ReportSeverity) levelResiko;
  final Color Function(ReportStatus) statusColor;
  final String Function(ReportStatus) statusLabel;
  final Color Function(ReportSeverity) severityColor;
  final VoidCallback onDetail;

  const _InboxCard({
    required this.report,
    required this.isRead,
    required this.formatDate,
    required this.levelResiko,
    required this.statusColor,
    required this.statusLabel,
    required this.severityColor,
    required this.onDetail,
  });

  Color get _typeColor {
    switch (report.type) {
      case ReportType.hazard:
        return const Color(0xFFF44336);
      case ReportType.inspection:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDetail,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : const Color(0xFF1A56C4).withValues(alpha: 0.3),
            width: 1,
          ),
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.bold,
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
                                Text(formatDate(report.createdAt),
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
                            const SizedBox(height: 10),

                            // Status & Priority
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor(report.status)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: statusColor(report.status)
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    statusLabel(report.status),
                                    style: TextStyle(
                                        color: statusColor(report.status),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: severityColor(report.severity),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    levelResiko(report.severity),
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

              // ── BOTTOM: Warning Banner if Open ───────────────────────────
              if (report.status == ReportStatus.open)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    border:
                        Border(top: BorderSide(color: Colors.orange.shade100)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.orange.shade900),
                      const SizedBox(width: 8),
                      Text(
                        'BUTUH TINDAKAN SEGERA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
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

// ── ANNOUNCEMENT CARD ─────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool isRead;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.announcement,
    required this.isRead,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFFFAFAFA) : const Color(0xFFF0F8FF),
          borderRadius: BorderRadius.circular(14),
          border: isRead
              ? null
              : Border.all(
                  color: const Color(0xFF1A56C4).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            children: [
              if (!isRead)
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A56C4),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56C4).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign,
                          color: Color(0xFF1A56C4), size: 22),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!isRead)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin:
                                      const EdgeInsets.only(right: 6, top: 2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A56C4),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  announcement.title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            announcement.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(formatDate(announcement.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 12),
                              const Icon(Icons.person_outline,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(announcement.from,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
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

// ── DETAIL ROW ────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90, // Menyamakan ukuran label agar rapi
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 13, color: Colors.black54)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}