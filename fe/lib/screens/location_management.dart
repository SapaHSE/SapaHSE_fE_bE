import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import 'company_management.dart';
import '../services/storage_service.dart';
import 'package:sapahse/main.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() => _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> with SingleTickerProviderStateMixin {
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

  bool get _isSuperAdmin => _userRole?.toLowerCase() == 'superadmin' || _userRole?.toLowerCase() == 'super admin';

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        CompanyService.getCompanies(category: 'owner'),
        CompanyService.getAreas(),
      ]);
      if (mounted) {
        setState(() {
          _ownerCompanies = results[0] as List<CompanyData>;
          _allAreas = results[1] as List<AreaData>;
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _navigateToAreaForm({AreaData? area, CompanyData? defaultCompany}) async {
    if (_ownerCompanies.isEmpty) {
      _showSnack('Belum ada perusahaan Owner. Tambahkan di Company Management terlebih dahulu.', isError: true);
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AreaFormScreen(
          areaToEdit: area,
          defaultCompany: defaultCompany,
          ownerCompanies: _ownerCompanies,
        ),
      ),
    );
    if (result == true) {
      _loadData();
      _showSnack(area == null ? 'Lokasi berhasil ditambahkan.' : 'Lokasi berhasil diperbarui.');
    }
  }

  void _confirmDeleteArea(AreaData area) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Lokasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Yakin ingin menghapus ${area.name}? Semua data yang terkait mungkin akan ikut hilang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await CompanyService.deleteArea(area.id);
                _showSnack('Lokasi berhasil dihapus.');
              } catch (e) {
                _showSnack(e.toString(), isError: true);
              }
              _loadData();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(AreaData area) async {
    setState(() => _isLoading = true);
    try {
      await CompanyService.toggleAreaStatus(area.id);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    _loadData();
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
          : const Text('Location Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Daftar Lokasi'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LocationNavItem(icon: Icons.home, label: 'Home', index: 0, currentIndex: 4, onTap: _onTabTapped),
              _LocationNavItem(icon: Icons.article_outlined, label: 'News', index: 1, currentIndex: 4, onTap: _onTabTapped),
              const SizedBox(width: 48),
              _LocationNavItem(icon: Icons.inbox_outlined, label: 'Inbox', index: 3, currentIndex: 4, onTap: _onTabTapped),
              _LocationNavItem(icon: Icons.menu, label: 'Menu', index: 4, currentIndex: 4, onTap: _onTabTapped),
            ],
          ),
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
      final areaMatch = _allAreas.any((a) => a.companyId == company.id && a.name.toLowerCase().contains(searchLower));
      return companyMatch || areaMatch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
              
              List<AreaData> companyAreas = _allAreas.where((a) => a.companyId == company.id).toList();
              
              // If searching and company doesn't match, only show matching areas
              final companyMatch = company.name.toLowerCase().contains(searchLower) || 
                                   (company.code?.toLowerCase().contains(searchLower) ?? false);
              if (_searchQuery.isNotEmpty && !companyMatch) {
                companyAreas = companyAreas.where((a) => a.name.toLowerCase().contains(searchLower)).toList();
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
            const Text('Tidak Ada Hasil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Lokasi atau perusahaan tidak ditemukan.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
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
              style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.w500),
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
            const Text('Belum ada Perusahaan Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildCategoryCard(CompanyData company, Color color, List<AreaData> areas) {
    final bgColor = color.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${company.code ?? 'OWN'} — ${company.name}',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${areas.where((s) => s.isActive).length} lokasi aktif',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
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
                    side: BorderSide(color: color.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.circle, size: 8, color: area.isActive ? Colors.green : Colors.grey.shade300),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(area.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    if (area.code != null && area.code!.isNotEmpty)
                      Text(area.code!, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              if (_isSuperAdmin) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                  onPressed: () => _confirmDeleteArea(area),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _navigateToAreaForm(area: area),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _toggleStatus(area),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: area.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      area.isActive ? 'On' : 'Off',
                      style: TextStyle(
                        color: area.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                        fontWeight: area.isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoToCompanyManagementButton() {
    if (!_isSuperAdmin) return const SizedBox.shrink();
    return InkWell(
      onTap: () {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CompanyManagementScreen()));
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
            Text('Kelola Owner di Company Management', style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 13)),
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

  const _AreaFormScreen({this.areaToEdit, this.defaultCompany, required this.ownerCompanies});

  @override
  State<_AreaFormScreen> createState() => _AreaFormScreenState();
}

class _AreaFormScreenState extends State<_AreaFormScreen> {
  static const _blue = Color(0xFF1A56C4);
  late int _selectedCompanyId;
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.areaToEdit?.companyId ?? widget.defaultCompany?.id ?? widget.ownerCompanies.first.id;
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
        );
      } else {
        result = await CompanyService.createArea(
          _selectedCompanyId,
          name,
          code: code,
        );
      }

      if (result != null) {
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
                  _buildTextField(_codeCtrl, hint: 'Contoh: PIT-M', maxLength: 3, capitalization: TextCapitalization.characters),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
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
                style: TextStyle(color: Color(0xFFF57F17), fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: 'Setelah disimpan, perubahan akan langsung berlaku pada data '),
                  TextSpan(text: 'Location Management.', style: TextStyle(fontWeight: FontWeight.bold)),
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
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedCompanyId,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: widget.ownerCompanies.map((c) => DropdownMenuItem(
          value: c.id, 
          child: Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))
        )).toList(),
        onChanged: (v) => setState(() => _selectedCompanyId = v!),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, {String? hint, int? maxLength, TextCapitalization capitalization = TextCapitalization.none}) {
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
            Icon(icon, color: isActive ? const Color(0xFF1A56C4) : Colors.grey, size: 24),
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
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
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
