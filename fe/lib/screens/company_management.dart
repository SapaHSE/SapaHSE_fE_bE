import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/ui_utils.dart';
import '../models/company_model.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../services/storage_service.dart';
import 'package:sapahse/main.dart';
import '../widgets/minimal_dropdown.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/fab_notched_bottom_bar.dart';

bool _isSvgPath(String value) {
  final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
  return path.endsWith('.svg');
}

class CompanyManagementScreen extends StatefulWidget {
  const CompanyManagementScreen({super.key});

  @override
  State<CompanyManagementScreen> createState() =>
      _CompanyManagementScreenState();
}

class _CompanyManagementScreenState extends State<CompanyManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1A56C4);
  static const _red = Color(0xFFD32F2F);
  static const _orange = Color(0xFFF57C00);

  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<CompanyData> _allCompanies = [];
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
      final companies = await CompanyService.getCompanies();
      if (mounted) {
        setState(() {
          _allCompanies = companies;
          if (!silent) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          if (!silent) {
            _isLoading = false;
          }
        });
      }
    }
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

  void _navigateToCompanyForm(
      {CompanyData? company, String? defaultCategory}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CompanyFormScreen(
          companyToEdit: company,
          defaultCategory: defaultCategory,
        ),
      ),
    );
    if (result == true) {
      _loadData();
      _showSnack(company == null
          ? 'Company berhasil ditambahkan.'
          : 'Company berhasil diperbarui.');
    }
  }

  void _replaceCompanyInList(CompanyData updated) {
    setState(() {
      final index =
          _allCompanies.indexWhere((company) => company.id == updated.id);
      if (index != -1) {
        _allCompanies[index] = updated;
      }
    });
  }

  void _removeCompanyFromList(int companyId) {
    setState(() {
      _allCompanies.removeWhere((company) => company.id == companyId);
    });
  }

  Future<void> _openCompanyDetail(CompanyData company) async {
    CompanyData currentCompany = company;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> openEdit() async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _CompanyFormScreen(companyToEdit: currentCompany),
                ),
              );
              if (result == true) {
                await _loadData(silent: true);
                final updated = _allCompanies.firstWhere(
                  (item) => item.id == currentCompany.id,
                  orElse: () => currentCompany,
                );
                setSheetState(() => currentCompany = updated);
                _showSnack('Company berhasil diperbarui.');
              }
            }

            Future<void> toggleStatus() async {
              try {
                await CompanyService.toggleCompanyStatus(currentCompany.id);
                final updated = CompanyData(
                  id: currentCompany.id,
                  name: currentCompany.name,
                  code: currentCompany.code,
                  logoUrl: currentCompany.logoUrl,
                  kttSignatureUrl: currentCompany.kttSignatureUrl,
                  companyStampUrl: currentCompany.companyStampUrl,
                  kttUserId: currentCompany.kttUserId,
                  kttUser: currentCompany.kttUser,
                  emergencyNumber: currentCompany.emergencyNumber,
                  ertFreq: currentCompany.ertFreq,
                  radioLabel: currentCompany.radioLabel,
                  radioChannel: currentCompany.radioChannel,
                  radioFrequency: currentCompany.radioFrequency,
                  category: currentCompany.category,
                  isActive: !currentCompany.isActive,
                );
                _replaceCompanyInList(updated);
                setSheetState(() => currentCompany = updated);
                _showSnack(updated.isActive
                    ? 'Company diaktifkan.'
                    : 'Company dinonaktifkan.');
              } catch (e) {
                _showSnack(e.toString(), isError: true);
              }
            }

            Future<void> deleteCompany() async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    'Hapus Company',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  content: Text('Yakin ingin menghapus ${currentCompany.name}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;

              try {
                await CompanyService.deleteCompany(currentCompany.id);
                _removeCompanyFromList(currentCompany.id);
                _showSnack('Company berhasil dihapus.');
                if (!sheetContext.mounted) return;
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.pop(sheetContext);
                }
              } catch (e) {
                _showSnack(e.toString(), isError: true);
              }
            }

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
                        _buildCompanyLogo(currentCompany),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentCompany.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _companyCategoryLabel(currentCompany.category),
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
                      title: 'Detail Company',
                      children: [
                        _detailRowInSheet(
                          'Kode',
                          (currentCompany.code ?? '').trim().isEmpty
                              ? '-'
                              : currentCompany.code!.trim(),
                        ),
                        _detailRowInSheet(
                          'Status',
                          currentCompany.isActive ? 'Aktif' : 'Nonaktif',
                        ),
                        _detailRowInSheet(
                          'Kategori',
                          _companyCategoryLabel(currentCompany.category),
                        ),
                        _detailRowInSheet(
                          'KTT',
                          currentCompany.kttDisplayName.isEmpty
                              ? '-'
                              : currentCompany.kttDisplayName,
                        ),
                        _detailRowInSheet(
                          'Emergency',
                          (currentCompany.emergencyNumber ?? '').trim().isEmpty
                              ? '-'
                              : currentCompany.emergencyNumber!.trim(),
                        ),
                        _detailRowInSheet(
                          'ERT',
                          (currentCompany.ertFreq ?? '').trim().isEmpty
                              ? '-'
                              : currentCompany.ertFreq!.trim(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_isSuperAdmin)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _quickActionInSheet(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              color: _blue,
                              onTap: () => openEdit(),
                            ),
                          ),
                          Expanded(
                            child: _quickActionInSheet(
                              icon: Icons.power_settings_new,
                              label:
                                  currentCompany.isActive ? 'Nonaktif' : 'Aktif',
                              color: currentCompany.isActive
                                  ? _orange
                                  : const Color(0xFF2E7D32),
                              onTap: () => toggleStatus(),
                            ),
                          ),
                          Expanded(
                            child: _quickActionInSheet(
                              icon: Icons.delete_outline,
                              label: 'Hapus',
                              color: _red,
                              onTap: () => deleteCompany(),
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
      builder: (_) => _CompanyFabMenuSheet(
        isSuperAdmin: _isSuperAdmin,
        onAddCompany: () {
          Navigator.pop(context);
          _navigateToCompanyForm();
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
                  hintText: 'Cari company...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              )
            : const Text('Company Management',
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
            Tab(text: 'Daftar Company'),
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
            _CompanyNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                currentIndex: 4,
                onTap: _onTabTapped),
            _CompanyNavItem(
                icon: Icons.article_outlined,
                label: 'News',
                index: 1,
                currentIndex: 4,
                onTap: _onTabTapped),
            const SizedBox(width: 56),
            _CompanyNavItem(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                index: 3,
                currentIndex: 4,
                onTap: _onTabTapped),
            _CompanyNavItem(
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
    final filtered = _allCompanies.where((c) {
      if (_searchQuery.isEmpty) return true;
      final searchLower = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(searchLower) ||
          (c.code?.toLowerCase().contains(searchLower) ?? false) ||
          c.kttDisplayName.toLowerCase().contains(searchLower) ||
          (c.emergencyNumber?.toLowerCase().contains(searchLower) ?? false) ||
          (c.ertFreq?.toLowerCase().contains(searchLower) ?? false) ||
          (c.radioLabel?.toLowerCase().contains(searchLower) ?? false) ||
          (c.radioChannel?.toLowerCase().contains(searchLower) ?? false) ||
          (c.radioFrequency?.toLowerCase().contains(searchLower) ?? false);
    }).toList();

    // Group companies by category
    final owners = filtered.where((c) => c.category == 'owner').toList();
    final contractors = filtered
        .where((c) => c.category == 'contractor' || c.category == 'kontraktor')
        .toList();
    final subcontraktors = filtered
        .where((c) =>
            c.category == 'sub contractor' || c.category == 'subkontraktor')
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: AppSafeInsets.bottomNavListPadding(context),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 16),
          _buildCategoryCard('Owner', 'OWN', _blue, owners, 'owner'),
          _buildCategoryCard(
              'Contractor', 'CON', _red, contractors, 'kontraktor'),
          _buildCategoryCard('Sub Contractor', 'SUB', _orange, subcontraktors,
              'subkontraktor'),
        ],
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
              'Daftar tipe company yang ada dalam sistem.',
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

  Widget _buildCategoryCard(String title, String code, Color color,
      List<CompanyData> subs, String defaultCategory) {
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
                        '$code — $title',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${subs.where((s) => s.isActive).length} company aktif',
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
          ...subs.map((sub) => _buildSubcategoryItem(sub)),
          // Add Subcategory Button
          if (_isSuperAdmin)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _navigateToCompanyForm(defaultCategory: defaultCategory),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Tambah $title'),
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

  Widget _buildSubcategoryItem(CompanyData sub) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade100),
        InkWell(
          onTap: () => _openCompanyDetail(sub),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildCompanyLogo(sub),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13)),
                      if (sub.code != null && sub.code!.isNotEmpty)
                        Text(sub.code!,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11)),
                      if (sub.kttDisplayName.isNotEmpty)
                        Text('KTT: ${sub.kttDisplayName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11)),
                      if ((sub.emergencyNumber ?? '').trim().isNotEmpty ||
                          (sub.ertFreq ?? '').trim().isNotEmpty)
                        Text(
                          [
                            if ((sub.emergencyNumber ?? '').trim().isNotEmpty)
                              'Emergency: ${sub.emergencyNumber!.trim()}',
                            if ((sub.ertFreq ?? '').trim().isNotEmpty)
                              'ERT: ${sub.ertFreq!.trim()}',
                          ].join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 11),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
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

  String _companyCategoryLabel(String category) {
    switch (category) {
      case 'owner':
        return 'Owner';
      case 'kontraktor':
      case 'contractor':
        return 'Contractor';
      case 'subkontraktor':
      case 'sub contractor':
        return 'Sub Contractor';
      default:
        return category;
    }
  }

  Widget _buildCompanyLogo(CompanyData company) {
    final logoUrl = company.logoUrl?.trim() ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0F7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: logoUrl.isNotEmpty
              ? (_isSvgPath(logoUrl)
                  ? SvgPicture.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      placeholderBuilder: (_) => _companyInitial(company),
                    )
                  : Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _companyInitial(company),
                    ))
              : _companyInitial(company),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: company.isActive ? Colors.green : Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _companyInitial(CompanyData company) {
    final text = (company.code?.trim().isNotEmpty == true
            ? company.code!.trim()
            : company.name
                .trim()
                .split(RegExp(r'\s+'))
                .where((e) => e.isNotEmpty)
                .take(2)
                .map((e) => e[0])
                .join())
        .toUpperCase();
    return Center(
      child: Text(
        text.isEmpty ? '?' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _blue,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  static bool _isSvgPath(String value) {
    final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
    return path.endsWith('.svg');
  }
}

// ── Company Form Screen ─────────────────────────────────────────────────────

class _CompanyFormScreen extends StatefulWidget {
  final CompanyData? companyToEdit;
  final String? defaultCategory;

  const _CompanyFormScreen({this.companyToEdit, this.defaultCategory});

  @override
  State<_CompanyFormScreen> createState() => _CompanyFormScreenState();
}

enum _CompanyImageType { logo, kttSignature, companyStamp }

class _CompanyFormScreenState extends State<_CompanyFormScreen> {
  static const _blue = Color(0xFF1A56C4);
  late String _category;
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _emergencyNumberCtrl;
  late TextEditingController _ertFreqCtrl;
  late TextEditingController _radioLabelCtrl;
  late TextEditingController _radioChannelCtrl;
  late TextEditingController _radioFrequencyCtrl;
  String? _logoUrl;
  String? _kttSignatureUrl;
  String? _companyStampUrl;
  XFile? _logoImageFile;
  XFile? _kttSignatureImageFile;
  XFile? _companyStampImageFile;
  bool _clearLogo = false;
  bool _clearKttSignature = false;
  bool _clearCompanyStamp = false;
  String? _selectedKttUserId;
  _KttUserOption? _selectedKttUser;
  bool _isLoading = false;
  bool _isLoadingKtt = false;

  @override
  void initState() {
    super.initState();
    String rawCategory =
        widget.companyToEdit?.category ?? widget.defaultCategory ?? 'owner';
    // Normalize Indonesian terms to English for standardized logic and dropdown matching
    if (rawCategory == 'contractor') {
      _category = 'kontraktor';
    } else if (rawCategory == 'sub contractor') {
      _category = 'subkontraktor';
    } else {
      _category = rawCategory;
    }

    _nameCtrl = TextEditingController(text: widget.companyToEdit?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.companyToEdit?.code ?? '');
    _logoUrl = widget.companyToEdit?.logoUrl;
    _kttSignatureUrl = widget.companyToEdit?.kttSignatureUrl;
    _companyStampUrl = widget.companyToEdit?.companyStampUrl;
    _emergencyNumberCtrl =
        TextEditingController(text: widget.companyToEdit?.emergencyNumber ?? '');
    _ertFreqCtrl =
        TextEditingController(text: widget.companyToEdit?.ertFreq ?? '');
    _radioLabelCtrl =
        TextEditingController(text: widget.companyToEdit?.radioLabel ?? '');
    _radioChannelCtrl =
        TextEditingController(text: widget.companyToEdit?.radioChannel ?? '');
    _radioFrequencyCtrl =
        TextEditingController(text: widget.companyToEdit?.radioFrequency ?? '');
    _selectedKttUserId = widget.companyToEdit?.kttUserId;
    final kttUser = widget.companyToEdit?.kttUser;
    if (kttUser != null) {
      _selectedKttUser = _KttUserOption.fromCompanyKttUser(kttUser);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _emergencyNumberCtrl.dispose();
    _ertFreqCtrl.dispose();
    _radioLabelCtrl.dispose();
    _radioChannelCtrl.dispose();
    _radioFrequencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final logoUrl = _clearLogo ? '' : (_logoUrl ?? '');
    final kttSignatureUrl =
        _clearKttSignature ? '' : (_kttSignatureUrl ?? '');
    final companyStampUrl =
        _clearCompanyStamp ? '' : (_companyStampUrl ?? '');
    final emergencyNumber = _emergencyNumberCtrl.text.trim();
    final ertFreq = _ertFreqCtrl.text.trim();
    final radioLabel = _radioLabelCtrl.text.trim();
    final radioChannel = _radioChannelCtrl.text.trim();
    final radioFrequency = _radioFrequencyCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Company wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      dynamic result;
      if (widget.companyToEdit != null) {
        result = await CompanyService.updateCompany(
          widget.companyToEdit!.id,
          name,
          _category,
          code: code,
          logoUrl: logoUrl,
          logoImagePath: _logoImageFile?.path,
          kttSignatureUrl: kttSignatureUrl,
          kttSignatureImagePath: _kttSignatureImageFile?.path,
          companyStampUrl: companyStampUrl,
          companyStampImagePath: _companyStampImageFile?.path,
          kttUserId: _selectedKttUserId,
          emergencyNumber: emergencyNumber,
          ertFreq: ertFreq,
          radioLabel: radioLabel,
          radioChannel: radioChannel,
          radioFrequency: radioFrequency,
        );
      } else {
        result = await CompanyService.createCompany(
          name,
          _category,
          code: code,
          logoUrl: logoUrl,
          logoImagePath: _logoImageFile?.path,
          kttSignatureUrl: kttSignatureUrl,
          kttSignatureImagePath: _kttSignatureImageFile?.path,
          companyStampUrl: companyStampUrl,
          companyStampImagePath: _companyStampImageFile?.path,
          kttUserId: _selectedKttUserId,
          emergencyNumber: emergencyNumber,
          ertFreq: ertFreq,
          radioLabel: radioLabel,
          radioChannel: radioChannel,
          radioFrequency: radioFrequency,
        );
      }

      if (result != null) {
        if (!mounted) return;
        await UiUtils.showSuccessPopup(context, 'Data berhasil disimpan');
        if (mounted) Navigator.pop(context, true);
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
    final isEdit = widget.companyToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Company' : 'Tambah Company',
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
              title: 'TIPE COMPANY',
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
              title: 'DETAIL COMPANY',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('NAMA COMPANY *'),
                  const SizedBox(height: 8),
                  _buildTextField(_nameCtrl,
                      hint: 'Contoh: PT Bukit Baiduri Energi'),
                  const SizedBox(height: 16),
                  _buildLabel('KODE (OPSIONAL)'),
                  const SizedBox(height: 8),
                  _buildTextField(_codeCtrl,
                      hint: 'Contoh: BBE',
                      maxLength: 50,
                      capitalization: TextCapitalization.characters),
                  const SizedBox(height: 16),
                  _buildLabel('LOGO COMPANY'),
                  const SizedBox(height: 8),
                  _buildLogoPicker(),
                  const SizedBox(height: 16),
                  _buildLabel('TTD KTT'),
                  const SizedBox(height: 8),
                  _buildImagePicker(
                    type: _CompanyImageType.kttSignature,
                    label: 'TTD KTT',
                    aspectRatio: 4,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('STAMP PERUSAHAAN'),
                  const SizedBox(height: 8),
                  _buildImagePicker(
                    type: _CompanyImageType.companyStamp,
                    label: 'Stamp perusahaan',
                    aspectRatio: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('KEPALA TEKNIK TAMBANG'),
                  const SizedBox(height: 8),
                  _buildKttPicker(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'KONTAK & RADIO',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('EMERGENCY NUMBER'),
                  const SizedBox(height: 8),
                  _buildTextField(_emergencyNumberCtrl,
                      hint: 'Contoh: 0541-123456',
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildLabel('ERT FREQ'),
                  const SizedBox(height: 8),
                  _buildTextField(_ertFreqCtrl,
                      hint: 'Contoh: CH 1 / 155.000 MHz'),
                  const SizedBox(height: 16),
                  _buildLabel('RADIO LABEL'),
                  const SizedBox(height: 8),
                  _buildTextField(_radioLabelCtrl, hint: 'Contoh: ERT'),
                  const SizedBox(height: 16),
                  _buildLabel('RADIO CHANNEL'),
                  const SizedBox(height: 8),
                  _buildTextField(_radioChannelCtrl, hint: 'Contoh: CH 1'),
                  const SizedBox(height: 16),
                  _buildLabel('RADIO FREKUENSI'),
                  const SizedBox(height: 8),
                  _buildTextField(_radioFrequencyCtrl,
                      hint: 'Contoh: 155.000 MHz'),
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
                      text: 'Company Management.',
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
      child: DropdownButtonFormField<String>(
        initialValue: _category,
        icon: kMinimalDropdownChevron,
        borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
        style: kMinimalDropdownTextStyle,
        decoration: minimalFieldDecoration(),
        items: const [
          DropdownMenuItem(
              value: 'owner',
              child: Text('Owner', style: kMinimalDropdownTextStyle)),
          DropdownMenuItem(
              value: 'kontraktor',
              child: Text('Contractor', style: kMinimalDropdownTextStyle)),
          DropdownMenuItem(
              value: 'subkontraktor',
              child: Text('Sub Contractor', style: kMinimalDropdownTextStyle)),
        ],
        onChanged: (v) => setState(() {
          _category = v!;
          _selectedKttUserId = null;
          _selectedKttUser = null;
        }),
      ),
    );
  }

  Widget _buildLogoPicker() {
    final hasLogo =
        _logoImageFile != null || (!_clearLogo && (_logoUrl ?? '').isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3,
            child: InkWell(
              onTap: _isLoading ? null : _showLogoOptions,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildLogoPreview(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showLogoOptions,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(hasLogo ? 'Ganti Logo' : 'Pilih Logo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: BorderSide(color: _blue.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (hasLogo) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _isLoading ? null : _clearSelectedLogo,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Hapus logo',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker({
    required _CompanyImageType type,
    required String label,
    required double aspectRatio,
  }) {
    final hasImage = _imageFileFor(type) != null ||
        (!_isImageCleared(type) && (_imageUrlFor(type) ?? '').isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: InkWell(
              onTap: _isLoading ? null : () => _showImageOptions(type, label),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildImagePreview(type, label),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _showImageOptions(type, label),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(hasImage ? 'Ganti $label' : 'Pilih $label'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: BorderSide(color: _blue.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _isLoading ? null : () => _clearSelectedImage(type),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Hapus $label',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPreview() {
    final imageFile = _logoImageFile;
    if (imageFile != null) {
      return FutureBuilder(
        future: imageFile.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final bytes = snapshot.data!;
          return _isSvgPath(imageFile.path)
              ? SvgPicture.memory(bytes, fit: BoxFit.contain)
              : Image.memory(bytes, fit: BoxFit.contain);
        },
      );
    }

    final logoUrl = _clearLogo ? '' : (_logoUrl?.trim() ?? '');
    if (logoUrl.isNotEmpty) {
      return _isSvgPath(logoUrl)
          ? SvgPicture.network(
              logoUrl,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => _emptyLogoPreview(),
            )
          : Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _emptyLogoPreview(),
            );
    }

    return _emptyLogoPreview();
  }

  Widget _buildImagePreview(_CompanyImageType type, String label) {
    final imageFile = _imageFileFor(type);
    if (imageFile != null) {
      return FutureBuilder(
        future: imageFile.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final bytes = snapshot.data!;
          return _isSvgPath(imageFile.path)
              ? SvgPicture.memory(bytes, fit: BoxFit.contain)
              : Image.memory(bytes, fit: BoxFit.contain);
        },
      );
    }

    final imageUrl = _isImageCleared(type) ? '' : (_imageUrlFor(type) ?? '');
    if (imageUrl.trim().isNotEmpty) {
      return _isSvgPath(imageUrl)
          ? SvgPicture.network(
              imageUrl,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => _emptyImagePreview(label),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _emptyImagePreview(label),
            );
    }

    return _emptyImagePreview(label);
  }

  Widget _emptyImagePreview(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              color: Colors.grey.shade500, size: 28),
          const SizedBox(height: 6),
          Text(
            'Upload $label',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _emptyLogoPreview() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              color: Colors.grey.shade500, size: 30),
          const SizedBox(height: 6),
          Text(
            'Upload logo',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _clearSelectedLogo() {
    setState(() {
      _logoImageFile = null;
      _logoUrl = null;
      _clearLogo = true;
    });
  }

  void _clearSelectedImage(_CompanyImageType type) {
    if (type == _CompanyImageType.logo) {
      _clearSelectedLogo();
      return;
    }

    setState(() {
      switch (type) {
        case _CompanyImageType.logo:
          return;
        case _CompanyImageType.kttSignature:
          _kttSignatureImageFile = null;
          _kttSignatureUrl = null;
          _clearKttSignature = true;
          return;
        case _CompanyImageType.companyStamp:
          _companyStampImageFile = null;
          _companyStampUrl = null;
          _clearCompanyStamp = true;
          return;
      }
    });
  }

  void _showLogoOptions() {
    if (kIsWeb) {
      _pickLogoFromSource(ImageSource.gallery);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          0,
          20,
          0,
          AppSafeInsets.sheetBottomPadding(ctx, base: 20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Sumber Logo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _blue),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickLogoFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _blue),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickLogoFromSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImageOptions(_CompanyImageType type, String label) {
    if (kIsWeb) {
      _pickImageFromSource(type, ImageSource.gallery);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          0,
          20,
          0,
          AppSafeInsets.sheetBottomPadding(ctx, base: 20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pilih Sumber $label',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _blue),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageFromSource(type, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _blue),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageFromSource(type, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLogoFromSource(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;

      if (!mounted) return;
      setState(() {
        _logoImageFile = picked;
        _clearLogo = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih logo: $e')),
      );
    }
  }

  Future<void> _pickImageFromSource(
    _CompanyImageType type,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;

      if (!mounted) return;
      setState(() {
        switch (type) {
          case _CompanyImageType.logo:
            _logoImageFile = picked;
            _clearLogo = false;
            return;
          case _CompanyImageType.kttSignature:
            _kttSignatureImageFile = picked;
            _clearKttSignature = false;
            return;
          case _CompanyImageType.companyStamp:
            _companyStampImageFile = picked;
            _clearCompanyStamp = false;
            return;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e')),
      );
    }
  }

  XFile? _imageFileFor(_CompanyImageType type) {
    switch (type) {
      case _CompanyImageType.logo:
        return _logoImageFile;
      case _CompanyImageType.kttSignature:
        return _kttSignatureImageFile;
      case _CompanyImageType.companyStamp:
        return _companyStampImageFile;
    }
  }

  String? _imageUrlFor(_CompanyImageType type) {
    switch (type) {
      case _CompanyImageType.logo:
        return _logoUrl;
      case _CompanyImageType.kttSignature:
        return _kttSignatureUrl;
      case _CompanyImageType.companyStamp:
        return _companyStampUrl;
    }
  }

  bool _isImageCleared(_CompanyImageType type) {
    switch (type) {
      case _CompanyImageType.logo:
        return _clearLogo;
      case _CompanyImageType.kttSignature:
        return _clearKttSignature;
      case _CompanyImageType.companyStamp:
        return _clearCompanyStamp;
    }
  }

  Widget _buildKttPicker() {
    final selected = _selectedKttUser;
    final hasSelection = selected != null;

    return InkWell(
      onTap: _isLoadingKtt ? null : _showKttPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.engineering_outlined,
                color: _isLoadingKtt ? Colors.grey.shade400 : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isLoadingKtt
                    ? 'Memuat user...'
                    : (hasSelection
                        ? selected.displayLabel
                        : 'Ketuk untuk pilih KTT'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasSelection ? Colors.black87 : Colors.grey.shade500,
                  fontSize: 14,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (hasSelection)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.grey.shade500,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() {
                  _selectedKttUserId = null;
                  _selectedKttUser = null;
                }),
              )
            else
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _showKttPicker() async {
    final companyName = _nameCtrl.text.trim();
    if (companyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama company terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoadingKtt = true);
    List<_KttUserOption> users = [];
    try {
      final response = await AuthService.listUsers(
        companyName: companyName,
        companyCategory: _category,
      );
      if (response.success && response.data['data'] is List) {
        users = (response.data['data'] as List)
            .whereType<Map>()
            .map((item) =>
                _KttUserOption.fromJson(Map<String, dynamic>.from(item)))
            .where((user) => user.id.isNotEmpty)
            .toList();
      } else {
        throw Exception(response.errorMessage ?? 'Gagal memuat user');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat user: $e')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isLoadingKtt = false);
    }

    if (!mounted) return;
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final q = query.toLowerCase();
          final filteredUsers = users
              .where((user) =>
                  user.fullName.toLowerCase().contains(q) ||
                  user.employeeId.toLowerCase().contains(q) ||
                  (user.department?.toLowerCase().contains(q) ?? false))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
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
                    'Pilih Kepala Teknik Tambang',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau NIK...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (_selectedKttUserId != null)
                        ListTile(
                          leading:
                              const Icon(Icons.person_remove_outlined, size: 20),
                          title: const Text('Kosongkan pilihan',
                              style: TextStyle(fontSize: 14)),
                          onTap: () {
                            setState(() {
                              _selectedKttUserId = null;
                              _selectedKttUser = null;
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      if (filteredUsers.isNotEmpty)
                        ...filteredUsers.map((user) {
                          final isSelected = _selectedKttUserId == user.id;
                          return ListTile(
                            leading:
                                const Icon(Icons.person_outline, size: 20),
                            title: Text(user.fullName,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              [
                                if (user.employeeId.isNotEmpty) user.employeeId,
                                if ((user.department ?? '').isNotEmpty)
                                  user.department!,
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
                                _selectedKttUserId = user.id;
                                _selectedKttUser = user;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        })
                      else
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              'Tidak ada user aktif untuk company ini',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
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
      TextCapitalization capitalization = TextCapitalization.none,
      TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: ctrl,
        maxLength: maxLength,
        keyboardType: keyboardType,
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

class _KttUserOption {
  final String id;
  final String fullName;
  final String employeeId;
  final String? department;
  final String? position;
  final String? jabatan;

  const _KttUserOption({
    required this.id,
    required this.fullName,
    required this.employeeId,
    this.department,
    this.position,
    this.jabatan,
  });

  factory _KttUserOption.fromJson(Map<String, dynamic> json) {
    return _KttUserOption(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      department: json['department']?.toString(),
      position: json['position']?.toString(),
      jabatan: json['jabatan']?.toString(),
    );
  }

  factory _KttUserOption.fromCompanyKttUser(CompanyKttUserData user) {
    return _KttUserOption(
      id: user.id,
      fullName: user.fullName,
      employeeId: user.employeeId ?? '',
      department: user.department,
      position: user.position,
      jabatan: user.jabatan,
    );
  }

  String get displayLabel {
    final name = fullName.trim().isEmpty ? 'Tanpa nama' : fullName.trim();
    final nik = employeeId.trim();
    return nik.isEmpty ? name : '$name - $nik';
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────
class _CompanyNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _CompanyNavItem({
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
class _CompanyMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CompanyMenuTile({
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
class _CompanyFabMenuSheet extends StatelessWidget {
  final bool isSuperAdmin;
  final VoidCallback onAddCompany;
  final VoidCallback onRefreshData;

  const _CompanyFabMenuSheet({
    required this.isSuperAdmin,
    required this.onAddCompany,
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
              'Aksi Company',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          if (isSuperAdmin) ...[
            _CompanyMenuTile(
              icon: Icons.business_outlined,
              iconBgColor: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1E88E5),
              title: 'Tambah Company Baru',
              subtitle: 'Daftarkan Owner, Kontraktor, atau Sub-Kont.',
              onTap: onAddCompany,
            ),
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          ],
          _CompanyMenuTile(
            icon: Icons.refresh_rounded,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Refresh Data',
            subtitle: 'Muat ulang data company terkini',
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
