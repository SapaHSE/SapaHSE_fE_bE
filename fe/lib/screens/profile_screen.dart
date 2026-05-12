import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import '../utils/value_parser.dart';
import 'dashboard_screen.dart';
import 'my_profile.dart';
import 'statistik.dart';
import 'user_management.dart';
import 'violation_management.dart';
import 'kategori_laporan.dart';
import 'settings_screen.dart';
import 'neztek_admin_screen.dart';
import 'company_management.dart';
import 'location_management.dart';
import '../main.dart';
import 'create_hazard_screen.dart';
import 'create_inspection_screen.dart';
import 'qr_scan_screen.dart';
import 'department_management.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  ProfileData? _profileData;
  Map<String, dynamic>? _cachedUser;
  String? _loadError;

  String get _effectiveRole {
    return (parseNullableDisplayName(_profileData?.role) ??
            parseNullableDisplayName(_cachedUser?['role']) ??
            '')
        .toLowerCase();
  }

  String get _effectiveDepartment {
    return (parseNullableDisplayName(_profileData?.department) ??
            parseNullableDisplayName(_cachedUser?['department']) ??
            '')
        .toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _loadCachedUser();
    _loadProfile();
  }

  Future<void> _loadCachedUser() async {
    final user = await StorageService.getUser();
    if (mounted && user != null) {
      setState(() => _cachedUser = user);
    }
  }

  Future<void> _loadProfile() async {
    final result = await ProfileService.getProfile();
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() {
        _profileData = result.data;
        _loadError = null;
        _isLoading = false;
      });
    } else {
      if (kDebugMode) {
        debugPrint(
          '[ProfileScreen] Failed to load profile payload. '
          'errorMessage=${result.errorMessage}, statusCode=${result.statusCode}',
        );
      }
      setState(() {
        _loadError = result.errorMessage ?? 'Gagal memuat profil.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loadError = null;
    });
    await _loadCachedUser();
    await _loadProfile();
  }

  void _onTabTapped(int index) {
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

  void _openFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProfileFabMenuSheet(
        currentIndex: 4,
        onScanQr: () {
          Navigator.pop(context);
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
        },
        onCreateHazard: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateHazardScreen()));
        },
        onCreateInspection: () {
          Navigator.pop(context);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CreateInspectionScreen()));
        },
        onAddCarousel: () {
          Navigator.pop(context);
        },
        onAddNews: () {
          Navigator.pop(context);
        },
        onEditBiodata: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const MyProfileScreen(initialAction: 'edit_biodata')),
          );
        },
        onAddLicense: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const MyProfileScreen(initialAction: 'add_license')),
          );
        },
        onAddCertification: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const MyProfileScreen(initialAction: 'add_certification')),
          );
        },
        onEditMedical: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const MyProfileScreen(initialAction: 'edit_medical')),
          );
        },
      ),
    );
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
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(height: 1, color: Colors.grey.shade200),
              if (_loadError != null) _buildErrorBanner(),
              _buildProfileCard(),
              Divider(height: 1, color: Colors.grey.shade200),
              _buildMenuItem(
                icon: Icons.person,
                iconBg: const Color(0xFFF3E5F5),
                iconColor: const Color(0xFF6A1B9A),
                title: 'Profile',
                subtitle: 'Biodata, licenses, medical, certifications',
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyProfileScreen()));
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
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const StatistikScreen()));
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
                          builder: (context) => Scaffold(
                                appBar: AppBar(
                                  title: const Text(
                                    'Workspace',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18),
                                  ),
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  centerTitle: true,
                                ),
                                backgroundColor: Colors.white,
                                body: _buildWorkspaceTab(),
                                floatingActionButton: FloatingActionButton(
                                  onPressed: _openFabMenu,
                                  backgroundColor: const Color(0xFF1A56C4),
                                  foregroundColor: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 4,
                                  child: const Icon(Icons.add, size: 30),
                                ),
                                extendBody: true,
                                floatingActionButtonLocation:
                                    FloatingActionButtonLocation.centerDocked,
                                bottomNavigationBar: BottomAppBar(
                                  shape: const CircularNotchedRectangle(),
                                  notchMargin: 8,
                                  color: Colors.white,
                                  elevation: 8,
                                  child: SizedBox(
                                    height: 64,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _ProfileNavItem(
                                            icon: Icons.home,
                                            label: 'Home',
                                            index: 0,
                                            currentIndex: 4,
                                            onTap: _onTabTapped),
                                        _ProfileNavItem(
                                            icon: Icons.article_outlined,
                                            label: 'News',
                                            index: 1,
                                            currentIndex: 4,
                                            onTap: _onTabTapped),
                                        const SizedBox(width: 48),
                                        _ProfileNavItem(
                                            icon: Icons.inbox_outlined,
                                            label: 'Inbox',
                                            index: 3,
                                            currentIndex: 4,
                                            onTap: _onTabTapped),
                                        _ProfileNavItem(
                                            icon: Icons.menu,
                                            label: 'Menu',
                                            index: 4,
                                            currentIndex: 4,
                                            onTap: _onTabTapped),
                                      ],
                                    ),
                                  ),
                                ),
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
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()));
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFB28704), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Menampilkan data tersimpan. ${_loadError!}',
              style: const TextStyle(color: Color(0xFF7A5A00), fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _loadError = null;
              });
              _loadProfile();
            },
            child: const Text('Coba Lagi'),
          ),
        ],
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

    final profileName = parseNullableDisplayName(_profileData?.fullName);
    final cachedName = parseNullableDisplayName(
      _cachedUser?['full_name'] ?? _cachedUser?['name'],
    );
    final name = profileName ?? cachedName ?? '-';
    final position = parseNullableDisplayName(_profileData?.position) ??
        parseNullableDisplayName(_cachedUser?['position']) ??
        '-';
    final company = parseNullableDisplayName(_profileData?.company) ??
        parseNullableDisplayName(_cachedUser?['company']) ??
        '-';
    final role = parseNullableDisplayName(_profileData?.role) ??
        parseNullableDisplayName(_cachedUser?['role']);
    final profilePhoto = (_profileData?.profilePhoto?.isNotEmpty ?? false)
        ? _profileData!.profilePhoto
        : parseNullableDisplayName(_cachedUser?['profile_photo']);
    final effectiveIsActive = _profileData?.isActive ??
        parseFlexibleBool(_cachedUser?['is_active'], defaultValue: false);
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
            backgroundImage: (profilePhoto != null && profilePhoto.isNotEmpty)
                ? NetworkImage(profilePhoto)
                : null,
            child: (profilePhoto == null || profilePhoto.isEmpty)
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
                      child: Text(
                          (role == null || role.isEmpty)
                              ? '-'
                              : role.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6A1B9A),
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: effectiveIsActive
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          effectiveIsActive
                              ? 'Karyawan : Aktif'
                              : 'Karyawan : Nonaktif',
                          style: TextStyle(
                              fontSize: 11,
                              color: effectiveIsActive
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFD32F2F),
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
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspaceTab() {
    final role = _effectiveRole;
    final department = _effectiveDepartment;
    final isSuperAdmin = role == 'superadmin' || role == 'super admin';
    final isAdmin = role == 'admin' || isSuperAdmin;
    final canManageViolations =
        isSuperAdmin || (role == 'admin' && department.contains('hse'));

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('APLIKASI'),
          _buildMenuItem(
            icon: Icons.dashboard_outlined,
            iconBg: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1A56C4),
            title: 'Dashboard Laporan',
            subtitle: 'Visualisasi data, grafik & ringkasan insiden',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100, indent: 70),
          _buildMenuItem(
            icon: Icons.health_and_safety_outlined,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF4CAF50),
            title: 'Module Plugin',
            subtitle: 'Fitur tambahan & integrasi sistem',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Module Plugin akan segera hadir')),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('ALAT ADMIN',
                badge: 'CHIEF', badgeColor: const Color(0xFFE65100)),
            _buildMenuItem(
              icon: Icons.people,
              iconBg: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1565C0),
              title: 'User Management',
              subtitle: 'Roles, access, approvals',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100, indent: 70),
            _buildMenuItem(
              icon: Icons.folder_special,
              iconBg: const Color(0xFFFBE9E7),
              iconColor: const Color(0xFFD84315),
              title: 'Kategori Laporan',
              subtitle: 'Daftar TTA, KTA & subkategori',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const KategoriLaporanScreen()),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100, indent: 70),
            _buildMenuItem(
              icon: Icons.business,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              title: 'Company Management',
              subtitle: 'Owner, kontraktor & sub kontraktor',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CompanyManagementScreen()),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100, indent: 70),
            _buildMenuItem(
              icon: Icons.corporate_fare,
              iconBg: const Color(0xFFE8EAF6),
              iconColor: const Color(0xFF3F51B5),
              title: 'Department Management',
              subtitle: 'Daftar departemen perusahaan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DepartmentManagementScreen()),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100, indent: 70),
            _buildMenuItem(
              icon: Icons.location_on,
              iconBg: const Color(0xFFFFF3E0),
              iconColor: const Color(0xFFEF6C00),
              title: 'Location Management',
              subtitle: 'Lokasi kerja tiap perusahaan owner',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LocationManagementScreen()),
              ),
            ),
            if (canManageViolations) ...[
              Divider(height: 1, color: Colors.grey.shade100, indent: 70),
              _buildMenuItem(
                icon: Icons.gavel_outlined,
                iconBg: const Color(0xFFFFEBEE),
                iconColor: const Color(0xFFD32F2F),
                title: 'Pelanggaran User',
                subtitle: 'Catat & kelola pelanggaran karyawan',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ViolationManagementScreen()),
                ),
              ),
            ],
          ],
          if (isSuperAdmin) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('PLATFORM',
                badge: 'NEZTEK ADMIN', badgeColor: const Color(0xFFD32F2F)),
            _buildMenuItem(
              icon: Icons.admin_panel_settings,
              iconBg: const Color(0xFFE8EAF6),
              iconColor: const Color(0xFF283593),
              title: 'Neztek Admin Panel',
              subtitle: 'Tenants, billing, modules',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NeztekAdminScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _ProfileNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
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

class _ProfileFabMenuSheet extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onScanQr;
  final VoidCallback onCreateHazard;
  final VoidCallback onCreateInspection;
  final VoidCallback onAddCarousel;
  final VoidCallback onAddNews;
  final VoidCallback onEditBiodata;
  final VoidCallback onAddLicense;
  final VoidCallback onAddCertification;
  final VoidCallback onEditMedical;

  const _ProfileFabMenuSheet({
    required this.currentIndex,
    required this.onScanQr,
    required this.onCreateHazard,
    required this.onCreateInspection,
    required this.onAddCarousel,
    required this.onAddNews,
    required this.onEditBiodata,
    required this.onAddLicense,
    required this.onAddCertification,
    required this.onEditMedical,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Pilih Aksi',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          _ProfileFabMenuTile(
            icon: Icons.qr_code_scanner,
            iconBgColor: const Color(0xFFEFF4FF),
            iconColor: const Color(0xFF1A56C4),
            title: 'Scan QR Code',
            subtitle: 'Pindai QR untuk verifikasi peralatan',
            onTap: onScanQr,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileFabMenuTile(
            icon: Icons.warning_amber_rounded,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFF44336),
            title: 'Buat Laporan Hazard',
            subtitle: 'Laporkan potensi bahaya di area kerja',
            onTap: onCreateHazard,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileFabMenuTile(
            icon: Icons.search,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            title: 'Buat Laporan Inspeksi',
            subtitle: 'Catat hasil inspeksi rutin area kerja',
            onTap: onCreateInspection,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileFabMenuTile(
            icon: Icons.person_outline,
            iconBgColor: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF8E24AA),
            title: 'Edit Biodata',
            subtitle: 'Perbarui nomor telepon & email',
            onTap: onEditBiodata,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileFabMenuTile(
            icon: Icons.badge_outlined,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1E88E5),
            title: 'Tambah Lisensi',
            subtitle: 'Tambahkan SIM/SIO',
            onTap: onAddLicense,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileFabMenuTile(
            icon: Icons.workspace_premium_outlined,
            iconBgColor: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFEF6C00),
            title: 'Tambah Sertifikat',
            subtitle: 'Tambahkan sertifikasi keahlian',
            onTap: onAddCertification,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileFabMenuTile(
            icon: Icons.medical_services_outlined,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFE53935),
            title: 'Edit Data Medis',
            subtitle: 'Perbarui info kesehatan & alergi',
            onTap: onEditMedical,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200)),
                ),
                child: const Text('Batal', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFabMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileFabMenuTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}
