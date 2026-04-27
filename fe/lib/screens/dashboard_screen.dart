import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/report.dart';
import 'dashboard_overview_module.dart';
import 'dashboard_report_module.dart';
import 'dashboard_news_module.dart';
import 'dashboard_users_module.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _userRole = 'Admin';

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final user = await StorageService.getUser();
    if (user != null && mounted) {
      final role = user['role'] ?? 'User';
      if (role.toLowerCase() == 'user') {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Akses Ditolak: Anda tidak memiliki izin untuk membuka Dashboard Admin.')),
        );
      } else {
        setState(() => _userRole = role);
      }
    }
  }

  bool get _canSeeUsers =>
      _userRole.toLowerCase() == 'super admin' ||
      _userRole.toLowerCase() == 'superadmin';

  List<String> get _sections {
    final list = [
      'Overview Sistem',
      'Manajemen Hazard',
      'Manajemen Inspection',
      'Berita & Update',
    ];
    if (_canSeeUsers) list.add('Pengguna');
    return list;
  }

  List<IconData> get _sectionIcons {
    final list = [
      Icons.dashboard_outlined,
      Icons.warning_amber_rounded,
      Icons.search_outlined,
      Icons.article_outlined,
    ];
    if (_canSeeUsers) list.add(Icons.people_outline);
    return list;
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardOverviewModule(
            hazardReports: [], inspectionReports: []);
      case 1:
        return const DashboardReportModule(
          type: ReportType.hazard,
          subtitle: 'Kelola seluruh laporan Hazard yang masuk dari lapangan.',
        );
      case 2:
        return const DashboardReportModule(
          type: ReportType.inspection,
          subtitle: 'Kelola seluruh laporan Inspeksi rutin dari tim.',
        );
      case 3:
        return const DashboardNewsModule();
      case 4:
        if (_canSeeUsers) return const DashboardUsersModule();
        return const SizedBox();
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

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
              title: Text(_sections[_selectedIndex],
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
              padding: EdgeInsets.all(isDesktop ? 32 : 16),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationMenu({required bool isDrawer}) {
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
          ...List.generate(_sections.length, (index) {
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
                      Icon(_sectionIcons[index],
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF64748B),
                          size: 20),
                      const SizedBox(width: 14),
                      Text(_sections[index],
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
