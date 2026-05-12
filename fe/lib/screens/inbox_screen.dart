import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inbox_item.dart';
import '../models/report.dart';
import '../services/inbox_service.dart';
import '../services/report_service.dart';
import 'report_detail_screen.dart';
import '../widgets/sapa_hse_header.dart';
import '../widgets/minimal_dropdown.dart';
import '../services/storage_service.dart';
import '../services/cloud_save_service.dart';

class _FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget Function(BuildContext) builder;
  _FadePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
}

enum _SubFilter { unread, read }
enum _MyPostFilter { all, draft, validating, approved, rejected }
enum _TaskStatusFilter {
  all,
  validating,
  approved,
  assigned,
  preparing,
  executing,
  reviewing,
  resolved,
  rejected,
  deferred
}

extension _TaskStatusFilterX on _TaskStatusFilter {
  ReportSubStatus? get subStatus {
    switch (this) {
      case _TaskStatusFilter.all:
        return null;
      case _TaskStatusFilter.validating:
        return ReportSubStatus.validating;
      case _TaskStatusFilter.approved:
        return ReportSubStatus.approved;
      case _TaskStatusFilter.assigned:
        return ReportSubStatus.assigned;
      case _TaskStatusFilter.preparing:
        return ReportSubStatus.preparing;
      case _TaskStatusFilter.executing:
        return ReportSubStatus.executing;
      case _TaskStatusFilter.reviewing:
        return ReportSubStatus.reviewing;
      case _TaskStatusFilter.resolved:
        return ReportSubStatus.resolved;
      case _TaskStatusFilter.rejected:
        return ReportSubStatus.rejected;
      case _TaskStatusFilter.deferred:
        return ReportSubStatus.deferred;
    }
  }

  String get label {
    if (this == _TaskStatusFilter.all) return 'Semua';
    return subStatus!.label;
  }
}

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  _SubFilter _activeFilter = _SubFilter.unread;
  _MyPostFilter _activeMyPostFilter = _MyPostFilter.all;
  _TaskStatusFilter _activeTaskStatusFilter = _TaskStatusFilter.all;
  bool _isUrgentSectionExpanded = true;
  bool _isOtherSectionExpanded = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ── Server-backed state ────────────────────────────────────────────────────
  List<InboxItem> _reports = [];
  List<InboxItem> _announcements = [];
  List<Report> _myRawReports = [];
  List<ReportDraft> _myDrafts = [];
  bool _loadingReports = false;
  bool _loadingAnnouncements = false;
  bool _loadingMyReports = false;
  String? _errorReports;
  String? _errorAnnouncements;
  String? _errorMyReports;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        setState(() {
          _activeFilter = _SubFilter.unread; // Reset filter when switching tabs
        });
      }
    });
    _loadCurrentUser();
    _loadSavedStatusFilter();
    // Fetch both tabs in parallel so badges are accurate from the start.
    _loadReports();
    _loadAnnouncements();
  }

  Future<void> _loadSavedStatusFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('tugas_status_filter');
    if (saved != null && mounted) {
      try {
        _activeTaskStatusFilter = _TaskStatusFilter.values.firstWhere(
          (e) => e.name == saved,
        );
      } catch (_) {
        // Keep default if invalid
      }
    }
  }

  Future<void> _saveTaskStatusFilter(_TaskStatusFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tugas_status_filter', filter.name);
  }

  Future<void> _loadCurrentUser() async {
    final user = await StorageService.getUser();
    if (user != null) {
      setState(() {
        _currentUserId = user['id']?.toString();
      });
      _loadMyReports();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mainTabController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadReports() async {
    setState(() {
      _loadingReports = true;
      _errorReports = null;
    });
    final result = await InboxService.fetchInbox(
      type: 'personal',
      search: _searchQuery.isEmpty ? null : _searchQuery,
      perPage: 100,
    );
    if (!mounted) return;
    setState(() {
      _loadingReports = false;
      if (result.success) {
        _reports = result.items;
      } else {
        _errorReports = result.errorMessage;
      }
    });
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _loadingAnnouncements = true;
      _errorAnnouncements = null;
    });
    final result = await InboxService.fetchInbox(
      type: 'announcement',
      search: _searchQuery.isEmpty ? null : _searchQuery,
      perPage: 100,
    );
    if (!mounted) return;
    setState(() {
      _loadingAnnouncements = false;
      if (result.success) {
        _announcements = result.items;
      } else {
        _errorAnnouncements = result.errorMessage;
      }
    });
  }

  Future<void> _loadMyReports() async {
    if (_currentUserId == null) return;
    setState(() {
      _loadingMyReports = true;
      _errorMyReports = null;
    });

    final results = await Future.wait([
      ReportService.getReports(),
      CloudSaveService.instance.getDrafts(),
    ]);

    final reportResult = results[0] as ReportListResult;
    final drafts = results[1] as List<ReportDraft>;

    if (!mounted) return;
    setState(() {
      _loadingMyReports = false;
      _myDrafts = drafts;
      if (reportResult.success) {
        _myRawReports = reportResult.reports
            .where((r) => r.reporterId == _currentUserId)
            .toList();
      } else {
        _errorMyReports = reportResult.errorMessage;
      }
    });
  }

  InboxItem _reportToInboxItem(Report r) {
    return InboxItem(
      id: r.id,
      itemType: InboxItemType.report,
      isRead: true,
      title: r.title,
      createdAt: r.createdAt,
      reportType: r.type,
      description: r.description,
      status: r.status,
      subStatus: r.subStatus,
      location: r.location,
      imageUrl: r.imageUrl,
      severity: r.severity,
      ticketNumber: r.ticketNumber,
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadReports();
      _loadAnnouncements();
    });
  }

  // ── Filtering (client-side by read/unread + already filtered list) ────────
  List<InboxItem> _filterByReadState(List<InboxItem> source) {
    if (_activeFilter == _SubFilter.unread) {
      return source.where((i) => !i.isRead).toList();
    }
    return source.where((i) => i.isRead).toList();
  }

  // Reports where user is tagged (inbox tasks assigned to the user)
  List<InboxItem> get _personalReports => _reports;

  // Filtered reports by status with sorting
  List<InboxItem> get _filteredReports {
    var list = _personalReports;

    final targetSubStatus = _activeTaskStatusFilter.subStatus;
    if (targetSubStatus != null) {
      list = list.where((i) => i.subStatus == targetSubStatus).toList();
    } else {
      list = list.toList();
    }

    // Apply sorting
    list.sort((a, b) {
      // Closed items always sink to the bottom, regardless of deadline/severity.
      final closedA = a.status == ReportStatus.closed;
      final closedB = b.status == ReportStatus.closed;
      if (closedA != closedB) {
        return closedA ? 1 : -1;
      }

      final validatingA = _isValidating(a);
      final validatingB = _isValidating(b);
      if (validatingA != validatingB) {
        return validatingB ? 1 : -1;
      }

      final urgentA = _needsImmediateAction(a);
      final urgentB = _needsImmediateAction(b);
      if (urgentA != urgentB) {
        return urgentB ? 1 : -1;
      }

      final remainA = _remainingMinutesRank(a);
      final remainB = _remainingMinutesRank(b);
      if (remainA != remainB) {
        return remainA.compareTo(remainB);
      }

      final sevA = _severityValue(a.severity);
      final sevB = _severityValue(b.severity);
      if (sevA != sevB) {
        return sevB.compareTo(sevA);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return list;
  }

  List<InboxItem> get _urgentTaskReports => _filteredReports
      .where((i) => i.status != ReportStatus.closed && _needsImmediateAction(i))
      .toList();

  List<InboxItem> get _otherTaskReports => _filteredReports
      .where((i) =>
          !(i.status != ReportStatus.closed && _needsImmediateAction(i)))
      .toList();

  // Reports created by the current user, fetched from ReportService
  List<InboxItem> get _myReports =>
      _myRawReports.map(_reportToInboxItem).toList();

  int _severityValue(ReportSeverity? s) {
    if (s == null) return 0;
    switch (s) {
      case ReportSeverity.critical:
        return 4;
      case ReportSeverity.high:
        return 3;
      case ReportSeverity.medium:
        return 2;
      case ReportSeverity.low:
        return 1;
    }
  }

  Duration? _remainingDuration(InboxItem item) {
    final due = item.dueDate;
    if (due == null) return null;
    return due.difference(DateTime.now());
  }

  bool _isValidating(InboxItem item) =>
      item.subStatus == ReportSubStatus.validating;

  bool _needsImmediateAction(InboxItem item) {
    if (item.status == ReportStatus.closed) return false;
    final remaining = _remainingDuration(item);
    final nearDeadline =
        remaining != null && remaining <= const Duration(hours: 24);
    final highSeverity = item.severity == ReportSeverity.high ||
        item.severity == ReportSeverity.critical;
    return nearDeadline || highSeverity;
  }

  int _remainingMinutesRank(InboxItem item) {
    final remaining = _remainingDuration(item);
    if (remaining == null) return 1 << 30;
    return remaining.inMinutes;
  }

  List<InboxItem> get _activeAnnouncements =>
      _filterByReadState(_announcements);
      
  List<InboxItem> get _activeMyReports {
    final drafts = _myDrafts.map((d) => InboxItem(
          id: d.id,
          itemType: InboxItemType.report,
          isRead: true,
          title: '[DRAFT] ${d.title}',
          createdAt: d.createdAt,
          reportType: d.type == DraftType.hazard ? ReportType.hazard : ReportType.inspection,
          description: d.data['description']?.toString() ?? d.data['kronologi']?.toString() ?? '',
          status: ReportStatus.open, // Placeholder for draft
          subStatus: null,
          location: d.data['location']?.toString() ?? '-',
          severity: _parseSeverity(d.data['severity']),
        )).toList();

    switch (_activeMyPostFilter) {
      case _MyPostFilter.all:
        final all = [...drafts, ..._myReports];
        all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return all;
      case _MyPostFilter.draft:
        return drafts;
      case _MyPostFilter.validating:
        return _myReports.where((i) => i.subStatus == ReportSubStatus.validating).toList();
      case _MyPostFilter.approved:
        return _myReports.where((i) =>
          i.subStatus != ReportSubStatus.validating &&
          i.subStatus != ReportSubStatus.rejected &&
          i.status != ReportStatus.closed
        ).toList();
      case _MyPostFilter.rejected:
        return _myReports.where((i) => i.status == ReportStatus.closed).toList();
    }
  }

  ReportSeverity _parseSeverity(dynamic raw) {
    final s = raw?.toString().toLowerCase();
    if (s == 'low') return ReportSeverity.low;
    if (s == 'high') return ReportSeverity.high;
    if (s == 'critical') return ReportSeverity.critical;
    return ReportSeverity.medium;
  }

  String _getEmptyStateMessage() {
    if (_mainTabController.index == 2) {
      return 'Tidak ada laporan dengan status ini.';
    }
     if (_mainTabController.index == 1) {
       if (_activeTaskStatusFilter == _TaskStatusFilter.all) {
         return _activeFilter == _SubFilter.unread
           ? 'Tidak ada tugas aktif!'
           : 'Tidak ada tugas selesai.';
       }
       return 'Tidak ada tugas ${_activeTaskStatusFilter.label}.';
     }
    // Pengumuman
    return _activeFilter == _SubFilter.unread
      ? 'Semua sudah dibaca!'
      : 'Belum ada yang dibaca.';
  }

  int get _readAnnouncementCount =>
      _announcements.where((i) => i.isRead).length;

  int get _unreadReports => _personalReports.where((i) => !i.isRead).length;
  int get _unreadAnnouncements => _announcements.where((i) => !i.isRead).length;
  int get _unreadMyReports => _myReports.where((i) => !i.isRead).length;

  // ── Mark-as-read (optimistic) ──────────────────────────────────────────────
  void _markItemRead(InboxItem item) {
    if (item.isRead) return;
    setState(() {
      item.isRead = true;
      // No manual count adjustment; counts are computed from lists.
    });

    // Fire-and-forget — rollback if it fails.
    final typeStr =
        item.itemType == InboxItemType.report ? 'report' : 'announcement';
    InboxService.markRead(itemId: item.id, itemType: typeStr).then((res) {
      if (!mounted) return;
      if (!res.success) {
        setState(() {
          item.isRead = false;
          // No manual count adjustment; counts are computed from lists.
        });
      }
    });
  }

  // ── Formatters & colors ────────────────────────────────────────────────────
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

  // Row used inside MinimalDropdown menu items: label left, muted count right.
  Widget _countRow(String label, int count) {
    return Row(
      children: [
        Expanded(child: Text(label, style: kMinimalDropdownTextStyle)),
        Text('$count', style: kMinimalDropdownCountStyle),
      ],
    );
  }

String _myPostFilterLabel(_MyPostFilter f) {
  switch (f) {
    case _MyPostFilter.all: return 'Semua';
    case _MyPostFilter.draft: return 'Draft';
    case _MyPostFilter.validating: return 'Validating';
    case _MyPostFilter.approved: return 'Approved';
    case _MyPostFilter.rejected: return 'Closed';
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
                    onSearchChanged: _onSearchChanged,
                    onSearchToggle: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _searchQuery = '';
                          _loadReports();
                          _loadAnnouncements();
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
                        fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 13),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                              child: Text('Pengumuman',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (_unreadAnnouncements > 0) ...[
                              const SizedBox(width: 6),
                              _TabBadge(count: _unreadAnnouncements),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                              child: Text('Tugas',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (_unreadReports > 0) ...[
                              const SizedBox(width: 6),
                              _TabBadge(count: _unreadReports),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                              child: Text('MyPost',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (_unreadMyReports > 0) ...[
                              const SizedBox(width: 6),
                              _TabBadge(count: _unreadMyReports),
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

            // ── Sub-filter: Unread | Read OR Tugas Status OR MyPost Status ──────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _mainTabController.index == 2
                  ? Row(
                      children: [
                        const Text('Filter', style: kMinimalDropdownLabelStyle),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MinimalDropdown<_MyPostFilter>(
                            value: _activeMyPostFilter,
                            onChanged: (val) {
                              if (val != null) setState(() => _activeMyPostFilter = val);
                            },
                            items: _MyPostFilter.values.map((f) {
                              int count = 0;
                              if (f == _MyPostFilter.all) {
                                count = _myDrafts.length + _myReports.length;
                              } else if (f == _MyPostFilter.draft) {
                                count = _myDrafts.length;
                              } else if (f == _MyPostFilter.validating) {
                                count = _myReports.where((i) => i.subStatus == ReportSubStatus.validating).length;
                              } else if (f == _MyPostFilter.approved) {
                                count = _myReports.where((i) =>
                                  i.subStatus != ReportSubStatus.validating &&
                                  i.subStatus != ReportSubStatus.rejected &&
                                  i.status != ReportStatus.closed
                                ).length;
                              } else if (f == _MyPostFilter.rejected) {
                                count = _myReports.where((i) => i.status == ReportStatus.closed).length;
                              }
                              return DropdownMenuItem(
                                value: f,
                                child: _countRow(_myPostFilterLabel(f), count),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    )
                  : _mainTabController.index == 1
                      ? Row(
                          children: [
                            const Text('Filter', style: kMinimalDropdownLabelStyle),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MinimalDropdown<_TaskStatusFilter>(
                                value: _activeTaskStatusFilter,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _activeTaskStatusFilter = val);
                                    _saveTaskStatusFilter(val);
                                  }
                                },
                                items: _TaskStatusFilter.values.map((f) {
                                  int count;
                                  if (f == _TaskStatusFilter.all) {
                                    count = _personalReports.length;
                                  } else {
                                    count = _personalReports
                                        .where((i) => i.subStatus == f.subStatus)
                                        .length;
                                  }
                                  return DropdownMenuItem(
                                    value: f,
                                    child: _countRow(f.label, count),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _SubFilterChip(
                                label: 'Unread',
                                isActive: _activeFilter == _SubFilter.unread,
                                badge: _unreadAnnouncements > 0 ? _unreadAnnouncements : null,
                                onTap: () =>
                                    setState(() => _activeFilter = _SubFilter.unread),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SubFilterChip(
                                label: 'Read',
                                isActive: _activeFilter == _SubFilter.read,
                                badge: _readAnnouncementCount > 0 ? _readAnnouncementCount : null,
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
                  _buildAnnouncementsTab(),
                  _buildReportsTab(),
                  _buildMyReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_loadingReports && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorReports != null && _reports.isEmpty) {
      return _buildErrorState(_errorReports!, _loadReports);
    }
    return _buildGroupedReportsList();
  }

  Widget _buildGroupedReportsList() {
    final urgentReports = _urgentTaskReports;
    final otherReports = _otherTaskReports;

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
        children: [
          _buildTaskSectionHeader(
            title: 'Butuh Tindakan Segera',
            count: urgentReports.length,
            isExpanded: _isUrgentSectionExpanded,
            onTap: () {
              setState(() {
                _isUrgentSectionExpanded = !_isUrgentSectionExpanded;
              });
            },
          ),
          if (_isUrgentSectionExpanded) ...urgentReports.map(_buildTaskListItem),
          _buildTaskSectionHeader(
            title: 'Lainnya',
            count: otherReports.length,
            isExpanded: _isOtherSectionExpanded,
            onTap: () {
              setState(() {
                _isOtherSectionExpanded = !_isOtherSectionExpanded;
              });
            },
          ),
          if (_isOtherSectionExpanded) ...otherReports.map(_buildTaskListItem),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    if (_loadingAnnouncements && _announcements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorAnnouncements != null && _announcements.isEmpty) {
      return _buildErrorState(_errorAnnouncements!, _loadAnnouncements);
    }
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: _buildList(_activeAnnouncements, isAnnouncement: true),
    );
  }

  Widget _buildMyReportsTab() {
    if (_loadingMyReports && _myRawReports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMyReports != null && _myRawReports.isEmpty) {
      return _buildErrorState(_errorMyReports!, _loadMyReports);
    }
    return RefreshIndicator(
      onRefresh: _loadMyReports,
      child: _buildList(_activeMyReports, isAnnouncement: false),
    );
  }

  Widget _buildList(List<InboxItem> list, {required bool isAnnouncement}) {
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(
                     _mainTabController.index == 1
                         ? Icons.assignment_outlined
                         : (_activeFilter == _SubFilter.unread
                             ? Icons.mark_email_read_outlined
                             : Icons.drafts_outlined),
                     size: 52,
                     color: Colors.grey.shade300,
                   ),
                   const SizedBox(height: 12),
                   Text(
                     _getEmptyStateMessage(),
                     style: const TextStyle(color: Colors.grey, fontSize: 14),
                   ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i];
        if (isAnnouncement) {
          return _AnnouncementCard(
            item: item,
            formatDate: _formatDate,
            onTap: () {
              _markItemRead(item);
              _showAnnouncementDetail(context, item);
            },
          );
        }
        return _buildTaskCard(item);
      },
    );
  }

  Widget _buildTaskSectionHeader({
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Text(
              '$count laporan',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListItem(InboxItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildTaskCard(item),
    );
  }

  Widget _buildTaskCard(InboxItem item) => _InboxCard(
        item: item,
        formatDate: _formatDate,
        levelResiko: _levelResiko,
        statusColor: _statusColor,
        statusLabel: _statusLabel,
        severityColor: _severityColor,
        onDetail: () {
          _markItemRead(item);
          Navigator.push(
            context,
            _FadePageRoute(
              builder: (_) => ReportDetailScreen(report: item.toReport()),
            ),
          );
        },
      );

  Widget _buildErrorState(String message, Future<void> Function() onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncementDetail(BuildContext context, InboxItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
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
                              Text(item.fromName ?? 'Admin',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF1A56C4))),
                              Text(_formatDate(item.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(item.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            height: 1.3)),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(item.body ?? '',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87, height: 1.6)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
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

// ── SUB FILTER CHIP (Unread | Read) ──────────────────────────────────────────
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


class _InboxCard extends StatelessWidget {
  final InboxItem item;
  final String Function(DateTime) formatDate;
  final String Function(ReportSeverity) levelResiko;
  final Color Function(ReportStatus) statusColor;
  final String Function(ReportStatus) statusLabel;
  final Color Function(ReportSeverity) severityColor;
  final VoidCallback onDetail;

  const _InboxCard({
    required this.item,
    required this.formatDate,
    required this.levelResiko,
    required this.statusColor,
    required this.statusLabel,
    required this.severityColor,
    required this.onDetail,
  });

  Color get _typeColor {
    switch (item.reportType) {
      case ReportType.hazard:
        return const Color(0xFFF44336);
      case ReportType.inspection:
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF757575);
    }
  }

  String get _typeLabel {
    switch (item.reportType) {
      case ReportType.hazard:
        return 'HAZARD';
      case ReportType.inspection:
        return 'INSPECTION';
      default:
        return '—';
    }
  }

  Duration? _remainingDuration() {
    if (item.dueDate == null) return null;
    return item.dueDate!.difference(DateTime.now());
  }

  bool _needsImmediateAction(ReportStatus status, ReportSeverity severity) {
    if (status == ReportStatus.closed) return false;
    final remaining = _remainingDuration();
    final nearDeadline =
        remaining != null && remaining <= const Duration(hours: 24);
    final highSeverity =
        severity == ReportSeverity.high || severity == ReportSeverity.critical;
    return nearDeadline || highSeverity;
  }

  ({Color border, Color background}) _urgencyStyle(
      ReportStatus status, ReportSeverity severity) {
    final remaining = _remainingDuration();
    if (status == ReportStatus.closed || remaining == null) {
      return (border: Colors.grey.shade200, background: Colors.white);
    }
    if (remaining <= Duration.zero || remaining <= const Duration(hours: 24)) {
      return (
        border: const Color(0xFFF44336).withValues(alpha: 0.45),
        background: const Color(0xFFFFEBEE),
      );
    }
    if (remaining <= const Duration(hours: 72)) {
      return (
        border: const Color(0xFFFF9800).withValues(alpha: 0.35),
        background: const Color(0xFFFFF8E1),
      );
    }
    return (border: Colors.grey.shade200, background: Colors.white);
  }

  String _formatRemaining(Duration diff) {
    final abs = diff.isNegative ? diff.abs() : diff;
    if (abs < const Duration(days: 1)) {
      final hours = abs.inHours;
      final minutes = abs.inMinutes.remainder(60);
      return '$hours jam $minutes menit';
    }
    final days = abs.inDays;
    final hours = abs.inHours.remainder(24);
    return '$days hari $hours jam';
  }

  Widget? _dueChip(ReportStatus status) {
    if (item.reportType != ReportType.hazard) return null;
    if (item.dueDate == null) return null;
    if (status == ReportStatus.closed) return null;
    final diff = _remainingDuration();
    if (diff == null) return null;

    Color color;
    const icon = Icons.alarm_outlined;
    String label;

    if (diff <= Duration.zero) {
      color = const Color(0xFFF44336);
      label = 'Terlambat ${_formatRemaining(diff)}';
    } else if (diff < const Duration(days: 1)) {
      color = const Color(0xFFF44336);
      label = _formatRemaining(diff);
    } else if (diff <= const Duration(hours: 72)) {
      color = const Color(0xFFFF9800);
      label = _formatRemaining(diff);
    } else {
      color = const Color(0xFF4CAF50);
      label = _formatRemaining(diff);
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
    final bool isRead = item.isRead;
    final ReportStatus status = item.status ?? ReportStatus.open;
    final ReportSeverity severity = item.severity ?? ReportSeverity.medium;
    final String imageUrl = item.imageUrl ?? '';
    final dueChip = _dueChip(status);
    final urgencyStyle = _urgencyStyle(status, severity);

    // Sub-status 'validating' ditampilkan sebagai "Validating" dengan warna
    // parent status 'open' (biru) agar konsisten dengan hierarki status.
    final String badgeLabel;
    final Color badgeColor;
    if (item.subStatus == ReportSubStatus.validating) {
      badgeLabel = 'Validating';
      badgeColor = statusColor(ReportStatus.open);
    } else if (item.subStatus == ReportSubStatus.rejected) {
      badgeLabel = 'Rejected';
      badgeColor = statusColor(ReportStatus.closed);
    } else {
      badgeLabel = statusLabel(status);
      badgeColor = statusColor(status);
    }

    return GestureDetector(
      onTap: onDetail,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isRead
                ? urgencyStyle.background
                : const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? urgencyStyle.border : const Color(0xFF1A56C4).withValues(alpha: 0.3),
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
              SizedBox(
                height: item.reportType == ReportType.hazard &&
                        dueChip != null
                    ? 155
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
                            child: imageUrl.isEmpty
                                ? Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_outlined,
                                        color: Colors.grey),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: imageUrl,
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
                              _typeLabel,
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
                              item.title,
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
                            Expanded(
                              child: Text(
                                item.description ?? '',
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
                              const Icon(Icons.access_time,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(formatDate(item.createdAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.location_on_outlined,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                    (item.location != null &&
                                            item.location!.trim().isNotEmpty)
                                        ? item.location!
                                        : '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ),
                            ],
                          ),
                            if (dueChip != null) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: dueChip,
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
                                    color: badgeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: badgeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: severityColor(severity),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    levelResiko(severity),
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
              if (_needsImmediateAction(status, severity))
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

// ── ANNOUNCEMENT CARD ────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final InboxItem item;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.item,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRead = item.isRead;
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
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                            item.body ?? '',
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
                              Text(formatDate(item.createdAt),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 12),
                              const Icon(Icons.person_outline,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(item.fromName ?? 'Admin',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ),
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
