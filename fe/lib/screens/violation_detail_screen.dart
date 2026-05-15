import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../main.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/fab_notched_bottom_bar.dart';

class ViolationDetailScreen extends StatelessWidget {
  final UserViolation violation;

  const ViolationDetailScreen({
    super.key,
    required this.violation,
  });

  void _onTabTapped(BuildContext context, int index) {
    if (index == 4) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAktif = violation.status.toLowerCase() == 'aktif';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Detail Pelanggaran',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Icon ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 60, color: Color(0xFFD32F2F)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    violation.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAktif
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      violation.status,
                      style: TextStyle(
                        color: isAktif
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Violation Details ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('INFORMASI PELANGGARAN', [
                    _buildDetailRow('Lokasi', violation.location ?? '-'),
                    _buildDetailRow('Tanggal', violation.dateOfViolation ?? '-'),
                    _buildDetailRow('Berlaku Sampai', violation.expiredAt ?? '-'),
                  ]),

                  const SizedBox(height: 24),

                  if (violation.sanction != null && violation.sanction!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SANKSI',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 1),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBFA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.gavel_rounded,
                                  color: Color(0xFFD32F2F), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  violation.sanction!,
                                  style: const TextStyle(
                                      color: Color(0xFFB71C1C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  SizedBox(
                    height: AppSafeInsets.bottomNavScrollPadding(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FabNotchedBottomBar(
        notchRadius: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DetailNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                onTap: (idx) => _onTabTapped(context, idx)),
            _DetailNavItem(
                icon: Icons.article_outlined,
                label: 'News',
                index: 1,
                onTap: (idx) => _onTabTapped(context, idx)),
            const SizedBox(width: 56),
            _DetailNavItem(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                index: 3,
                onTap: (idx) => _onTabTapped(context, idx)),
            _DetailNavItem(
                icon: Icons.menu,
                label: 'Menu',
                index: 4,
                isActive: true,
                onTap: (idx) => _onTabTapped(context, idx)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        backgroundColor: const Color(0xFF1A56C4),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool isActive;
  final Function(int) onTap;

  const _DetailNavItem({
    required this.icon,
    required this.label,
    required this.index,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
