import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/report.dart';
import '../utils/access_permissions.dart';
import 'dashboard_overview_module.dart';
import 'dashboard_report_module.dart';
import 'dashboard_news_module.dart';
import 'dashboard_users_module.dart';
import '../widgets/app_safe_insets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardNavSection {
  final String title;
  final IconData icon;
  final Widget content;

  const _DashboardNavSection({
    required this.title,
    required this.icon,
    required this.content,
  });
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _dashboardPermissionKeys = [
    'dashboard_overview',
    'manage_hazard_reports',
    'manage_inspection_reports',
    'manage_news',
    'manage_users',
  ];

  int _selectedIndex = 0;
  String _userRole = 'Admin';
  bool _isCheckingAccess = true;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final user = await StorageService.getUser();
    if (!mounted) return;

    final role = user?['role']?.toString() ?? 'User';
    final canOpenDashboard = userHasAnyAccess(user, _dashboardPermissionKeys);

    if (!canOpenDashboard) {
      setState(() => _isCheckingAccess = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Akses Ditolak: Anda tidak memiliki izin untuk membuka Dashboard Admin.')),
      );
      return;
    }

    setState(() {
      _currentUser = user;
      _userRole = role;
      _isCheckingAccess = false;
      if (_selectedIndex >= _sections.length) {
        _selectedIndex = 0;
      }
    });
  }

  bool _canAccess(String permissionKey) =>
      userHasAccess(_currentUser, permissionKey);

  List<_DashboardNavSection> get _sections {
    final sections = <_DashboardNavSection>[];

    if (_canAccess('dashboard_overview')) {
      sections.add(
        const _DashboardNavSection(
          title: 'Overview Sistem',
          icon: Icons.dashboard_outlined,
          content: DashboardOverviewModule(
            hazardReports: [],
            inspectionReports: [],
          ),
        ),
      );
    }

    if (_canAccess('manage_hazard_reports')) {
      sections.add(
        const _DashboardNavSection(
          title: 'Manajemen Hazard',
          icon: Icons.warning_amber_rounded,
          content: DashboardReportModule(
            type: ReportType.hazard,
            subtitle: 'Kelola seluruh laporan Hazard yang masuk dari lapangan.',
          ),
        ),
      );
    }

    if (_canAccess('manage_inspection_reports')) {
      sections.add(
        const _DashboardNavSection(
          title: 'Manajemen Inspection',
          icon: Icons.search_outlined,
          content: DashboardReportModule(
            type: ReportType.inspection,
            subtitle: 'Kelola seluruh laporan Inspeksi rutin dari tim.',
          ),
        ),
      );
    }

    if (_canAccess('manage_news')) {
      sections.add(
        const _DashboardNavSection(
          title: 'Berita & Update',
          icon: Icons.article_outlined,
          content: DashboardNewsModule(),
        ),
      );
    }

    if (_canAccess('manage_users')) {
      sections.add(
        const _DashboardNavSection(
          title: 'Pengguna',
          icon: Icons.people_outline,
          content: DashboardUsersModule(),
        ),
      );
    }

    return sections;
  }

  Widget _buildContent() {
    final sections = _sections;
    if (sections.isEmpty) return const SizedBox();
    final selectedIndex =
        _selectedIndex >= sections.length ? 0 : _selectedIndex;
    return sections[selectedIndex].content;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final sections = _sections;
    final selectedIndex = sections.isEmpty || _selectedIndex >= sections.length
        ? 0
        : _selectedIndex;

    if (_isCheckingAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      drawer: isDesktop
          ? null
          : Drawer(child: _buildNavigationMenu(isDrawer: true)),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: Text(
                  sections.isEmpty
                      ? 'Dashboard'
                      : sections[selectedIndex].title,
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Color(0xFF1D4ED8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
      body: Row(
        children: [
          if (isDesktop) _buildNavigationMenu(isDrawer: false),
          Expanded(
            child: SingleChildScrollView(
              padding: AppSafeInsets.pagePadding(
                context,
                left: isDesktop ? 32 : 16,
                top: isDesktop ? 32 : 16,
                right: isDesktop ? 32 : 16,
                bottom: isDesktop ? 32 : 16,
              ),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationMenu({required bool isDrawer}) {
    final sections = _sections;

    return Container(
      width: isDrawer ? null : 280,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                Text('SAPA HSE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue.shade800,
                        letterSpacing: 2.0)),
                const SizedBox(height: 4),
                Text(_userRole.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5)),
              ],
            ),
          ),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('DASHBOARD MENU',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 1.5)),
          ),
          ...List.generate(sections.length, (index) {
            final section = sections[index];
            final isSelected = _selectedIndex == index;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedIndex = index);
                  if (isDrawer) Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1D4ED8)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(section.icon,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF64748B),
                          size: 20),
                      const SizedBox(width: 14),
                      Text(section.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF334155))),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9))),
              child: ListTile(
                onTap: () {
                  if (isDrawer) {
                    // Jika di mobile (drawer), kita tutup drawer dulu, baru pop screen-nya
                    Navigator.pop(context); // Close Drawer
                  }
                  Navigator.pop(context); // Close Dashboard
                },
                leading: const Icon(Icons.logout_rounded,
                    color: Color(0xFFEF4444), size: 20),
                title: const Text('Back to App',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155))),
                dense: true,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
