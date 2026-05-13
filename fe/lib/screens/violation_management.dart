import 'package:flutter/material.dart';
import '../services/violation_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'dart:async';

String _userInitial(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '?' : text[0].toUpperCase();
}

class ViolationManagementScreen extends StatefulWidget {
  const ViolationManagementScreen({super.key});

  @override
  State<ViolationManagementScreen> createState() =>
      _ViolationManagementScreenState();
}

class _ViolationManagementScreenState extends State<ViolationManagementScreen> {
  final List<ViolationItem> _violations = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  String? _userRole;
  String? _userDept;

  bool get _hasFullAccess {
    if (_userRole == 'superadmin') return true;
    if (_userRole == 'admin' &&
        (_userDept?.toLowerCase().contains('hse') ?? false)) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _fetchViolations();
    _loadUserData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchViolations(refresh: true);
    });
  }

  Future<void> _loadUserData() async {
    final user = await StorageService.getUser();
    if (mounted) {
      setState(() {
        _userRole = user?['role']?.toString();
        _userDept = user?['department']?.toString();
      });
    }
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
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aksi Pelanggaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildFabMenuItem(
              icon: Icons.add_circle_outline,
              color: Colors.blue,
              title: 'Tambah Pelanggaran',
              subtitle: 'Catat data pelanggaran baru',
              onTap: () {
                Navigator.pop(context);
                _showViolationForm();
              },
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            _buildFabMenuItem(
              icon: Icons.edit_outlined,
              color: Colors.orange,
              title: 'Edit Pelanggaran',
              subtitle: 'Pilih data untuk diubah',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Silakan klik pada kartu pelanggaran untuk mengedit'),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            _buildFabMenuItem(
              icon: Icons.delete_sweep_outlined,
              color: Colors.red,
              title: 'Hapus Pelanggaran',
              subtitle: 'Hapus satu atau beberapa data sekaligus',
              onTap: () {
                Navigator.pop(context);
                setState(() => _isSelectionMode = true);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFabMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchViolations({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _violations.clear();
      });
    }

    setState(() => _isLoading = true);
    final result = await ViolationService.getViolations(
      page: _currentPage,
      search: _searchController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _violations.addAll(result.items);
          _lastPage = result.lastPage;
        } else {
          _error = result.message;
        }
      });
    }
  }

  void _showViolationForm({ViolationItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ViolationFormSheet(
        item: item,
        onSuccess: () {
          _fetchViolations(refresh: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Manajemen Pelanggaran',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Text('${_selectedIds.length} dipilih',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    }),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    child: const Text('Hapus'),
                  ),
                ],
              ),
            )
          else
            _buildSearchBar(),
          Expanded(
            child: _isLoading && _violations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _violations.isEmpty
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: () => _fetchViolations(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                          itemCount: _violations.length +
                              (_currentPage < _lastPage ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _violations.length) {
                              _currentPage++;
                              _fetchViolations();
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            return _buildViolationCard(_violations[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _hasFullAccess
          ? FloatingActionButton(
              onPressed: _openFabMenu,
              backgroundColor: const Color(0xFF1A56C4),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.add, size: 30),
            )
          : null,
      extendBody: true,
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
              _NavItem(
                  icon: Icons.home,
                  label: 'Home',
                  index: 0,
                  currentIndex: 4,
                  onTap: _onTabTapped),
              _NavItem(
                  icon: Icons.article_outlined,
                  label: 'News',
                  index: 1,
                  currentIndex: 4,
                  onTap: _onTabTapped),
              const SizedBox(width: 48),
              _NavItem(
                  icon: Icons.inbox_outlined,
                  label: 'Inbox',
                  index: 3,
                  currentIndex: 4,
                  onTap: _onTabTapped),
              _NavItem(
                  icon: Icons.menu,
                  label: 'Menu',
                  index: 4,
                  currentIndex: 4,
                  onTap: _onTabTapped),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari nama user atau pelanggaran...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildViolationCard(ViolationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (_selectedIds.contains(item.id)) {
                _selectedIds.remove(item.id);
              } else {
                _selectedIds.add(item.id);
              }
            });
          } else {
            _showViolationForm(item: item);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_isSelectionMode)
                Checkbox(
                  value: _selectedIds.contains(item.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedIds.add(item.id);
                      } else {
                        _selectedIds.remove(item.id);
                      }
                    });
                  },
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFE3F2FD),
                          child: Text(
                            _userInitial(item.user['full_name']),
                            style: const TextStyle(
                                color: Color(0xFF1A56C4),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.user['full_name'] ?? 'Unknown User',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'ID: ${item.user['employee_id'] ?? '-'}',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(item.status),
                        if (!_isSelectionMode && _hasFullAccess) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Colors.red),
                            onPressed: () => _confirmDelete(item),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    Text(
                      item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          item.location ?? 'Lokasi tidak disebutkan',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 12, color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text(
                                  'Dibuat: ${_formatDate(item.dateOfViolation)}',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                            if (item.expiredAt != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.event_available_outlined,
                                      size: 12, color: Colors.blue.shade300),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Berlaku S/D: ${_formatDate(item.expiredAt!)}',
                                    style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        if (item.sanction != null)
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.sanction!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      if (dateStr.contains('T')) {
        return dateStr.split('T')[0];
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Terpilih'),
        content: Text(
            'Apakah Anda yakin ingin menghapus ${_selectedIds.length} data yang dipilih?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      int successCount = 0;
      for (String id in _selectedIds) {
        final result = await ViolationService.deleteViolation(id);
        if (result.success) successCount++;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSelectionMode = false;
        _selectedIds.clear();
      });

      _fetchViolations(refresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successCount data berhasil dihapus')),
      );
    }
  }

  Future<void> _confirmDelete(ViolationItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggaran'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final result = await ViolationService.deleteViolation(item.id);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result.success) {
        _fetchViolations(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pelanggaran berhasil dihapus')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.errorMessage ?? 'Gagal menghapus data')));
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == 'Aktif') color = Colors.red;
    if (status == 'Selesai') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ViolationFormSheet extends StatefulWidget {
  final ViolationItem? item;
  final VoidCallback onSuccess;

  const ViolationFormSheet({super.key, this.item, required this.onSuccess});

  @override
  State<ViolationFormSheet> createState() => _ViolationFormSheetState();
}

class _ViolationFormSheetState extends State<ViolationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _expiredDateController = TextEditingController();
  final _sanctionController = TextEditingController();
  Timer? _debounce;
  String _status = 'Aktif';

  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _userResults = [];
  bool _isSearchingUser = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleController.text = widget.item!.title;
      _locationController.text = widget.item!.location ?? '';
      _expiredDateController.text = widget.item!.expiredAt ?? '';
      _sanctionController.text = widget.item!.sanction ?? '';
      _status = widget.item!.status;
      _selectedUser = widget.item!.user;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) {
        setState(() => _userResults = []);
        return;
      }
      setState(() => _isSearchingUser = true);
      final response = await AuthService.listUsers(search: query);
      setState(() {
        _isSearchingUser = false;
        if (response.success) {
          _userResults = List<Map<String, dynamic>>.from(response.data['data']);
        }
      });
    });
  }

  Future<void> _selectExpiredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _expiredDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedUser == null) {
      if (_selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan pilih user terlebih dahulu')));
      }
      return;
    }

    setState(() => _isSaving = true);
    final data = {
      'title': _titleController.text,
      'location': _locationController.text,
      'expired_at': _expiredDateController.text.isEmpty
          ? null
          : _expiredDateController.text,
      'status': _status,
      'sanction': _sanctionController.text,
    };

    final result = widget.item == null
        ? await ViolationService.storeViolation(
            _selectedUser!['id'].toString(), data)
        : await ViolationService.updateViolation(widget.item!.id, data);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pelanggaran berhasil disimpan')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.errorMessage ?? 'Gagal menyimpan data')));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggaran'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      final result = await ViolationService.deleteViolation(widget.item!.id);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (result.success) {
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pelanggaran berhasil dihapus')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserPicker(),
                    const SizedBox(height: 20),
                    _buildField('Judul Pelanggaran', _titleController,
                        hint: 'Contoh: Tidak memakai helm'),
                    const SizedBox(height: 16),
                    _buildField('Lokasi', _locationController,
                        hint: 'Contoh: Pit A / Area Workshop',
                        isRequired: false),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectExpiredDate,
                      child: IgnorePointer(
                        child: _buildField('Masa Berlaku / Berlaku Hingga',
                            _expiredDateController,
                            hint: 'YYYY-MM-DD',
                            icon: Icons.event_available,
                            isRequired: false),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusPicker(),
                    const SizedBox(height: 16),
                    _buildField('Sanksi / Tindakan', _sanctionController,
                        hint: 'Contoh: SP1 / Teguran Lisan', isRequired: false),
                    const SizedBox(height: 32),
                    _buildFooterButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.item == null ? 'Tambah Pelanggaran' : 'Edit Pelanggaran',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('User / Karyawan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_selectedUser != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1A56C4).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                    child: Text(_userInitial(_selectedUser!['full_name']))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedUser!['full_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(_selectedUser!['employee_id'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (widget.item == null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _selectedUser = null),
                  ),
              ],
            ),
          )
        else
          Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama atau ID karyawan...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                onChanged: _searchUsers,
              ),
              if (_isSearchingUser)
                const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator()),
              if (_userResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _userResults.length,
                    itemBuilder: (ctx, idx) {
                      final u = _userResults[idx];
                      return ListTile(
                        leading: CircleAvatar(
                            radius: 14, child: Text(u['full_name']?[0] ?? '')),
                        title: Text(u['full_name'] ?? '',
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(u['employee_id'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        onTap: () => setState(() {
                          _selectedUser = u;
                          _userResults = [];
                        }),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {required String hint, IconData? icon, bool isRequired = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: isRequired
              ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null
              : null,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _status,
              isExpanded: true,
              items: ['Aktif', 'Selesai']
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterButtons() {
    return Row(
      children: [
        if (widget.item != null) ...[
          IconButton(
            onPressed: _isSaving ? null : _delete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56C4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SIMPAN DATA',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _NavItem({
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
