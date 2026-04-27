import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';
import 'dashboard_screen.dart';
import 'my_profile.dart';
import 'statistik.dart';
import 'user_management.dart';
import 'kategori_laporan.dart';
import 'settings_screen.dart';
import 'neztek_admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  ProfileData? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await ProfileService.getProfile();
    if (mounted && result.success && result.data != null) {
      setState(() {
        _profileData = result.data;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu, color: Colors.black87, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Menu',
                    style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text('Akun, workspace & pengaturan',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(height: 1, color: Colors.grey.shade200),
            _buildProfileCard(),
            Divider(height: 1, color: Colors.grey.shade200),
            _buildMenuItem(
              icon: Icons.person,
              iconBg: const Color(0xFFF3E5F5),
              iconColor: const Color(0xFF6A1B9A),
              title: 'Profile',
              subtitle: 'Biodata, licenses, medical, certifications',
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyProfileScreen()));
              },
            ),
            Divider(height: 1, color: Colors.grey.shade100, indent: 70),
            _buildMenuItem(
              icon: Icons.bar_chart,
              iconBg: const Color(0xFFFFF9C4),
              iconColor: const Color(0xFFFBC02D),
              title: 'Statistik',
              subtitle: 'Laporan, akurasi, kecepatan, medali',
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StatistikScreen()));
              },
            ),
            Divider(height: 1, color: Colors.grey.shade100, indent: 70),
            _buildMenuItem(
              icon: Icons.folder,
              iconBg: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1E88E5),
              title: 'Workspace',
              subtitle: 'Switch module or dashboard view',
              trailingText: 'HSE',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Workspace'),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 0.5,
                              ),
                              backgroundColor: const Color(0xFFF5F5F5),
                              body: const _AppTab(),
                            )));
              },
            ),
            Divider(height: 1, color: Colors.grey.shade100, indent: 70),
            _buildMenuItem(
              icon: Icons.settings,
              iconBg: const Color(0xFFF5F5F5),
              iconColor: Colors.grey.shade700,
              title: 'Settings',
              subtitle: 'Bahasa, notifikasi, tampilan awal',
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            _buildSectionHeader('ALAT ADMIN',
                badge: 'CHIEF', badgeColor: const Color(0xFFE65100)),
            _buildMenuItem(
              icon: Icons.people,
              iconBg: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1565C0),
              title: 'User Management',
              subtitle: 'Roles, access, approvals',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UserManagementScreen()));
              },
            ),
            Divider(height: 1, color: Colors.grey.shade100, indent: 70),
            _buildMenuItem(
              icon: Icons.folder_special,
              iconBg: const Color(0xFFFBE9E7),
              iconColor: const Color(0xFFD84315),
              title: 'Kategori Laporan',
              subtitle: 'Kelola TTA, KTA & subkategori',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const KategoriLaporanScreen()));
              },
            ),
            _buildSectionHeader('PLATFORM',
                badge: 'NEZTEK ADMIN', badgeColor: const Color(0xFFD32F2F)),
            _buildMenuItem(
              icon: Icons.admin_panel_settings,
              iconBg: const Color(0xFFE8EAF6),
              iconColor: const Color(0xFF283593),
              title: 'Neztek Admin Panel',
              subtitle: 'Tenants, billing, modules',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NeztekAdminScreen()));
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child:
            Center(child: CircularProgressIndicator(color: Color(0xFF5C38FF))),
      );
    }

    final name = _profileData?.fullName ?? 'No Name';
    final position = _profileData?.position ?? 'Safety Officer';
    final company = _profileData?.company ?? 'PT. BBE';
    final initials = name
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join()
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFF5C38FF),
            backgroundImage: (_profileData?.profilePhoto != null &&
                    _profileData!.profilePhoto!.isNotEmpty)
                ? NetworkImage(_profileData!.profilePhoto!)
                : null,
            child: (_profileData?.profilePhoto == null ||
                    _profileData!.profilePhoto!.isEmpty)
                ? Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text('$position — $company',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Text('User',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6A1B9A),
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Text('Aktif',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? badge, Color? badgeColor}) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  letterSpacing: 1)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: badgeColor, borderRadius: BorderRadius.circular(12)),
              child: Text(badge,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (trailingText != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(trailingText,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w700)),
              ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// APP TAB
// ══════════════════════════════════════════════════════════════════════════════
class _AppTab extends StatelessWidget {
  const _AppTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Aplikasi'),
          _SettingCard(children: [
            _MenuRow(
              icon: Icons.dashboard_outlined,
              iconColor: const Color(0xFF1A56C4),
              label: 'Dashboard Laporan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            _MenuRow(
              icon: Icons.health_and_safety_outlined,
              iconColor: const Color(0xFF4CAF50),
              label: 'Module Plugin',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Module Plugin akan segera hadir')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.8),
        ),
      );
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: children),
      );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}
