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
  final FocusNode _searchFocusNode = FocusNode();
  String? _userRole;
  String? _userDept;
  String _selectedStatus = 'Semua';
  String _selectedType = 'Semua';
  bool _isSearching = false;

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
    _searchFocusNode.dispose();
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
      onDeleteMode: () => setState(() => _isSelectionMode = true),
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
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Cari violation atau user...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              )
            : const Text(
                'Violation & Incident',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
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
                    _searchController.clear();
                  });
                  _fetchViolations(refresh: true);
                },
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (_isSearching) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _searchFocusNode.requestFocus();
                });
              } else {
                _searchController.clear();
                _fetchViolations(refresh: true);
              }
            },
          ),
        ],
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
            _buildFilterRow(),
          ],
          Expanded(
            child: _isLoading && _violations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _violations.isEmpty
                    ? _buildMessageState(
                        icon: Icons.error_outline,
                        message: _error!,
                      )
                    : _violations.isEmpty
                        ? _buildMessageState(
                            icon: Icons.fact_check_outlined,
                            message: 'Tidak ada data violation atau incident',
                          )
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

  Widget _buildFilterRow() {
    final filters = ['Semua', 'Violation', 'Incident', 'Aktif', 'Selesai'];
    return Container(
      height: 56,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeFilter == filter;
          final color = _filterColor(filter);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              selectedColor: color,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey.shade300,
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (!selected) return;
                _applyFilter(filter);
              },
            ),
          );
        },
      ),
    );
  }

  String get _activeFilter {
    if (_selectedType != 'Semua') return _selectedType;
    if (_selectedStatus != 'Semua') return _selectedStatus;
    return 'Semua';
  }

  Color _filterColor(String filter) {
    if (filter == 'Violation' || filter == 'Aktif') return Colors.red;
    if (filter == 'Incident') return Colors.orange;
    if (filter == 'Selesai') return Colors.green;
    return const Color(0xFF1A56C4);
  }

  void _applyFilter(String filter) {
    setState(() {
      if (filter == 'Violation' || filter == 'Incident') {
        _selectedType = filter;
        _selectedStatus = 'Semua';
      } else if (filter == 'Aktif' || filter == 'Selesai') {
        _selectedStatus = filter;
        _selectedType = 'Semua';
      } else {
        _selectedType = 'Semua';
        _selectedStatus = 'Semua';
      }
    });
    _fetchViolations(refresh: true);
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationCard(ViolationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Checkbox(
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
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE3F2FD),
                        child: Text(
                          _userInitial(item.user['full_name']),
                          style: const TextStyle(
                            color: Color(0xFF1A56C4),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.user['full_name'] ?? 'Unknown User',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${item.user['employee_id'] ?? '-'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatusBadge(item.status),
                          if (!_isSelectionMode && _hasFullAccess) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _confirmDelete(item),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildTypeBadge(item.type),
                      _buildLevelBadge(item.level),
                      if ((item.violationCategory ?? '').trim().isNotEmpty)
                        _buildNeutralBadge(item.violationCategory!.trim()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildMetaItem(
                        Icons.location_on_outlined,
                        item.location ?? 'Lokasi tidak disebutkan',
                      ),
                      _buildMetaItem(
                        Icons.calendar_today_outlined,
                        _formatDate(item.dateOfViolation),
                      ),
                      _buildMetaItem(
                        item.isPermanent
                            ? Icons.all_inclusive
                            : Icons.event_available_outlined,
                        item.isPermanent || (item.expiredAt ?? '').isEmpty
                            ? 'Permanen'
                            : 'S/D ${_formatDate(item.expiredAt!)}',
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                  if ((item.sanction ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.sanction!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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

  Widget _buildNeutralBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.blueGrey.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text, {Color? color}) {
    final effectiveColor = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: effectiveColor.withValues(alpha: 0.75)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: color == null ? FontWeight.normal : FontWeight.w500,
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
