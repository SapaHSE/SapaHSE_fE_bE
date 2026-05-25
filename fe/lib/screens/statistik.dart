import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/statistics_service.dart';
import '../widgets/app_safe_insets.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen> {
  String _selectedPeriod = 'Bulan Ini';
  final List<String> _periods = ['Bulan Ini', 'Tahun Ini', 'Sepanjang Waktu', 'Kustom'];

  PersonalStatistics? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String? startDate;
    String? endDate;
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');

    switch (_selectedPeriod) {
      case 'Bulan Ini':
        startDate = fmt.format(DateTime(now.year, now.month, 1));
        endDate = fmt.format(now);
        break;
      case 'Tahun Ini':
        startDate = fmt.format(DateTime(now.year, 1, 1));
        endDate = fmt.format(now);
        break;
      case 'Sepanjang Waktu':
        break;
      case 'Kustom':
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2023),
          lastDate: now,
          initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
          confirmText: 'TERAPKAN',
          saveText: 'TERAPKAN',
          helpText: 'PILIH RENTANG TANGGAL',
        );
        if (picked == null || !mounted) {
          setState(() => _isLoading = false);
          return;
        }
        startDate = fmt.format(picked.start);
        endDate = fmt.format(picked.end);
        break;
    }

    if (!mounted) return;

    final result = await StatisticsService.fetchPersonalStatistics(
      startDate: startDate,
      endDate: endDate,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _stats = result.stats;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.errorMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Statistik Saya',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchStatistics,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _stats!;

    return RefreshIndicator(
      onRefresh: _fetchStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSafeInsets.pagePadding(
          context,
          top: 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildPeriodSelector(),
            const SizedBox(height: 24),
            _buildStatsGrid(stats),
            const SizedBox(height: 24),
            _buildAccuracySection(stats),
            const SizedBox(height: 16),
            _buildHandlingSpeed(stats),
            const SizedBox(height: 16),
            _buildAwards(stats),
            if (stats.needsCategoryAdjustment > 0) ...[
              const SizedBox(height: 24),
              _buildOnboardingBanner(),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map((p) {
          final isSelected = _selectedPeriod == p;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedPeriod = p);
              _fetchStatistics();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF5C38FF) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
              ),
              child: Text(
                p,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsGrid(PersonalStatistics stats) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        _buildStatCard(stats.total.toString(), 'Dikirim', Colors.black87),
        _buildStatCard(stats.accepted.toString(), 'Diterima', const Color(0xFF4CAF50)),
        _buildStatCard(stats.rejected.toString(), 'Ditolak', Colors.red),
        _buildStatCard('${stats.accuracy}%', 'Akurasi', const Color(0xFF5C38FF)),
        _buildStatCard(stats.streak.toString(), 'Streak', const Color(0xFFF44336), isFire: true),
      ],
    );
  }

  Widget _buildAccuracySection(PersonalStatistics stats) {
    final value = stats.categoryAccuracy / 100.0;
    return _buildDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tingkat Akurasi Kategori', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${stats.categoryAccuracy}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5C38FF))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF5C38FF)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stats.categoryMessage,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildHandlingSpeed(PersonalStatistics stats) {
    return _buildDetailCard(
      title: 'Kecepatan Penanganan',
      child: Column(
        children: [
          _buildMetricRow('Rata-rata Validasi', stats.avgValidationLabel, 'Sejak laporan dikirim'),
          const Divider(height: 24),
          _buildMetricRow('Rata-rata Pengerjaan', stats.avgProcessingLabel, 'Setelah divalidasi'),
          const Divider(height: 24),
          _buildMetricRow('Rata-rata Open → Closed', stats.avgTotalLabel, 'Total waktu penyelesaian'),
        ],
      ),
    );
  }

  Widget _buildAwards(PersonalStatistics stats) {
    if (stats.awards.isEmpty) return const SizedBox.shrink();

    return _buildDetailCard(
      title: 'Medali & Penghargaan',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: stats.awards.map((a) => _buildAwardItem(a)).toList(),
        ),
      ),
    );
  }

  Widget _buildOnboardingBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBC02D).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFFFBC02D), size: 20),
              const SizedBox(width: 8),
              const Text('Saran Peningkatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Beberapa laporanmu memerlukan penyesuaian kategori. Yuk pelajari kembali panduan di Menu > Workspace > Onboarding agar laporanmu lebih tepat sasaran.',
            style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBC02D),
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Buka Onboarding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color, {bool isFire = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              if (isFire) ...[
                const SizedBox(width: 4),
                const Icon(Icons.local_fire_department, color: Colors.red, size: 16),
              ]
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildDetailCard({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, String subLabel) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
      ],
    );
  }

  Widget _buildAwardItem(AwardItem award) {
    final icon = _mapIcon(award.icon);
    final color = _parseColor(award.color);

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(award.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(award.date, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  IconData _mapIcon(String icon) {
    switch (icon) {
      case 'emoji_events':
        return Icons.emoji_events;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'bolt':
        return Icons.bolt;
      default:
        return Icons.emoji_events;
    }
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
