import 'package:flutter/material.dart';
import '../utils/ui_utils.dart';
import '../services/violation_service.dart';
import '../services/storage_service.dart';
import '../main.dart';
import 'dart:async';
import '../widgets/app_safe_insets.dart';
import '../widgets/fab_notched_bottom_bar.dart';
import '../widgets/violation_form_sheet.dart';
import '../widgets/violation_type_picker.dart';

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
  String _selectedStatus = 'Semua';
  String _selectedType = 'Semua';

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
    showViolationTypePicker(
      context: context,
      onSelected: (type) => _showViolationForm(initialType: type),
    );
  }

  Future<void> _fetchViolations({bool refresh = false, bool silent = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _violations.clear();
      });
    }

    if (!silent) {
      setState(() => _isLoading = true);
    }
    final result = await ViolationService.getViolations(
      page: _currentPage,
      search: _searchController.text,
      status: _selectedStatus,
      type: _selectedType,
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

  void _showViolationForm({ViolationItem? item, String initialType = 'Violation'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ViolationFormSheet(
        item: item,
        initialType: item?.type ?? initialType,
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
          else ...[
            _buildSearchBar(),
            _buildFilterRow(),
          ],
          Expanded(
            child: _isLoading && _violations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _violations.isEmpty
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: () => _fetchViolations(refresh: true),
                        child: ListView.builder(
                          padding: AppSafeInsets.bottomNavListPadding(context),
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
      bottomNavigationBar: FabNotchedBottomBar(
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
            const SizedBox(width: 56),
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

  Widget _buildFilterRow() {
    final statuses = ['Semua', 'Aktif', 'Selesai'];
    final types = ['Semua', 'Violation', 'Incident'];
    return Container(
      height: 96,
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: types.length,
              itemBuilder: (context, index) {
                final type = types[index];
                final isSelected = _selectedType == type;
                final color = type == 'Incident'
                    ? Colors.orange
                    : type == 'Violation'
                        ? Colors.red
                        : Colors.blue;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: ChoiceChip(
                    label: Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: color.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: isSelected ? color : color.withValues(alpha: 0.2),
                    ),
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() => _selectedType = type);
                      _fetchViolations(refresh: true);
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                final status = statuses[index];
                final isSelected = _selectedStatus == status;

                Color color = Colors.blue;
                if (status == 'Aktif') color = Colors.red;
                if (status == 'Selesai') color = Colors.green;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: ChoiceChip(
                    label: Text(
                      status,
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: color.withValues(alpha: 0.05),
                    side: BorderSide(
                        color: isSelected ? color : color.withValues(alpha: 0.2)),
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() => _selectedStatus = status);
                      _fetchViolations(refresh: true);
                    },
                  ),
                );
              },
            ),
          ),
        ],
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
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: [
                            _buildTypeBadge(item.type),
                            _buildLevelBadge(item.level),
                            _buildStatusBadge(item.status),
                          ],
                        ),
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
                    if ((item.violationCategory ?? '').isNotEmpty ||
                        (item.violationSubcategory ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          item.violationCategory,
                          item.violationSubcategory,
                        ].where((v) => (v ?? '').isNotEmpty).join(' - '),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
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
      int successCount = 0;
      for (String id in _selectedIds) {
        final result = await ViolationService.deleteViolation(id);
        if (result.success) successCount++;
      }

      if (!mounted) return;
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });

      _fetchViolations(refresh: true, silent: true);
      UiUtils.showSuccessPopup(context, '$successCount data berhasil dihapus');
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
      final result = await ViolationService.deleteViolation(item.id);
      if (!mounted) return;
      if (result.success) {
        _fetchViolations(refresh: true, silent: true);
        UiUtils.showSuccessPopup(context, 'Pelanggaran berhasil dihapus');
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

  Widget _buildTypeBadge(String type) {
    final color = type == 'Incident' ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLevelBadge(int level) {
    final color = switch (level) {
      1 => Colors.green,
      2 => Colors.orange,
      _ => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'L$level',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
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
