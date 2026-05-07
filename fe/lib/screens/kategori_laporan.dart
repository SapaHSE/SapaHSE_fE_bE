import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import 'package:sapahse/main.dart';
import '../widgets/minimal_dropdown.dart';

class KategoriLaporanScreen extends StatefulWidget {
  const KategoriLaporanScreen({super.key});

  @override
  State<KategoriLaporanScreen> createState() => _KategoriLaporanScreenState();
}

class _KategoriLaporanScreenState extends State<KategoriLaporanScreen> {
  static const _blue = Color(0xFF1A56C4);
  static const _red = Color(0xFFD32F2F);
  static const _orange = Color(0xFFF57C00);


  String? _userRole;

  List<HazardCategoryData> _categories = [];
  bool _isLoading = true;
  String? _error;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

  bool get _isSuperAdmin => _userRole?.toLowerCase() == 'superadmin';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ReportService.getHazardCategories(),
      ]);
      if (mounted) {
        setState(() {
          _categories = results[0];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Category CRUD ─────────────────────────────────────────────────────────

  void _showAddCategoryDialog() {
    final ctrl = TextEditingController();
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _InputDialog(
        title: 'Tambah Kategori',
        fields: [
          _FieldConfig('Nama Kategori', ctrl, 'cth: Lingkungan', required: true),
          _FieldConfig('Kode (opsional)', codeCtrl, 'cth: LKG', maxLength: 3, capitalization: TextCapitalization.characters),
        ],
        onSubmit: () async {
          if (ctrl.text.trim().isEmpty) return;
          Navigator.pop(context);
          setState(() => _isLoading = true);
          final result = await ReportService.createCategory(
            ctrl.text.trim(),
            code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
          );
          if (result != null) {
            await _loadData();
          } else {
            setState(() => _isLoading = false);
            _showSnack('Gagal menambah kategori.', isError: true);
          }
        },
      ),
    );
  }

  void _showEditCategoryDialog(HazardCategoryData cat) {
    final ctrl = TextEditingController(text: cat.name);
    final codeCtrl = TextEditingController(text: cat.code);
    showDialog(
      context: context,
      builder: (_) => _InputDialog(
        title: 'Edit Kategori',
        fields: [
          _FieldConfig('Nama Kategori', ctrl, '', required: true),
          _FieldConfig('Kode (opsional)', codeCtrl, '', maxLength: 3, capitalization: TextCapitalization.characters),
        ],
        onSubmit: () async {
          if (ctrl.text.trim().isEmpty) return;
          Navigator.pop(context);
          setState(() => _isLoading = true);
          final result = await ReportService.updateCategory(
            cat.id, ctrl.text.trim(),
            code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
          );
          if (result != null) {
            await _loadData();
          } else {
            setState(() => _isLoading = false);
            _showSnack('Gagal mengupdate kategori.', isError: true);
          }
        },
      ),
    );
  }

  void _confirmDeleteCategory(HazardCategoryData cat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          const Text('Hapus Kategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: 'Yakin hapus kategori '),
              TextSpan(text: '"${cat.name}"', style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: '?\n\nSemua subkategori di dalamnya akan ikut terhapus.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final ok = await ReportService.deleteCategory(cat.id);
              if (ok) {
                await _loadData();
                _showSnack('Kategori "${cat.name}" dihapus.');
              } else {
                setState(() => _isLoading = false);
                _showSnack('Gagal menghapus kategori.', isError: true);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Subcategory CRUD ──────────────────────────────────────────────────────

  void _showAddSubcategoryDialog(HazardCategoryData cat) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SubcategoryFormScreen(
          initialCategory: cat,
          categories: _categories,
        ),
      ),
    );
    if (result == true) {
      _loadData();
      _showSnack('Subkategori berhasil ditambahkan.');
    }
  }

  void _showEditSubcategoryDialog(HazardCategoryData cat, HazardSubcategoryData sub) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SubcategoryFormScreen(
          initialCategory: cat,
          categories: _categories,
          subcategoryToEdit: sub,
        ),
      ),
    );
    if (result == true) {
      _loadData();
      _showSnack('Subkategori berhasil diperbarui.');
    }
  }

  void _confirmDeleteSubcategory(HazardCategoryData cat, HazardSubcategoryData sub) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Subkategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: 'Yakin hapus '),
              TextSpan(text: '"${sub.name}"', style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final ok = await ReportService.deleteSubcategory(cat.id, sub.id);
              if (ok) {
                await _loadData();
                _showSnack('Subkategori "${sub.name}" dihapus.');
              } else {
                setState(() => _isLoading = false);
                _showSnack('Gagal menghapus subkategori.', isError: true);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
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
      builder: (_) => _KategoriFabMenuSheet(
        isSuperAdmin: _isSuperAdmin,
        onAddCategory: () {
          Navigator.pop(context);
          _showAddCategoryDialog();
        },
        onAddSubcategory: () {
          Navigator.pop(context);
          _showAddSubcategoryForAnyCategory();
        },
        onRefreshData: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                hintText: 'Cari kategori...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              style: const TextStyle(color: Colors.black87, fontSize: 16),
            )
          : const Text('Kategori Laporan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildMainListTab(),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () => _openFabMenu(),
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
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _KategoriNavItem(icon: Icons.home, label: 'Home', index: 0, currentIndex: 4, onTap: _onTabTapped),
              _KategoriNavItem(icon: Icons.article_outlined, label: 'News', index: 1, currentIndex: 4, onTap: _onTabTapped),
              const SizedBox(width: 48),
              _KategoriNavItem(icon: Icons.inbox_outlined, label: 'Inbox', index: 3, currentIndex: 4, onTap: _onTabTapped),
              _KategoriNavItem(icon: Icons.menu, label: 'Menu', index: 4, currentIndex: 4, onTap: _onTabTapped),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Gagal Memuat Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainListTab() {
    final filteredCategories = _categories.where((cat) {
      if (_searchQuery.isEmpty) return true;
      final searchLower = _searchQuery.toLowerCase();
      final catMatch = cat.name.toLowerCase().contains(searchLower) ||
          cat.code.toLowerCase().contains(searchLower);
      final subMatch = cat.subcategories.any((sub) => sub.name.toLowerCase().contains(searchLower));
      return catMatch || subMatch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 16),
          if (filteredCategories.isEmpty && _searchQuery.isNotEmpty)
            _buildEmptyState(
              icon: Icons.search_off,
              title: 'Tidak Ada Hasil',
              subtitle: 'Kategori atau subkategori tidak ditemukan.',
            )
          else
            ...filteredCategories.map((cat) => _buildRedesignedCategoryCard(cat)),
          if (_isSuperAdmin) ...[
            const SizedBox(height: 16),
            _buildAddMainCategoryButton(),
          ],
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
              'Kategori ini berlaku untuk seluruh perusahaan dalam operasional harian.',
              style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedesignedCategoryCard(HazardCategoryData cat) {
    final color = (cat.code == 'TTA') ? _red : (cat.code == 'KTA') ? _orange : _blue;
    final bgColor = color.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
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
                        '${cat.code} - ${cat.name}',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cat.subcategories.where((s) => s.isActive).length} subkategori aktif',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (_isSuperAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    onPressed: () => _confirmDeleteCategory(cat),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _showEditCategoryDialog(cat),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
                const Icon(Icons.keyboard_arrow_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
          // Subcategories
          ...cat.subcategories.map((sub) => _buildSubcategoryItem(cat, sub)),
          // Add Subcategory Button
          if (_isSuperAdmin)
            Padding(
              padding: const EdgeInsets.all(12),
              child: InkWell(
                onTap: () => _showAddSubcategoryDialog(cat),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('Tambah Subkategori ${cat.code}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryItem(HazardCategoryData cat, HazardSubcategoryData sub) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.circle, size: 8, color: sub.isActive ? Colors.green : Colors.grey.shade300),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    if (sub.abbreviation != null)
                      Text(sub.abbreviation!, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              if (_isSuperAdmin) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                  onPressed: () => _confirmDeleteSubcategory(cat, sub),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showEditSubcategoryDialog(cat, sub),
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
                  onTap: () => _toggleSubcategory(sub),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sub.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sub.isActive ? 'On' : 'Off',
                      style: TextStyle(
                        color: sub.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
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

  Widget _buildAddMainCategoryButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _showAddCategoryDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah Kategori Utama Baru'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _blue,
            side: BorderSide(color: _blue.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSubcategory(HazardSubcategoryData sub) async {
    setState(() => _isLoading = true);
    final ok = await ReportService.toggleSubcategoryStatus(sub.id);
    if (ok) {
      await _loadData();
      _showSnack('Status subkategori diperbarui.');
    } else {
      setState(() => _isLoading = false);
      _showSnack('Gagal mengubah status.', isError: true);
    }
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  void _showAddSubcategoryForAnyCategory() async {
    if (_categories.isEmpty) {
      _showSnack('Tambah kategori terlebih dahulu.', isError: true);
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SubcategoryFormScreen(
          categories: _categories,
        ),
      ),
    );
    if (result == true) {
      _loadData();
      _showSnack('Subkategori berhasil ditambahkan.');
    }
  }
}

// ── Subcategory Form Screen ────────────────────────────────────────────────

class _SubcategoryFormScreen extends StatefulWidget {
  final HazardCategoryData? initialCategory;
  final List<HazardCategoryData> categories;
  final HazardSubcategoryData? subcategoryToEdit;

  const _SubcategoryFormScreen({
    this.initialCategory,
    required this.categories,
    this.subcategoryToEdit,
  });

  @override
  State<_SubcategoryFormScreen> createState() => _SubcategoryFormScreenState();
}

class _SubcategoryFormScreenState extends State<_SubcategoryFormScreen> {
  static const _blue = Color(0xFF1A56C4);
  
  HazardCategoryData? _selectedCategory;
  late TextEditingController _nameCtrl;
  late TextEditingController _abbrCtrl;
  late TextEditingController _descCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? (widget.categories.isNotEmpty ? widget.categories.first : null);
    _nameCtrl = TextEditingController(text: widget.subcategoryToEdit?.name ?? '');
    _abbrCtrl = TextEditingController(text: widget.subcategoryToEdit?.abbreviation ?? '');
    _descCtrl = TextEditingController(text: widget.subcategoryToEdit?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final abbr = _abbrCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (name.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Kategori wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      dynamic result;
      if (widget.subcategoryToEdit != null) {
        result = await ReportService.updateSubcategory(
          _selectedCategory!.id,
          widget.subcategoryToEdit!.id,
          name,
          abbreviation: abbr,
          description: desc,
          isActive: widget.subcategoryToEdit!.isActive,
        );
      } else {
        result = await ReportService.createSubcategory(
          _selectedCategory!.id,
          name,
          abbreviation: abbr,
          description: desc,
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
    final isEdit = widget.subcategoryToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Subkategori' : 'Tambah Subkategori', 
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
            _buildLabel('MASUK KE'),
            const SizedBox(height: 8),
            _buildDropdown(),
            const SizedBox(height: 24),
            _buildLabel('SINGKATAN'),
            const SizedBox(height: 8),
            _buildTextField(_abbrCtrl, hint: 'cth: TTA-01', maxLength: 3, capitalization: TextCapitalization.characters),
            const SizedBox(height: 24),
            _buildLabel('NAMA SUBKATEGORI'),
            const SizedBox(height: 8),
            _buildTextField(_nameCtrl, hint: 'cth: Pengoperasian Alat'),
            const SizedBox(height: 24),
            _buildLabel('DESKRIPSI (OPSIONAL)'),
            const SizedBox(height: 8),
            _buildTextField(_descCtrl, hint: 'Masukkan deskripsi subkategori...', maxLines: 4),
            const SizedBox(height: 40),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: kMinimalFieldContainerDecoration,
      child: DropdownButtonFormField<HazardCategoryData>(
        initialValue: _selectedCategory,
        icon: kMinimalDropdownChevron,
        borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
        style: kMinimalDropdownTextStyle,
        decoration: minimalFieldDecoration(),
        items: widget.categories.map((c) => DropdownMenuItem(
          value: c,
          child: Text(c.name, style: kMinimalDropdownTextStyle),
        )).toList(),
        onChanged: (v) => setState(() => _selectedCategory = v),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, {String? hint, int maxLines = 1, int? maxLength, TextCapitalization capitalization = TextCapitalization.none}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: _blue.withValues(alpha: 0.4),
        ),
        child: _isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('SIMPAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
      ),
    );
  }
}

// ── Reusable Input Dialog ──────────────────────────────────────────────────

class _FieldConfig {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool required;
  final int? maxLength;
  final TextCapitalization capitalization;

  _FieldConfig(this.label, this.controller, this.hint, {
    this.required = false, 
    this.maxLength,
    this.capitalization = TextCapitalization.none,
  });
}

class _InputDialog extends StatelessWidget {
  final String title;
  final List<_FieldConfig> fields;
  final VoidCallback onSubmit;

  const _InputDialog({
    required this.title,
    required this.fields,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.expand((f) => [
          Text(
            '${f.label}${f.required ? ' *' : ''}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: f.controller,
            maxLength: f.maxLength,
            textCapitalization: f.capitalization,
            decoration: InputDecoration(
              hintText: f.hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              counterText: "", // Hide counter
            ),
          ),
          const SizedBox(height: 12),
        ]).toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A56C4),
            foregroundColor: Colors.white,
          ),
          onPressed: onSubmit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

// ── Kategori Nav Item ──────────────────────────────────────────────────────────
class _KategoriNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _KategoriNavItem({
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

// ── Kategori Menu Tile ─────────────────────────────────────────────────────────
class _KategoriMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _KategoriMenuTile({
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

// ── Kategori FAB Menu Sheet ───────────────────────────────────────────────────
class _KategoriFabMenuSheet extends StatelessWidget {
  final bool isSuperAdmin;
  final VoidCallback onAddCategory;
  final VoidCallback onAddSubcategory;
  final VoidCallback onRefreshData;

  const _KategoriFabMenuSheet({
    required this.isSuperAdmin,
    required this.onAddCategory,
    required this.onAddSubcategory,
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
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
              'Aksi Kategori',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),

          if (isSuperAdmin) ...[
            _KategoriMenuTile(
              icon: Icons.category_outlined,
              iconBgColor: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1E88E5),
              title: 'Tambah Kategori',
              subtitle: 'Buat kategori hazard utama baru',
              onTap: onAddCategory,
            ),
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
            _KategoriMenuTile(
              icon: Icons.subdirectory_arrow_right_rounded,
              iconBgColor: const Color(0xFFF3E5F5),
              iconColor: const Color(0xFF8E24AA),
              title: 'Tambah Subkategori',
              subtitle: 'Tambahkan item ke kategori yang ada',
              onTap: onAddSubcategory,
            ),
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          ],

          _KategoriMenuTile(
            icon: Icons.refresh_rounded,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Refresh Data',
            subtitle: 'Muat ulang daftar kategori',
            onTap: onRefreshData,
          ),
          const SizedBox(height: 8),

          // Cancel
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
