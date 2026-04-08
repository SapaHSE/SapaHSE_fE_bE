import 'package:flutter/material.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/dummy_data.dart';
import '../models/report.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Filter state ───────────────────────────────────────────────────────────
  String _filterType   = 'Semua';
  String _filterStatus = 'Semua';
  DateTimeRange? _dateRange;
  bool _isExporting = false;

  final List<String> _typeOptions   = ['Semua', 'Hazard', 'Inspection'];
  final List<String> _statusOptions = ['Semua', 'Open', 'In Progress', 'Closed'];

  // ── Filtered reports ───────────────────────────────────────────────────────
  List<Report> get _filtered {
    return dummyReports.where((r) {
      final matchType = _filterType == 'Semua' || r.type.label == _filterType;
      final matchStatus = _filterStatus == 'Semua' ||
          (_filterStatus == 'Open'        && r.status == ReportStatus.open) ||
          (_filterStatus == 'In Progress' && r.status == ReportStatus.inProgress) ||
          (_filterStatus == 'Closed'      && r.status == ReportStatus.closed);
      final matchDate = _dateRange == null ||
          (r.createdAt.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
           r.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1))));
      return matchType && matchStatus && matchDate;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  int get _total      => _filtered.length;
  int get _hazard     => _filtered.where((r) => r.type == ReportType.hazard).length;
  int get _inspection => _filtered.where((r) => r.type == ReportType.inspection).length;
  int get _open       => _filtered.where((r) => r.status == ReportStatus.open).length;
  int get _inProgress => _filtered.where((r) => r.status == ReportStatus.inProgress).length;
  int get _closed     => _filtered.where((r) => r.status == ReportStatus.closed).length;
  int get _high       => _filtered.where((r) => r.severity == ReportSeverity.high).length;
  int get _medium     => _filtered.where((r) => r.severity == ReportSeverity.medium).length;
  int get _low        => _filtered.where((r) => r.severity == ReportSeverity.low).length;

  String _fmt(DateTime dt) {
    final m = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${dt.day} ${m[dt.month-1]} ${dt.year}';
  }

  // ── Export CSV ─────────────────────────────────────────────────────────────
  Future<void> _exportCSV() async {
    setState(() => _isExporting = true);
    try {
      final rows = <List<dynamic>>[
        ['No', 'ID', 'Judul', 'Tipe', 'Severity', 'Status', 'Lokasi', 'Dilaporkan Oleh', 'Tanggal'],
      ];
      for (var i = 0; i < _filtered.length; i++) {
        final r = _filtered[i];
        rows.add([
          i + 1, r.id, r.title, r.type.label,
          r.severity.label, r.status.label, r.location,
          r.reportedBy, _fmt(r.createdAt),
        ]);
      }
      final csv  = const ListToCsvConverter().convert(rows);
      final dir  = await getTemporaryDirectory();
      final ts   = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/sapahse_laporan_$ts.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'SapaHse - Export Laporan',
        text: 'Export laporan SapaHse (${_filtered.length} data)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal export: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A56C4),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dashboard Laporan',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _isExporting ? null : _exportCSV,
            icon: _isExporting
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A56C4)))
                : const Icon(Icons.download_outlined, size: 18, color: Color(0xFF1A56C4)),
            label: Text(
              _isExporting ? 'Exporting...' : 'Export CSV',
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A56C4), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          _buildFilterSection(),
          const SizedBox(height: 16),
          _sectionLabel('Ringkasan'),
          const SizedBox(height: 8),
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _sectionLabel('Status Laporan'),
          const SizedBox(height: 8),
          _buildBarChart(
            items: [
              _BarItem('Open',        _open,       const Color(0xFF4CAF50)),
              _BarItem('In Progress', _inProgress, const Color(0xFFFF9800)),
              _BarItem('Closed',      _closed,     const Color(0xFFF44336)),
            ],
          ),
          const SizedBox(height: 16),
          _sectionLabel('Tingkat Risiko'),
          const SizedBox(height: 8),
          _buildBarChart(
            items: [
              _BarItem('High',   _high,   const Color(0xFFF44336)),
              _BarItem('Medium', _medium, const Color(0xFFFF9800)),
              _BarItem('Low',    _low,    const Color(0xFF4CAF50)),
            ],
          ),
          const SizedBox(height: 16),
          _sectionLabel('Tipe Laporan'),
          const SizedBox(height: 8),
          _buildTypeRow(),
          const SizedBox(height: 16),
          Row(children: [
            _sectionLabel('Daftar Laporan'),
            const Spacer(),
            _countBadge(_filtered.length),
          ]),
          const SizedBox(height: 8),
          _buildTable(),
        ],
      ),
    );
  }

  // ── FILTERS ────────────────────────────────────────────────────────────────
  Widget _buildFilterSection() {
    final hasFilter = _filterType != 'Semua' || _filterStatus != 'Semua' || _dateRange != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _dropdown('Tipe', _typeOptions, _filterType,
              (v) => setState(() => _filterType = v!))),
          const SizedBox(width: 10),
          Expanded(child: _dropdown('Status', _statusOptions, _filterStatus,
              (v) => setState(() => _filterStatus = v!))),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickDateRange,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(
                  color: _dateRange != null ? const Color(0xFF1A56C4) : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: _dateRange != null ? const Color(0xFFEFF4FF) : Colors.white,
            ),
            child: Row(children: [
              Icon(Icons.date_range_outlined, size: 18,
                  color: _dateRange != null ? const Color(0xFF1A56C4) : Colors.grey),
              const SizedBox(width: 8),
              Text(
                _dateRange != null
                    ? '${_fmt(_dateRange!.start)}  —  ${_fmt(_dateRange!.end)}'
                    : 'Pilih rentang tanggal',
                style: TextStyle(
                  fontSize: 13,
                  color: _dateRange != null ? const Color(0xFF1A56C4) : Colors.grey,
                  fontWeight: _dateRange != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (_dateRange != null)
                GestureDetector(
                  onTap: () => setState(() => _dateRange = null),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF1A56C4)),
                ),
            ]),
          ),
        ),
        if (hasFilter) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() {
              _filterType   = 'Semua';
              _filterStatus = 'Semua';
              _dateRange    = null;
            }),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh, size: 14, color: Colors.red),
              SizedBox(width: 4),
              Text('Reset filter', style: TextStyle(fontSize: 12, color: Colors.red)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _dropdown(String label, List<String> items, String val, ValueChanged<String?> cb) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: val, isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: cb,
          ),
        ),
      ),
    ]);
  }

  // ── SUMMARY CARDS ──────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.8,
      children: [
        _StatCard('Total Laporan', '$_total', Icons.assignment_outlined, const Color(0xFF1A56C4)),
        _StatCard('Hazard', '$_hazard', Icons.warning_amber_rounded, const Color(0xFFF44336)),
        _StatCard('Inspection', '$_inspection', Icons.search, const Color(0xFF1565C0)),
        _StatCard('Belum Selesai', '${_open + _inProgress}', Icons.pending_outlined, const Color(0xFFFF9800)),
      ],
    );
  }

  // ── BAR CHART ──────────────────────────────────────────────────────────────
  Widget _buildBarChart({required List<_BarItem> items}) {
    final maxVal = _total == 0 ? 1 : _total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(item.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${item.value}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: item.color)),
              if (_total > 0)
                Text('  (${(item.value * 100 / _total).round()}%)',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.value / maxVal,
                minHeight: 10,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(item.color),
              ),
            ),
          ]),
        )).toList(),
      ),
    );
  }

  // ── TYPE BREAKDOWN ─────────────────────────────────────────────────────────
  Widget _buildTypeRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: _cardDeco(),
      child: Row(children: [
        Expanded(child: _TypeTile('Hazard',     _hazard,     _total, const Color(0xFFF44336), Icons.warning_amber_rounded)),
        Container(width: 1, height: 70, color: Colors.grey.shade100),
        Expanded(child: _TypeTile('Inspection', _inspection, _total, const Color(0xFF1565C0), Icons.search)),
      ]),
    );
  }

  // ── DATA TABLE ─────────────────────────────────────────────────────────────
  Widget _buildTable() {
    final reports = _filtered;
    if (reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: _cardDeco(),
        child: const Center(child: Column(children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('Tidak ada data', style: TextStyle(color: Colors.grey)),
        ])),
      );
    }
    return Container(
      decoration: _cardDeco(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFEFF4FF)),
            headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A56C4)),
            dataTextStyle: const TextStyle(fontSize: 11, color: Colors.black87),
            columnSpacing: 14,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 58,
            columns: const [
              DataColumn(label: Text('No')),
              DataColumn(label: Text('Judul')),
              DataColumn(label: Text('Tipe')),
              DataColumn(label: Text('Severity')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Lokasi')),
              DataColumn(label: Text('PJA')),
              DataColumn(label: Text('Tanggal')),
            ],
            rows: List.generate(reports.length, (i) {
              final r = reports[i];
              return DataRow(
                color: WidgetStateProperty.resolveWith((_) =>
                    i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFF)),
                cells: [
                  DataCell(Text('${i+1}', style: const TextStyle(color: Colors.grey))),
                  DataCell(SizedBox(width: 110,
                      child: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis))),
                  DataCell(_TypeBadge(r.type)),
                  DataCell(_SeverityBadge(r.severity)),
                  DataCell(_StatusBadge(r.status)),
                  DataCell(SizedBox(width: 90,
                      child: Text(r.location, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10)))),
                  DataCell(Text(r.reportedBy, style: const TextStyle(fontSize: 10))),
                  DataCell(Text(_fmt(r.createdAt), style: const TextStyle(fontSize: 10))),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
  );

  Widget _sectionLabel(String t) =>
      Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87));

  Widget _countBadge(int n) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: const Color(0xFF1A56C4).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10)),
    child: Text('$n data',
        style: const TextStyle(fontSize: 12, color: Color(0xFF1A56C4), fontWeight: FontWeight.bold)),
  );
}

// ── DATA CLASS ────────────────────────────────────────────────────────────────
class _BarItem {
  final String label;
  final int value;
  final Color color;
  const _BarItem(this.label, this.value, this.color);
}

// ── STAT CARD ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0,2))],
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ]),
  );
}

// ── TYPE TILE ─────────────────────────────────────────────────────────────────
class _TypeTile extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  final IconData icon;

  const _TypeTile(this.label, this.count, this.total, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (count * 100 / total).round();
    return Column(children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(height: 6),
      Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text('$pct%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── BADGES ────────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final ReportType type;
  const _TypeBadge(this.type);
  @override
  Widget build(BuildContext context) {
    final c = type == ReportType.hazard ? const Color(0xFFF44336) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(type.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final ReportSeverity severity;
  const _SeverityBadge(this.severity);
  Color get _c => switch (severity) {
    ReportSeverity.high   => const Color(0xFFF44336),
    ReportSeverity.medium => const Color(0xFFFF9800),
    ReportSeverity.low    => const Color(0xFF4CAF50),
  };
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: _c, borderRadius: BorderRadius.circular(8)),
    child: Text(severity.label,
        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
  );
}

class _StatusBadge extends StatelessWidget {
  final ReportStatus status;
  const _StatusBadge(this.status);
  Color get _c => switch (status) {
    ReportStatus.open       => const Color(0xFF4CAF50),
    ReportStatus.inProgress => const Color(0xFFFF9800),
    ReportStatus.closed     => const Color(0xFFF44336),
  };
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _c.withOpacity(0.3)),
    ),
    child: Text(status.label, style: TextStyle(fontSize: 10, color: _c, fontWeight: FontWeight.w600)),
  );
}