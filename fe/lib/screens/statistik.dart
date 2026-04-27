import 'package:flutter/material.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen> {
  String _selectedPeriod = 'Bulan Ini';
  final List<String> _periods = ['Bulan Ini', 'Tahun Ini', 'Sepanjang Waktu', 'Kustom'];

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // ── Period Selector ──────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periods.map((p) {
                  final isSelected = _selectedPeriod == p;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPeriod = p),
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
            ),

            const SizedBox(height: 24),

            // ── Main Stats Grid ──────────────────────────────────────────
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _buildStatCard('23', 'Dikirim', Colors.black87),
                _buildStatCard('18', 'Diterima', const Color(0xFF4CAF50)),
                _buildStatCard('3', 'Ditolak', Colors.red),
                _buildStatCard('2', 'Dikoreksi', const Color(0xFFF57C00)),
                _buildStatCard('78%', 'Akurasi', const Color(0xFF5C38FF)),
                _buildStatCard('12', 'Streak', const Color(0xFFF44336), isFire: true),
              ],
            ),

            const SizedBox(height: 24),

            // ── Accuracy Section ──────────────────────────────────────────
            _buildDetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tingkat Akurasi Kategori', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Text('78%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5C38FF))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.78,
                      minHeight: 6,
                      backgroundColor: Color(0xFFF0F0F0),
                      valueColor: AlwaysStoppedAnimation(Color(0xFF5C38FF)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Target: 90% - 3 laporan perlu penyesuaian kategori bulan ini',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Handling Speed ────────────────────────────────────────────
            _buildDetailCard(
              title: 'Kecepatan Penanganan',
              child: Column(
                children: [
                  _buildMetricRow('Rata-rata Validasi', '45 mnt', 'Sejak laporan dikirim'),
                  const Divider(height: 24),
                  _buildMetricRow('Rata-rata Pengerjaan', '2.3 hari', 'Setelah divalidasi'),
                  const Divider(height: 24),
                  _buildMetricRow('Rata-rata Open → Closed', '3.1 hari', 'Total waktu penyelesaian'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Medals & Awards ───────────────────────────────────────────
            _buildDetailCard(
              title: 'Medali & Penghargaan',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAwardItem('Pelapor Terbaik', 'Feb 2024', Icons.emoji_events, const Color(0xFFFFB300)),
                    _buildAwardItem('Streak 30 Hari', 'Jan 2024', Icons.local_fire_department, const Color(0xFFFF5722)),
                    _buildAwardItem('Respon Tercepat', 'Mar 2024', Icons.bolt, const Color(0xFF2196F3)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Onboarding Banner ────────────────────────────────────────
            Container(
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
            ),

            const SizedBox(height: 40),
          ],
        ),
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

  Widget _buildAwardItem(String title, String date, IconData icon, Color color) {
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
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(date, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
