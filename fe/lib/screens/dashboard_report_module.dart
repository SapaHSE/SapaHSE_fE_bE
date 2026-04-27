import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/report.dart';
import '../services/api_service.dart';
import '../services/excel_service.dart';
import 'report_detail_screen.dart';
import 'dashboard_widgets.dart';

class DashboardReportModule extends StatefulWidget {
  final ReportType type;
  final String subtitle;

  const DashboardReportModule({
    super.key,
    required this.type,
    required this.subtitle,
  });

  @override
  State<DashboardReportModule> createState() => _DashboardReportModuleState();
}

class _DashboardReportModuleState extends State<DashboardReportModule> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<Report> _reports = [];
  bool _isLoading = false;
  int _totalPages = 1;
  int _currentPage = 1;

  String _searchQuery = '';
  String _statusFilter = 'Semua';
  String _severityFilter = 'Semua';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
      _fetchReports(page: 1);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchReports({int page = 1}) async {
    setState(() => _isLoading = true);

    String path = widget.type == ReportType.hazard
        ? '/hazard-reports'
        : '/inspection-reports';
    String query = '?page=$page&search=$_searchQuery';

    if (_statusFilter != 'Semua') {
      query += '&status=${_statusFilter.toLowerCase().replaceAll(' ', '_')}';
    }
    if (widget.type == ReportType.hazard && _severityFilter != 'Semua') {
      query += '&severity=${_severityFilter.toLowerCase()}';
    }

    final response = await ApiService.get('$path$query');
    if (response.success && mounted) {
      try {
        dynamic dataObj = response.data;
        // Handle cases where response.data is wrapped in another 'data' key or is the list itself
        final dynamic rawData = (dataObj is Map && dataObj.containsKey('data'))
            ? dataObj['data']
            : dataObj;

        List<Report> parsedReports = [];
        int total = 1;
        int current = 1;

        if (rawData is Map<String, dynamic>) {
          parsedReports = (rawData['data'] as List? ?? [])
              .map((r) => Report.fromJson(r))
              .toList();
          total = int.tryParse(rawData['last_page']?.toString() ?? '1') ?? 1;
          current =
              int.tryParse(rawData['current_page']?.toString() ?? '1') ?? 1;
        } else if (rawData is List) {
          parsedReports = rawData.map((r) => Report.fromJson(r)).toList();
          if (dataObj is Map) {
            final meta = dataObj['meta'];
            total = int.tryParse(meta?['last_page']?.toString() ?? '1') ?? 1;
            current =
                int.tryParse(meta?['current_page']?.toString() ?? '1') ?? 1;
          }
        }

        setState(() {
          _reports = parsedReports;
          _totalPages = total;
          _currentPage = current;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('Error parsing reports: $e');
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showReportDetails(Report r) {
    final screenSize = MediaQuery.of(context).size;
    final isMobileDialog = screenSize.width < 800;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobileDialog ? 12 : 16)),
        backgroundColor: Colors.transparent,
        insetPadding: isMobileDialog
            ? const EdgeInsets.all(8)
            : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          width: isMobileDialog ? screenSize.width : 1000,
          height: isMobileDialog ? screenSize.height * 0.90 : 800,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobileDialog ? 12 : 16),
          ),
          child: ReportDetailScreen(report: r, isDialog: true),
        ),
      ),
    ).then((_) {
      if (mounted) _fetchReports(page: _currentPage);
    });
  }

  void _showEditReportForm(Report r) {
    final titleCtrl = TextEditingController(text: r.title);
    final locCtrl = TextEditingController(text: r.location);
    String currentStatus = r.status.label;
    String currentSeverity = r.severity.label;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (bCtx, setModalState) => AlertDialog(
          title: Text('Edit Laporan ${r.type.label}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Judul Laporan',
                        border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(
                    controller: locCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Lokasi', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: currentStatus,
                  decoration: const InputDecoration(
                      labelText: 'Status', border: OutlineInputBorder()),
                  items: ['Open', 'In Progress', 'Closed']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setModalState(() => currentStatus = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: currentSeverity,
                  decoration: const InputDecoration(
                      labelText: 'Tingkat Risiko',
                      border: OutlineInputBorder()),
                  items: ['Low', 'Medium', 'High', 'Critical']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setModalState(() => currentSeverity = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      String path = widget.type == ReportType.hazard
                          ? '/hazard-reports'
                          : '/inspection-reports';

                      final data = {
                        'title': titleCtrl.text,
                        'location': locCtrl.text,
                        'status':
                            currentStatus.toLowerCase().replaceAll(' ', '_'),
                        'severity': currentSeverity.toLowerCase(),
                      };

                      final res = await ApiService.put('$path/${r.id}', data);

                      if (res.success && mounted) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchReports(page: _currentPage);
                        showDialog(
                          context: context,
                          builder: (ctx) => DashboardSuccessDialog(
                            title: 'Berhasil!',
                            message:
                                'Laporan "${titleCtrl.text}" telah berhasil diperbarui.',
                          ),
                        );
                      } else if (mounted) {
                        setModalState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(res.errorMessage ?? 'Gagal update'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportReportsExcel() async {
    try {
      final String title = 'Laporan Data ${widget.type.label}';
      final String? dateRangeStr = _dateRange != null
          ? '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'
          : null;

      await ExcelService.exportReports(
        reports: _reports,
        title: title,
        dateRange: dateRangeStr,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Excel "$title" berhasil diexport'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal export Excel: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  String _fmt(DateTime dt) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: widget.type == ReportType.hazard
              ? 'Manajemen Hazard'
              : 'Manajemen Inspection',
          subtitle: widget.subtitle,
        ),
        const SizedBox(height: 32),
        _buildFilterBar(),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          decoration: dashboardCardDecoration(radius: 20),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(100),
                  child: Center(child: CircularProgressIndicator()))
              : Column(
                  children: [
                    _buildResponsiveList(),
                    _buildPaginationFooter(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: dashboardCardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search records...',
                      hintStyle:
                          TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                _exportButton(),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: _exportButton()),
          ],
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterDropdown(
                    'Status',
                    _statusFilter,
                    ['Semua', 'Open', 'In Progress', 'Closed'],
                    (v) => setState(() => _statusFilter = v!)),
                if (widget.type == ReportType.hazard) ...[
                  const SizedBox(width: 12),
                  _filterDropdown(
                      'Risiko',
                      _severityFilter,
                      ['Semua', 'Low', 'Medium', 'High', 'Critical'],
                      (v) => setState(() => _severityFilter = v!)),
                ],
                const SizedBox(width: 12),
                _dateRangeButton(),
                if (_searchQuery.isNotEmpty ||
                    _statusFilter != 'Semua' ||
                    _severityFilter != 'Semua' ||
                    _dateRange != null) ...[
                  const SizedBox(width: 12),
                  _resetButton(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportButton() {
    return ElevatedButton.icon(
      onPressed: _exportReportsExcel,
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('Export Excel'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  Widget _dateRangeButton() {
    return OutlinedButton.icon(
      onPressed: _pickDateRange,
      icon: Icon(Icons.calendar_today_rounded,
          size: 16,
          color: _dateRange != null
              ? const Color(0xFF1D4ED8)
              : const Color(0xFF64748B)),
      label: Text(
        _dateRange == null
            ? 'All Dates'
            : '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _dateRange != null
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF334155)),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(
            color: _dateRange != null
                ? const Color(0xFF1D4ED8)
                : const Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _dateRange != null
            ? const Color(0xFF1D4ED8).withValues(alpha: 0.05)
            : Colors.white,
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2023),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        initialDateRange: _dateRange,
        confirmText: 'TERAPKAN',
        saveText: 'TERAPKAN',
        helpText: 'PILIH RENTANG TANGGAL',
      );
      if (picked != null && mounted) {
        setState(() => _dateRange = picked);
        _fetchReports(page: 1);
      }
      return;
    }

    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1A56C4),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF0F172A),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1A56C4)),
              ),
            ),
            child: DateRangePickerDialog(
              firstDate: DateTime(2023),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: _dateRange,
              confirmText: 'TERAPKAN',
              cancelText: 'BATAL',
              helpText: 'PILIH RENTANG TANGGAL',
            ),
          ),
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
      _fetchReports(page: 1);
    }
  }

  Widget _resetButton() {
    return IconButton.filledTonal(
      onPressed: () {
        setState(() {
          _searchCtrl.clear();
          _searchQuery = '';
          _statusFilter = 'Semua';
          _severityFilter = 'Semua';
          _dateRange = null;
        });
      },
      icon: const Icon(Icons.refresh_rounded, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFFEF2F2),
        foregroundColor: const Color(0xFFEF4444),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _filterDropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: (v) {
            onChanged(v);
            _fetchReports(page: 1);
          },
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 13))))
              .toList(),
          style: const TextStyle(color: Colors.black87),
          icon: const Icon(Icons.arrow_drop_down, size: 20),
        ),
      ),
    );
  }

  Widget _buildResponsiveList() {
    final isMobile = MediaQuery.of(context).size.width < 1100;
    if (_reports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFCBD5E1)),
              SizedBox(height: 12),
              Text('No data found.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: _reports
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: DashboardReportCard(
                      report: r,
                      type: widget.type,
                      fmt: _fmt,
                      onView: () => _showReportDetails(r),
                      onEdit: () => _showEditReportForm(r),
                    ),
                  ))
              .toList(),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: const Color(0xFFF1F5F9)),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
              fontSize: 12,
              letterSpacing: 0.5),
          dataRowMinHeight: 64,
          dataRowMaxHeight: 72,
          columnSpacing: 40,
          horizontalMargin: 24,
          columns: [
            const DataColumn(label: Text('Ticket')),
            const DataColumn(label: Text('Title')),
            const DataColumn(label: Text('Location')),
            if (widget.type == ReportType.hazard)
              const DataColumn(label: Text('Risk')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('At')),
            const DataColumn(label: Text('Action')),
          ],
          rows: _reports.map((r) {
            return DataRow(cells: [
              DataCell(Text(r.ticketNumber ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
              DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(r.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis))),
              DataCell(Text(r.location)),
              if (widget.type == ReportType.hazard)
                DataCell(DashboardSeverityBadge(r.severity)),
              DataCell(DashboardStatusBadge(r.status)),
              DataCell(Text(_fmt(r.createdAt),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined,
                        size: 20, color: Color(0xFF1A56C4)),
                    onPressed: () => _showReportDetails(r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: Color(0xFF64748B)),
                    onPressed: () => _showEditReportForm(r),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Showing page $_currentPage of $_totalPages',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500)),
          Row(
            children: [
              DashboardPagerButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: _currentPage > 1
                      ? () => _fetchReports(page: _currentPage - 1)
                      : null),
              const SizedBox(width: 8),
              DashboardPagerButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: _currentPage < _totalPages
                      ? () => _fetchReports(page: _currentPage + 1)
                      : null),
            ],
          ),
        ],
      ),
    );
  }
}
