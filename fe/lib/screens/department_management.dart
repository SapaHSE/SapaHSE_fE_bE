import 'package:flutter/material.dart';
import '../models/department_model.dart';
import '../services/department_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:sapahse/main.dart';
import 'qr_scan_screen.dart';
import 'create_hazard_screen.dart';
import 'create_inspection_screen.dart';
import 'my_profile.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  State<DepartmentManagementScreen> createState() => _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState extends State<DepartmentManagementScreen> {
  static const _blue = Color(0xFF1A56C4);
  
  bool _isLoading = true;
  String? _error;
  List<DepartmentData> _departments = [];
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await AuthService.getCurrentUser();
      final departments = await DepartmentService.getDepartments();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _departments = departments;
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

  void _showForm({DepartmentData? department}) {
    final isEdit = department != null;
    final ctrl = TextEditingController(text: department?.name ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Department' : 'Tambah Department', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NAMA DEPARTMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Contoh: Maintenance',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                if (isEdit) {
                  await DepartmentService.updateDepartment(department.id, name);
                  _showSnack('Department berhasil diperbarui');
                } else {
                  await DepartmentService.createDepartment(name);
                  _showSnack('Department berhasil ditambahkan');
                }
                _loadInitialData();
              } catch (e) {
                _showSnack(e.toString(), isError: true);
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DepartmentData department) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
        content: Text('Yakin ingin menghapus ${department.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await DepartmentService.deleteDepartment(department.id);
                _showSnack('Department berhasil dihapus');
                _loadInitialData();
              } catch (e) {
                _showSnack(e.toString(), isError: true);
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
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
    final bool canEdit = _currentUser?.role.toLowerCase() == 'superadmin';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeptFabMenuSheet(
        canEdit: canEdit,
        onAddDepartment: () {
          Navigator.pop(context);
          _showForm();
        },
        onRefresh: () {
          Navigator.pop(context);
          _loadInitialData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = _currentUser?.role.toLowerCase() == 'superadmin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Department Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadInitialData, child: const Text('Coba Lagi')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadInitialData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _departments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final dept = _departments[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.corporate_fare, color: _blue, size: 20),
                          ),
                          title: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          trailing: canEdit ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                onPressed: () => _showForm(department: dept),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _confirmDelete(dept),
                              ),
                            ],
                          ) : null,
                        ),
                      );
                    },
                  ),
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
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DeptNavItem(icon: Icons.home, label: 'Home', index: 0, currentIndex: 4, onTap: _onTabTapped),
              _DeptNavItem(icon: Icons.article_outlined, label: 'News', index: 1, currentIndex: 4, onTap: _onTabTapped),
              const SizedBox(width: 48),
              _DeptNavItem(icon: Icons.inbox_outlined, label: 'Inbox', index: 3, currentIndex: 4, onTap: _onTabTapped),
              _DeptNavItem(icon: Icons.menu, label: 'Menu', index: 4, currentIndex: 4, onTap: _onTabTapped),
            ],
          ),
        ),
      ),
    );
  }
}

// ── DEPT FAB MENU SHEET ────────────────────────────────────────────────────────
class _DeptFabMenuSheet extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onAddDepartment;
  final VoidCallback onRefresh;

  const _DeptFabMenuSheet({
    required this.canEdit,
    required this.onAddDepartment,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Manajemen Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87)),
          ),
          const SizedBox(height: 8),
          if (canEdit) ...[
            _DeptFabMenuTile(
              icon: Icons.add_business_rounded,
              iconBgColor: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              title: 'Tambah Department',
              subtitle: 'Daftarkan unit atau departemen baru',
              onTap: onAddDepartment,
            ),
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          ],
          _DeptFabMenuTile(
            icon: Icons.refresh_rounded,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Refresh Data',
            subtitle: 'Muat ulang daftar departemen',
            onTap: onRefresh,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                ),
                child: const Text('Batal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptFabMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DeptFabMenuTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── NAV ITEM ──────────────────────────────────────────────────────────────────
class _DeptNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _DeptNavItem({
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
