import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../services/report_service.dart';
import 'company_management.dart';
import '../services/storage_service.dart';
import 'package:sapahse/main.dart';
import '../widgets/minimal_dropdown.dart';
import '../widgets/app_safe_insets.dart';
import '../utils/ui_utils.dart';
import '../widgets/fab_notched_bottom_bar.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1A56C4);
  static const _orange = Color(0xFFF57C00);

  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<CompanyData> _ownerCompanies = [];
  List<AreaData> _allAreas = [];
  List<_PicUserOption> _picUsers = [];
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _checkRoleAndLoad();
  }

  Future<void> _checkRoleAndLoad() async {
    final user = await StorageService.getUser();
    if (mounted) {
      setState(() {
        _userRole = user?['role']?.toString();
      });
    }
    _loadData();
  }

  bool get _isSuperAdmin =>
      _userRole?.toLowerCase() == 'superadmin' ||
      _userRole?.toLowerCase() == 'super admin';

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        CompanyService.getCompanies(category: 'owner'),
        CompanyService.getAreas(),
      ]);

      List<_PicUserOption> users = [];
      try {
        final reportUsers = await ReportService.getUsers();
        users = reportUsers
            .map((user) => _PicUserOption(
                  id: int.tryParse(user.id) ?? 0,
                  fullName: user.fullName,
                  employeeId: '',
                  department: user.department,
                  isActive: true,
                ))
            .where((user) => user.id > 0 && user.fullName.trim().isNotEmpty)
            .toList();
      } catch (_) {}
      if (users.isEmpty) {
        try {
          final adminResponse =
              await ApiService.get('/admin/users?is_active=true&per_page=100');
          if (adminResponse.success) {
            users = _picUsersFromRaw(adminResponse.data);
          }
        } catch (_) {}
      }
      if (users.isEmpty) {
        try {
          final usersResponse = await AuthService.listUsers();
          if (usersResponse.success) {
            users = _picUsersFromRaw(
              usersResponse.data['data'] ?? usersResponse.data,
            );
          }
        } catch (_) {}
      }
      if (users.isEmpty) {
        try {
          final adminResponse = await ApiService.get('/admin/users?per_page=100');
          if (adminResponse.success) {
            users = _picUsersFromRaw(adminResponse.data);
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _ownerCompanies = results[0] as List<CompanyData>;
          _allAreas = results[1] as List<AreaData>;
          _picUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<_PicUserOption> _picUsersFromRaw(dynamic raw) {
    final list = _rawList(raw);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((map) => _PicUserOption(
              id: map['id'] is int
                  ? map['id'] as int
                  : int.tryParse(map['id']?.toString() ?? '') ?? 0,
              fullName: map['full_name']?.toString() ??
                  map['name']?.toString() ??
                  '',
              employeeId: map['employee_id']?.toString() ?? '',
              department: map['department']?.toString(),
              isActive: map['is_active'] == null ||
                  map['is_active'] == true ||
                  map['is_active'] == 1 ||
                  map['is_active']?.toString() == '1',
            ))
        .where((user) => user.id > 0 && user.fullName.trim().isNotEmpty)
        .toList();
  }

  List<dynamic> _rawList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in const ['data', 'users', 'items', 'results']) {
        final nested = raw[key];
        if (nested is List) return nested;
        if (nested is Map) return _rawList(nested);
      }
      return raw.values.whereType<Map>().toList();
    }
    return const [];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (!isError) {
      UiUtils.showSuccessPopup(context, msg);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  void _navigateToAreaForm(
      {AreaData? area, CompanyData? defaultCompany}) async {
    if (_ownerCompanies.isEmpty) {
      _showSnack(
          'Belum ada perusahaan Owner. Tambahkan di Company Management terlebih dahulu.',
          isError: true);
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AreaFormScreen(
          areaToEdit: area,
          defaultCompany: defaultCompany,
          ownerCompanies: _ownerCompanies,
          picUsers: _picUsers,
        ),
      ),
    );
    if (result is AreaData) {
      _replaceAreaInList(result);
      _showSnack(area == null
          ? 'Lokasi berhasil ditambahkan.'
          : 'Lokasi berhasil diperbarui.');
    } else if (result == true) {
      _loadData();
      _showSnack(area == null
          ? 'Lokasi berhasil ditambahkan.'
          : 'Lokasi berhasil diperbarui.');
    }
  }

  void _replaceAreaInList(AreaData updated) {
    setState(() {
      final index = _allAreas.indexWhere((area) => area.id == updated.id);
      if (index != -1) {
        _allAreas[index] = updated;
      }
    });
  }

  void _removeAreaFromList(int areaId) {
    setState(() {
      _allAreas.removeWhere((area) => area.id == areaId);
    });
  }

  Future<void> _openAreaDetail(AreaData area, CompanyData company) async {
    AreaData currentArea = area;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        CompanyData effectiveCompany() {
          for (final item in _ownerCompanies) {
            if (item.id == currentArea.companyId) {
              return item;
            }
          }
          return company;
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> openEdit() async {
              final currentCompany = effectiveCompany();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _AreaFormScreen(
                    areaToEdit: currentArea,
                    defaultCompany: currentCompany,
                    ownerCompanies: _ownerCompanies,
                    picUsers: _picUsers,
                  ),
                ),
              );
              if (result is AreaData) {
                _replaceAreaInList(result);
                setSheetState(() => currentArea = result);
                _showSnack('Lokasi berhasil diperbarui.');
              }
            }

            Future<void> toggleStatus() async {
              final updated =
                  await CompanyService.toggleAreaStatus(currentArea.id);
              if (updated != null) {
                _replaceAreaInList(updated);
                setSheetState(() => currentArea = updated);
                _showSnack(
                  updated.isActive
                      ? 'Lokasi diaktifkan.'
                      : 'Lokasi dinonaktifkan.',
                );
              } else {
                _showSnack('Gagal mengubah status lokasi.', isError: true);
              }
            }

            Future<void> deleteArea() async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Hapus Lokasi',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  content: Text('Yakin ingin menghapus ${currentArea.name}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );
              if (confirmed == true &&
                  await CompanyService.deleteArea(currentArea.id)) {
                _removeAreaFromList(currentArea.id);
                _showSnack('Lokasi berhasil dihapus.');
                if (Navigator.of(sheetContext).canPop())
                  Navigator.pop(sheetContext);
              } else if (confirmed == true) {
                _showSnack('Gagal menghapus lokasi.', isError: true);
              }
            }

            final picNames = currentArea.picUsers.isNotEmpty
                ? currentArea.picUsers.map((u) => u.displayLabel).toList()
                : (currentArea.picUserName?.trim().isNotEmpty == true
                    ? [currentArea.picUserName!.trim()]
                    : const <String>[]);

            return Container(
              margin: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                AppSafeInsets.sheetBottomPadding(context, base: 20),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: currentArea.isActive
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: currentArea.isActive
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentArea.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                effectiveCompany().name,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _detailSectionInSheet(
                      title: 'Detail Lokasi',
                      children: [
                        _detailRowInSheet(
                            'Kode',
                            (currentArea.code ?? '').isEmpty
                                ? '-'
                                : currentArea.code!),
                        _detailRowInSheet('Status',
                            currentArea.isActive ? 'Aktif' : 'Nonaktif'),
                        _detailRowInSheet('PIC',
                            picNames.isEmpty ? '-' : picNames.join(', ')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _detailSectionInSheet(
                      title: 'PIC Area',
                      children: picNames.isEmpty
                          ? [
                              const Text(
                                'Belum ada PIC yang ditetapkan.',
                                style:
                                    TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ]
                          : [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: picNames
                                    .map((name) => Chip(
                                          label: Text(name,
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          backgroundColor:
                                              const Color(0xFFF8F9FF),
                                        ))
                                    .toList(),
                              ),
                            ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _quickActionInSheet(
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            color: const Color(0xFF1A56C4),
                            onTap: () => openEdit(),
                          ),
                        ),
                        Expanded(
                          child: _quickActionInSheet(
                            icon: Icons.power_settings_new,
                            label: currentArea.isActive ? 'Nonaktif' : 'Aktif',
                            color: currentArea.isActive
                                ? const Color(0xFFF57C00)
                                : const Color(0xFF2E7D32),
                            onTap: () => toggleStatus(),
                          ),
                        ),
                        Expanded(
                          child: _quickActionInSheet(
                            icon: Icons.delete_outline,
                            label: 'Hapus',
                            color: Colors.red,
                            onTap: () => deleteArea(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailSectionInSheet({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRowInSheet(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          const Text(': ', style: TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionInSheet({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    if (index == 4) {
      Navigator.pop(context);
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
      builder: (_) => _LocationFabMenuSheet(
        isSuperAdmin: _isSuperAdmin,
        onAddLocation: () {
          Navigator.pop(context);
          _navigateToAreaForm();
        },
        onRefreshData: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Cari lokasi...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              )
            : const Text('Location Management',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _blue,
          labelColor: _blue,
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Daftar Lokasi'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMainListTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFabMenu,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 30),
      ),
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: FabNotchedBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _LocationNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                currentIndex: 4,
                onTap: _onTabTapped),
            _LocationNavItem(
                icon: Icons.article_outlined,
                label: 'News',
                index: 1,
                currentIndex: 4,
                onTap: _onTabTapped),
            const SizedBox(width: 56),
            _LocationNavItem(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                index: 3,
                currentIndex: 4,
                onTap: _onTabTapped),
            _LocationNavItem(
                icon: Icons.menu,
                label: 'Menu',
                index: 4,
                currentIndex: 4,
                onTap: _onTabTapped),
          ],
        ),
      ),
    );
  }

  Widget _buildMainListTab() {
    final searchLower = _searchQuery.toLowerCase();

    final filteredCompanies = _ownerCompanies.where((company) {
      if (_searchQuery.isEmpty) return true;
      final companyMatch = company.name.toLowerCase().contains(searchLower) ||
          (company.code?.toLowerCase().contains(searchLower) ?? false);
      final areaMatch = _allAreas.any((a) =>
          a.companyId == company.id &&
          a.name.toLowerCase().contains(searchLower));
      return companyMatch || areaMatch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: AppSafeInsets.bottomNavListPadding(context),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 16),
          if (filteredCompanies.isEmpty && _searchQuery.isNotEmpty)
            _buildEmptyStateForSearch()
          else if (_ownerCompanies.isEmpty)
            _buildEmptyState()
          else
            ...filteredCompanies.asMap().entries.map((entry) {
              int idx = entry.key;
              CompanyData company = entry.value;
              Color color = idx % 2 == 0 ? _blue : _orange;

              List<AreaData> companyAreas =
                  _allAreas.where((a) => a.companyId == company.id).toList();

              // If searching and company doesn't match, only show matching areas
              final companyMatch = company.name
                      .toLowerCase()
                      .contains(searchLower) ||
                  (company.code?.toLowerCase().contains(searchLower) ?? false);
              if (_searchQuery.isNotEmpty && !companyMatch) {
                companyAreas = companyAreas
                    .where((a) => a.name.toLowerCase().contains(searchLower))
                    .toList();
              }

              return _buildCategoryCard(company, color, companyAreas);
            }),
          const SizedBox(height: 16),
          _buildGoToCompanyManagementButton(),
        ],
      ),
    );
  }

  Widget _buildEmptyStateForSearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Tidak Ada Hasil',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Lokasi atau perusahaan tidak ditemukan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Daftar lokasi kerja berdasarkan perusahaan owner.',
              style: TextStyle(
                  color: Colors.blue.shade800,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Belum ada Perusahaan Owner',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Silakan tambahkan perusahaan dengan tipe "Owner" di menu Company Management.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
      CompanyData company, Color color, List<AreaData> areas) {
    final bgColor = color.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${company.code ?? 'OWN'} — ${company.name}',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${areas.where((s) => s.isActive).length} lokasi aktif',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down,
                    color: Colors.grey, size: 20),
              ],
            ),
          ),
          // Subcategories
          ...areas.map((area) => _buildSubcategoryItem(area, company)),
          // Add Subcategory Button
          if (_isSuperAdmin)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToAreaForm(defaultCompany: company),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Lokasi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryItem(AreaData area, CompanyData company) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade100),
        InkWell(
          onTap: () => _openAreaDetail(area, company),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.circle,
                    size: 8,
                    color: area.isActive ? Colors.green : Colors.grey.shade300),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(area.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13)),
                      if (area.code != null && area.code!.isNotEmpty)
                        Text(area.code!,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11)),
                      if (area.picUsers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'PIC: ${area.picUsers.map((u) => u.displayLabel).join(', ')}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoToCompanyManagementButton() {
    if (!_isSuperAdmin) return const SizedBox.shrink();
    return InkWell(
      onTap: () {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const CompanyManagementScreen()));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _blue.withValues(alpha: 0.3), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, color: _blue, size: 20),
            SizedBox(width: 8),
            Text('Kelola Owner di Company Management',
                style: TextStyle(
                    color: _blue, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Area Form Screen ────────────────────────────────────────────────────────

class _AreaFormScreen extends StatefulWidget {
  final AreaData? areaToEdit;
  final CompanyData? defaultCompany;
  final List<CompanyData> ownerCompanies;
  final List<_PicUserOption> picUsers;

  const _AreaFormScreen({
    this.areaToEdit,
    this.defaultCompany,
    required this.ownerCompanies,
    required this.picUsers,
  });

  @override
  State<_AreaFormScreen> createState() => _AreaFormScreenState();
}

class _AreaFormScreenState extends State<_AreaFormScreen> {
  static const _blue = Color(0xFF1A56C4);
  late int _selectedCompanyId;
  final Set<int> _selectedPicUserIds = {};
  late List<_PicUserOption> _picUsers;
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  bool _isLoading = false;
  bool _isLoadingPicUsers = false;

  @override
  void initState() {
    super.initState();
    _picUsers = List<_PicUserOption>.from(widget.picUsers);
    _selectedCompanyId = widget.areaToEdit?.companyId ??
        widget.defaultCompany?.id ??
        widget.ownerCompanies.first.id;
    final initialIds = widget.areaToEdit?.picUserIds.isNotEmpty == true
        ? widget.areaToEdit!.picUserIds
        : (widget.areaToEdit?.picUserId != null
            ? [widget.areaToEdit!.picUserId!]
            : <int>[]);
    for (final id in initialIds) {
      _selectedPicUserIds.add(id);
    }
    _nameCtrl = TextEditingController(text: widget.areaToEdit?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.areaToEdit?.code ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Lokasi wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      dynamic result;
      if (widget.areaToEdit != null) {
        result = await CompanyService.updateArea(
          widget.areaToEdit!.id,
          _selectedCompanyId,
          name,
          code: code,
          picUserIds: _selectedPicUserIds.toList(),
        );
      } else {
        result = await CompanyService.createArea(
          _selectedCompanyId,
          name,
          code: code,
          picUserIds: _selectedPicUserIds.toList(),
        );
      }

      if (result != null) {
        if (mounted) Navigator.pop(context, result);
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan data')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.areaToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Lokasi' : 'Tambah Lokasi',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'INDUK PERUSAHAAN',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('MASUK KE *'),
                  const SizedBox(height: 8),
                  _buildDropdown(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'DETAIL LOKASI',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('NAMA LOKASI/AREA *'),
                  const SizedBox(height: 8),
                  _buildTextField(_nameCtrl, hint: 'Contoh: Pit Merdeka'),
                  const SizedBox(height: 16),
                  _buildLabel('KODE LOKASI (OPSIONAL)'),
                  const SizedBox(height: 8),
                  _buildTextField(_codeCtrl,
                      hint: 'Contoh: PIT-M',
                      maxLength: 3,
                      capitalization: TextCapitalization.characters),
                  const SizedBox(height: 16),
                  _buildLabel('PIC / PENANGGUNG JAWAB'),
                  const SizedBox(height: 8),
                  _buildPicPickerField(),
                  if (_selectedPicUserIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedPicUsers
                          .map((u) => Chip(
                                label: Text(u.displayLabel,
                                    style: const TextStyle(fontSize: 12)),
                                onDeleted: () => setState(
                                    () => _selectedPicUserIds.remove(u.id)),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                backgroundColor: _blue.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                side: BorderSide(
                                    color: _blue.withValues(alpha: 0.2)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal',
                      style: TextStyle(
                          color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                    color: Color(0xFFF57F17), fontSize: 13, height: 1.4),
                children: [
                  TextSpan(
                      text:
                          'Setelah disimpan, perubahan akan langsung berlaku pada data '),
                  TextSpan(
                      text: 'Location Management.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey.shade300,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: kMinimalFieldContainerDecoration,
      child: DropdownButtonFormField<int>(
        initialValue: _selectedCompanyId,
        decoration: minimalFieldDecoration(),
        icon: kMinimalDropdownChevron,
        borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
        style: kMinimalDropdownTextStyle,
        items: widget.ownerCompanies
            .map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, style: kMinimalDropdownTextStyle),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selectedCompanyId = v!),
      ),
    );
  }

  List<_PicUserOption> get _selectedPicUsers =>
      _picUsers.where((u) => _selectedPicUserIds.contains(u.id)).toList();

  Widget _buildPicPickerField() {
    final hasSelection = _selectedPicUserIds.isNotEmpty;
    return GestureDetector(
      onTap: _isLoadingPicUsers ? null : _openPicPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.person_add_outlined,
                size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isLoadingPicUsers
                    ? 'Memuat user...'
                    : (hasSelection
                        ? '${_selectedPicUsers.length} PIC terpilih'
                        : 'Ketuk untuk pilih PIC'),
                style: TextStyle(
                  color: hasSelection ? Colors.black87 : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicPicker() async {
    _showPicPicker();
  }

  Future<void> _loadPicUsers() async {
    setState(() => _isLoadingPicUsers = true);
    final users = await _fetchPicUsers();

    if (!mounted) return;
    setState(() {
      _picUsers = users;
      _isLoadingPicUsers = false;
    });
  }

  Future<List<_PicUserOption>> _fetchPicUsers({String search = ''}) async {
    var users = <_PicUserOption>[];
    final searchQuery =
        search.trim().isEmpty ? '' : '?search=${Uri.encodeComponent(search.trim())}';

    try {
      final response = await ApiService.get('/users$searchQuery');
      if (response.success) {
        users = _picUsersFromRaw(response.data['data'] ?? response.data);
      }
    } catch (_) {}

    if (users.isEmpty) {
      try {
        final response = await AuthService.listUsers(search: search.trim());
        if (response.success) {
          users = _picUsersFromRaw(response.data['data'] ?? response.data);
        }
      } catch (_) {}
    }

    try {
      if (users.isEmpty) {
        final reportUsers = await ReportService.getUsers();
        users = reportUsers
            .map((user) => _PicUserOption(
                  id: int.tryParse(user.id) ?? 0,
                  fullName: user.fullName,
                  employeeId: '',
                  department: user.department,
                ))
            .where((user) => user.id > 0 && user.fullName.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {}

    if (users.isEmpty) {
      try {
        final adminQuery = search.trim().isEmpty
            ? '?per_page=100'
            : '?per_page=100&search=${Uri.encodeComponent(search.trim())}';
        final response = await ApiService.get('/admin/users$adminQuery');
        if (response.success) {
          users = _picUsersFromRaw(response.data);
        }
      } catch (_) {}
    }

    if (users.isEmpty) {
      final currentUser = await StorageService.getUser();
      if (currentUser != null) {
        final current = _PicUserOption(
          id: int.tryParse(currentUser['id']?.toString() ?? '') ?? 0,
          fullName: currentUser['full_name']?.toString() ??
              currentUser['name']?.toString() ??
              '',
          employeeId: currentUser['employee_id']?.toString() ?? '',
          department: currentUser['department']?.toString(),
        );
        if (current.id > 0 && current.fullName.trim().isNotEmpty) {
          users = [current];
        }
      }
    }

    final unique = <int, _PicUserOption>{};
    for (final user in users) {
      unique[user.id] = user;
    }
    return unique.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  List<_PicUserOption> _picUsersFromRaw(dynamic raw) {
    final list = _rawList(raw);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((map) => _PicUserOption(
              id: map['id'] is int
                  ? map['id'] as int
                  : int.tryParse(map['id']?.toString() ?? '') ?? 0,
              fullName: map['full_name']?.toString() ??
                  map['name']?.toString() ??
                  '',
              employeeId: map['employee_id']?.toString() ?? '',
              department: map['department']?.toString(),
              isActive: map['is_active'] == null ||
                  map['is_active'] == true ||
                  map['is_active'] == 1 ||
                  map['is_active']?.toString() == '1',
            ))
        .where((user) => user.id > 0 && user.fullName.trim().isNotEmpty)
        .toList();
  }

  List<dynamic> _rawList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in const ['data', 'users', 'items', 'results']) {
        final nested = raw[key];
        if (nested is List) return nested;
        if (nested is Map) return _rawList(nested);
      }
      return raw.values.whereType<Map>().toList();
    }
    return const [];
  }

  void _showPicPicker() {
    String query = '';
    Future<List<_PicUserOption>> usersFuture = _fetchPicUsers();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Pilih PIC Area',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama PIC...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      query = v;
                      usersFuture = _fetchPicUsers(search: query);
                      setSheetState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<_PicUserOption>>(
                    future: usersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(color: _blue),
                        );
                      }

                      final loadedUsers = snapshot.data ?? const <_PicUserOption>[];
                      _picUsers = loadedUsers;

                      return ListView(
                          children: [
                      if (_selectedPicUserIds.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            'TERPILIH',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _selectedPicUsers.map((user) {
                              return Chip(
                                label: Text(user.displayLabel,
                                    style: const TextStyle(fontSize: 12)),
                                onDeleted: () {
                                  setState(() =>
                                      _selectedPicUserIds.remove(user.id));
                                  setSheetState(() {});
                                },
                                deleteIcon: const Icon(Icons.close, size: 14),
                                backgroundColor: _blue.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                side: BorderSide(
                                  color: _blue.withValues(alpha: 0.2),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const Divider(height: 32),
                      ],
                      if (loadedUsers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            'PIC',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...loadedUsers.map((user) {
                          final isSelected =
                              _selectedPicUserIds.contains(user.id);
                          return ListTile(
                            leading: const Icon(Icons.person_outline, size: 20),
                            title: Text(user.fullName,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              [
                                if ((user.department ?? '').isNotEmpty)
                                  user.department!,
                                if (user.employeeId.isNotEmpty) user.employeeId,
                              ].join(' • '),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSelected ? _blue : Colors.grey,
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedPicUserIds.remove(user.id);
                                } else {
                                  _selectedPicUserIds.add(user.id);
                                }
                              });
                              setSheetState(() {});
                            },
                          );
                        }),
                      ],
                      if (loadedUsers.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                const Text('User belum muncul',
                                    style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    usersFuture = _fetchPicUsers(search: query);
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Muat ulang user'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                          ],
                        );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    AppSafeInsets.sheetBottomPadding(context, base: 20),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Selesai',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl,
      {String? hint,
      int? maxLength,
      TextCapitalization capitalization = TextCapitalization.none}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: ctrl,
        maxLength: maxLength,
        textCapitalization: capitalization,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          counterText: "", // Hide the counter for cleaner UI
        ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────
class _PicUserOption {
  final int id;
  final String fullName;
  final String employeeId;
  final String? department;
  final bool isActive;

  const _PicUserOption({
    required this.id,
    required this.fullName,
    required this.employeeId,
    this.department,
    this.isActive = true,
  });

  String get displayLabel {
    final name = fullName.trim().isEmpty ? 'Tanpa nama' : fullName.trim();
    final nik = employeeId.trim();
    if (nik.isEmpty) return name;
    return '$name - $nik';
  }
}

class _LocationNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _LocationNavItem({
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

// ── Menu Tile ─────────────────────────────────────────────────────────────────
class _LocationMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LocationMenuTile({
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
                  borderRadius: BorderRadius.circular(12),
                ),
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

// ── FAB Bottom Sheet ──────────────────────────────────────────────────────────
class _LocationFabMenuSheet extends StatelessWidget {
  final bool isSuperAdmin;
  final VoidCallback onAddLocation;
  final VoidCallback onRefreshData;

  const _LocationFabMenuSheet({
    required this.isSuperAdmin,
    required this.onAddLocation,
    required this.onRefreshData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppSafeInsets.sheetBottomPadding(context, base: 32),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Aksi Lokasi',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          if (isSuperAdmin) ...[
            _LocationMenuTile(
              icon: Icons.add_location_alt_outlined,
              iconBgColor: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1E88E5),
              title: 'Tambah Lokasi Baru',
              subtitle: 'Daftarkan area atau lokasi kerja baru',
              onTap: onAddLocation,
            ),
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          ],
          _LocationMenuTile(
            icon: Icons.refresh_rounded,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Refresh Data',
            subtitle: 'Muat ulang data lokasi terkini',
            onTap: onRefreshData,
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
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
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
