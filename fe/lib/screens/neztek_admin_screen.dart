import 'package:flutter/material.dart';

class NeztekAdminScreen extends StatelessWidget {
  const NeztekAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  _buildTenantList(),
                  const SizedBox(height: 24),
                  _buildAddButton(),
                  const SizedBox(height: 20),
                  _buildBottomActions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
    decoration: const BoxDecoration(
      color: Color(0xFF23253F),
      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEZTEK PLATFORM ADMIN', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        const Text('Tenant Management', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildStatsRow() => Row(
    children: [
      _buildStatCard('14', 'Tenant Aktif'),
      const SizedBox(width: 12),
      _buildStatCard('1,847', 'Total Users'),
      const SizedBox(width: 12),
      _buildStatCard('2', 'Expiring Soon', color: Colors.orange),
    ],
  );

  Widget _buildStatCard(String val, String label, {Color? color}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF323552),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(val, style: TextStyle(color: color ?? Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
        ],
      ),
    ),
  );

  Widget _buildFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _buildFilterItem('All', active: true),
        _buildFilterItem('Aktif'),
        _buildFilterItem('Trial'),
        _buildFilterItem('Expiring'),
        _buildFilterItem('Tangguhkan'),
      ],
    ),
  );

  Widget _buildFilterItem(String label, {bool active = false}) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: active ? const Color(0xFF3F51B5) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: active ? Colors.transparent : Colors.grey.shade200),
    ),
    child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey.shade600, fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
  );

  Widget _buildTenantList() => Column(
    children: [
      _buildTenantItem('PT. Bukit Balduri Energi', '142 users • HSE + IT modules', 'Pro', 'exp Dec 2025', const Color(0xFF2E7D32), Colors.green.shade50),
      _buildTenantItem('PT. Mitra Tambang Sejahtera', '87 users • HSE only', 'Starter', 'exp Mar 2026', const Color(0xFF1565C0), Colors.blue.shade50),
      _buildTenantItem('PT. Energi Nusantara', '205 pengguna • Semua modul', 'Enterprise', '16d left', Colors.orange.shade800, Colors.orange.shade50, isWarning: true),
      _buildTenantItem('PT. Konstruksi Maju', '23 users • Trial', 'Trial', '7d trial', Colors.brown, Colors.grey.shade100),
    ],
  );

  Widget _buildTenantItem(String name, String sub, String badge, String date, Color color, Color bg, {bool isWarning = false}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: isWarning ? Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5) : Border.all(color: Colors.grey.shade100),
    ),
    child: Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.business_outlined, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (isWarning) Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 12),
                if (isWarning) const SizedBox(width: 4),
                Text(date, style: TextStyle(color: isWarning ? Colors.orange : Colors.grey.shade400, fontSize: 10, fontWeight: isWarning ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildAddButton() => Container(
    width: double.infinity,
    height: 50,
    decoration: BoxDecoration(
      color: const Color(0xFF3F51B5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text('Daftarkan Tenant Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );

  Widget _buildBottomActions() => Row(
    children: [
      Expanded(child: _buildActionBtn(Icons.language, 'Language Manager', const Color(0xFF1976D2))),
      const SizedBox(width: 12),
      Expanded(child: _buildActionBtn(Icons.apps, 'Katalog Modul', const Color(0xFFE65100))),
    ],
  );

  Widget _buildActionBtn(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _buildFooter(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    color: Colors.white,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              Icon(Icons.arrow_back, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 8),
              Text('Kembali ke App', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Text('Neztek Platform v1.0', style: TextStyle(color: Colors.grey.shade300, fontSize: 10)),
      ],
    ),
  );
}
