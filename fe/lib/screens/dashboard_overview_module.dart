import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/report.dart';
import '../services/excel_service.dart';
import 'dashboard_widgets.dart';

class DashboardOverviewModule extends StatefulWidget {
  final List<Report> hazardReports;
  final List<Report> inspectionReports;

  const DashboardOverviewModule({
    super.key,
    required this.hazardReports,
    required this.inspectionReports,
  });

  @override
  State<DashboardOverviewModule> createState() =>
      _DashboardOverviewModuleState();
}

class _DashboardOverviewModuleState extends State<DashboardOverviewModule> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoadingDashboard = false;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoadingDashboard = true);
    final response = await ApiService.get('/dashboard/statistics');
    if (response.success && mounted) {
      setState(() {
        _dashboardData = response.data['data'];
        _isLoadingDashboard = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingDashboard = false);
    }
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
        _fetchDashboardData();
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
      _fetchDashboardData();
    }
  }

  void _exportReportsExcel(List<Report> reports, String type) async {
    try {
      final String title = type == 'Merged'
          ? 'Laporan Gabungan Hazard & Inspection'
          : 'Laporan Data $type';

      final String? dateRangeStr = _dateRange != null
          ? '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'
          : null;

      await ExcelService.exportReports(
        reports: reports,
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDashboard || _dashboardData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              CircularProgressIndicator(color: Color(0xFF1A56C4)),
              SizedBox(height: 16),
              Text('Memuat data statistik...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final summary = _dashboardData!['summary'];
    final hazardStats = _dashboardData!['hazard'];
    final userStats = _dashboardData!['user_stats'];

    final int hazardCount = summary['total_hazard'] ?? 0;
    final int inspectionCount = summary['total_inspection'] ?? 0;
    final int totalReports = summary['total_reports'] ?? 0;

    final sev = hazardStats['severity'] ?? {};
    final int lowCount = sev['low'] ?? 0;
    final int mediumCount = sev['medium'] ?? 0;
    final int highCount = sev['high'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, headerConstraints) {
          final isCompact = headerConstraints.maxWidth < 700;
          return isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DashboardSectionHeader(
                      title: 'Overview Sistem',
                      subtitle: 'Pantau keseluruhan operasi HSE.',
                    ),
                    const SizedBox(height: 20),
                    _buildExportButtons(),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Expanded(
                      child: DashboardSectionHeader(
                        title: 'Overview Sistem',
                        subtitle:
                            'Pantau keseluruhan operasi, hazard, dan inspeksi pekerja.',
                      ),
                    ),
                    const SizedBox(width: 24),
                    _buildExportButtons(),
                  ],
                );
        }),
        const SizedBox(height: 32),
        _buildStatCards(summary, userStats, hazardStats),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 950;
            return Column(
              children: [
                if (isWide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        flex: 2,
                        child: _buildChartCard(
                            'Tren Pelaporan (7 Hari Terakhir)',
                            _buildTrendChart())),
                    const SizedBox(width: 24),
                    Expanded(
                        flex: 1,
                        child: _buildChartCard(
                            'Distribusi Laporan',
                            _buildDonutChart(
                                hazardCount, inspectionCount, totalReports))),
                  ])
                else ...[
                  _buildChartCard(
                      'Tren Pelaporan (7 Hari Terakhir)', _buildTrendChart()),
                  const SizedBox(height: 24),
                  _buildChartCard(
                      'Distribusi Laporan',
                      _buildDonutChart(
                          hazardCount, inspectionCount, totalReports)),
                ],
                const SizedBox(height: 24),
                if (isWide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: _buildChartCard('Analisis Tingkat Risiko',
                            _buildBarChart(lowCount, highCount, highCount))),
                    const SizedBox(width: 24),
                    Expanded(
                        child: _buildChartCard(
                            'Aktivitas Terbaru', _buildRecentActivity())),
                  ])
                else ...[
                  _buildChartCard('Analisis Tingkat Risiko',
                      _buildBarChart(lowCount, mediumCount, highCount)),
                  const SizedBox(height: 24),
                  _buildChartCard('Aktivitas Terbaru', _buildRecentActivity()),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildExportButtons() {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range, size: 20),
          tooltip: 'Filter Tanggal',
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {
            _exportReportsExcel(
                [...widget.hazardReports, ...widget.inspectionReports],
                'Merged');
          },
          icon: const Icon(Icons.file_download_rounded, size: 20),
          label: const Text('Export Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(Map<String, dynamic> summary,
      Map<String, dynamic> userStats, Map<String, dynamic> hazardStats) {
    final screenWidth = MediaQuery.of(context).size.width -
        (MediaQuery.of(context).size.width > 800 ? 280 : 0) -
        64; // Adjust for sidebar and padding

    final cardW = screenWidth < 500
        ? (screenWidth - 20)
        : (screenWidth < 900
            ? (screenWidth - 40) / 2
            : (screenWidth < 1200 ? (screenWidth - 60) / 3 : 240.0));

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _statItem('Total Laporan', '${summary['total_reports']}',
            Icons.analytics_rounded, const Color(0xFF6366F1), cardW),
        _statItem('Hazard Terdeteksi', '${summary['total_hazard']}',
            Icons.warning_amber_rounded, const Color(0xFFF43F5E), cardW),
        _statItem('Inspeksi Selesai', '${summary['total_inspection']}',
            Icons.fact_check_rounded, const Color(0xFFF59E0B), cardW),
        _statItem('Pengguna Aktif', '${userStats['active']}',
            Icons.person_search_rounded, const Color(0xFF10B981), cardW),
        _statItem(
            'Hazard Terbuka',
            '${hazardStats['open'] ?? 0}',
            Icons.notification_important_rounded,
            const Color(0xFF8B5CF6),
            cardW),
        _statItem('HSE Online', '${userStats['total']}',
            Icons.wifi_protected_setup_rounded, const Color(0xFF0EA5E9), cardW),
      ],
    );
  }

  Widget _statItem(
      String title, String value, IconData icon, Color color, double width) {
    return SizedBox(
      width: width,
      child: DashboardStatCard(
          title: title, value: value, icon: icon, color: color),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: dashboardCardDecoration(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 32),
          SizedBox(height: 300, child: chart),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final trendList = _dashboardData?['weekly_trend'] as List? ?? [];
    if (trendList.isEmpty) {
      return const Center(child: Text('Data tren tidak tersedia'));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFFE2E8F0),
              strokeWidth: 1,
              dashArray: [5, 5]),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                int idx = val.toInt();
                if (idx >= 0 && idx < trendList.length) {
                  String day = trendList[idx]['day'].toString();
                  const dayMap = {
                    'Monday': 'Sen',
                    'Tuesday': 'Sel',
                    'Wednesday': 'Rab',
                    'Thursday': 'Kam',
                    'Friday': 'Jum',
                    'Saturday': 'Sab',
                    'Sunday': 'Min'
                  };
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(dayMap[day] ?? day.substring(0, 1),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8))),
                  );
                }
                return const Text('');
              },
              reservedSize: 32,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _lineStyle(trendList, 'hazard', const Color(0xFFF43F5E)),
          _lineStyle(trendList, 'inspection', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  LineChartBarData _lineStyle(List data, String key, Color color) {
    return LineChartBarData(
      spots: List.generate(data.length,
          (i) => FlSpot(i.toDouble(), (data[i][key] as num).toDouble())),
      isCurved: true,
      curveSmoothness: 0.4,
      color: color,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 3,
              strokeColor: color)),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildDonutChart(int hazard, int inspection, int total) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 8,
            centerSpaceRadius: 70,
            startDegreeOffset: -90,
            sections: [
              PieChartSectionData(
                  color: const Color(0xFFF43F5E),
                  value: hazard.toDouble(),
                  title: '',
                  radius: 22),
              PieChartSectionData(
                  color: const Color(0xFFF59E0B),
                  value: inspection.toDouble(),
                  title: '',
                  radius: 22),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$total',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
            const Text('TOTAL\nLAPORAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 1)),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart(int low, int high, int critical) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: [low, high, critical].reduce((a, b) => a > b ? a : b).toDouble() +
            2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                String text = '';
                if (val == 0) text = 'LOW';
                if (val == 1) text = 'HIGH';
                if (val == 2) text = 'CRIT';
                return SideTitleWidget(
                    meta: meta,
                    child: Text(text,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w900,
                            fontSize: 10)));
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          _barGroup(0, low.toDouble(), const Color(0xFF10B981)),
          _barGroup(1, high.toDouble(), const Color(0xFFF59E0B)),
          _barGroup(2, critical.toDouble(), const Color(0xFFF43F5E)),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter),
          width: 32,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          backDrawRodData: BackgroundBarChartRodData(
              show: true, toY: y > 0 ? y : 1, color: const Color(0xFFF1F5F9)),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final activities = _dashboardData?['latest_activities'] as List? ?? [];
    if (activities.isEmpty) {
      return const Center(
          child: Text('Belum ada aktivitas',
              style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final act = activities[index];
        return DashboardActivityItem(
          title: act['title'] ?? 'Aktivitas',
          subtitle: 'Oleh ${act['user'] ?? 'Anonim'}',
          time: act['timestamp'] ?? '',
          isLast: index == activities.length - 1,
        );
      },
    );
  }
}
