import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/company_service.dart';
import '../services/department_service.dart';
import '../widgets/reject_reason_dialog.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/fab_notched_bottom_bar.dart';
import 'package:sapahse/main.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const _blue = Color(0xFF1A56C4); // Unified Blue
  bool _isLoading = false;
  bool _isLoadingUnapproved = false;
  bool _isLoadingRejected = false;
  List<dynamic> _allUsers = [];
  List<dynamic> _unapprovedUsers = [];
  List<dynamic> _rejectedUsers = [];
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  bool _isSuperadmin = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoad() async {
    final user = await StorageService.getUser();
    if (mounted) {
      final role = user?['role']?.toString().toLowerCase();
      final isSuper = role == 'superadmin';
      final isAdmin = role == 'admin' || isSuper;

      if (user != null && isAdmin) {
        setState(() => _isSuperadmin = isSuper);
        _fetchUsers();
        _fetchUnapprovedUsers();
        _fetchRejectedUsers();
      } else {
        setState(() => _isSuperadmin = false);
      }
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final response = await ApiService.get('/admin/users?per_page=100');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.success && response.data['data'] != null) {
          // Sometimes pagination data is nested
          final data = response.data['data'];
          if (data is Map && data.containsKey('data')) {
            _allUsers = data['data'] ?? [];
          } else if (data is List) {
            _allUsers = data;
          } else {
            _allUsers = [];
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.errorMessage ?? 'Gagal memuat pengguna'),
            ),
          );
        }
      });
    }
  }

  Future<void> _fetchUnapprovedUsers() async {
    setState(() => _isLoadingUnapproved = true);
    final response = await ApiService.get(
      '/admin/users?registration_status=pending',
    );
    if (mounted) {
      setState(() {
        _isLoadingUnapproved = false;
        if (response.success && response.data['data'] != null) {
          final data = response.data['data'];
          if (data is Map && data.containsKey('data')) {
            _unapprovedUsers = data['data'] ?? [];
          } else if (data is List) {
            _unapprovedUsers = data;
          } else {
            _unapprovedUsers = [];
          }
        }
      });
    }
  }

  Future<void> _fetchRejectedUsers() async {
    setState(() => _isLoadingRejected = true);
    final response = await ApiService.get('/admin/registration-logs');
    if (mounted) {
      setState(() {
        _isLoadingRejected = false;
        if (response.success && response.data['data'] != null) {
          final data = response.data['data'];
          if (data is Map && data.containsKey('data')) {
            _rejectedUsers = data['data'] ?? [];
          } else if (data is List) {
            _rejectedUsers = data;
          } else {
            _rejectedUsers = [];
          }
        }
      });
    }
  }

  Future<void> _approveUser(String id) async {
    final response = await ApiService.put('/admin/users/$id/approve', {});
    if (mounted) {
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengguna berhasil disetujui!')),
        );
        _fetchUnapprovedUsers();
        _fetchUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.errorMessage ?? 'Gagal menyetujui pengguna.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(String id) async {
    final reason = await showRejectReasonDialog(
      context,
      title: 'Tolak Pendaftaran',
      description: 'Berikan alasan penolakan:',
      hintText: 'Contoh: NIK tidak ditemukan atau data tidak valid...',
      confirmLabel: 'Tolak Pendaftaran',
      requireReason: false,
    );
    if (reason != null) {
      setState(() => _isLoadingUnapproved = true);
      final response = await ApiService.post('/admin/users/$id/reject', {
        'reason': reason,
      });
      if (mounted) {
        setState(() => _isLoadingUnapproved = false);
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pendaftaran ditolak. Email notifikasi telah dikirim.',
              ),
            ),
          );
          _fetchUnapprovedUsers();
          _fetchRejectedUsers();
          _fetchUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.errorMessage ?? 'Gagal menolak.')),
          );
        }
      }
    }
  }

  List<dynamic> get _filteredUsers {
    return _allUsers.where((u) {
      // Search
      final name = (u['full_name'] ?? '').toLowerCase();
      final nik = (u['employee_id'] ?? '').toLowerCase();
      final dept = (u['department'] ?? '').toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      if (_searchQuery.isNotEmpty &&
          !name.contains(searchLower) &&
          !nik.contains(searchLower) &&
          !dept.contains(searchLower)) {
        return false;
      }

      // Filter
      final isActive = u['is_active'] == 1 || u['is_active'] == true;
      final role = (u['role'] ?? 'user').toString().toLowerCase();

      if (_selectedFilter == 'Inactive') return !isActive;
      if (_selectedFilter == 'User') return role == 'user' && isActive;
      if (_selectedFilter == 'Admin') return role == 'admin' && isActive;
      if (_selectedFilter == 'Superadmin') {
        return role == 'superadmin' && isActive;
      }

      return true; // Semua
    }).toList();
  }

  void _navigateToUserDetail(dynamic user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)),
    );
    if (result == true) {
      _fetchUsers();
      _fetchUnapprovedUsers();
    }
  }

  void _navigateToUserForm([dynamic user]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserFormScreen(userToEdit: user)),
    );
    if (result == true) {
      _fetchUsers();
      _fetchUnapprovedUsers();
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
      builder: (_) => _UserFabMenuSheet(
        isSuperadmin: _isSuperadmin,
        onAddUser: () {
          if (_isSuperadmin) {
            Navigator.pop(context);
            _navigateToUserForm();
          }
        },
        onRefreshData: () {
          Navigator.pop(context);
          _fetchUsers();
          _fetchUnapprovedUsers();
          _fetchRejectedUsers();
        },
        onSearch: () {
          Navigator.pop(context);
          setState(() {
            _isSearching = true;
          });
          FocusScope.of(context).requestFocus(_searchFocusNode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Admin & Superadmin can enter. Others blocked.
    // If _isSuperadmin is false here, it means we might be admin or unauthorized.
    // Let's check more strictly.
    // Actually, _checkAccessAndLoad already handles the logic.
    // We just need to make sure we don't show the blank screen if not superadmin.

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Cari user...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  style: const TextStyle(color: Colors.black87),
                )
              : const Text(
                  'User Management',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
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
              icon: Icon(
                _isSearching ? Icons.search : Icons.search,
                color: _blue,
              ),
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
            labelColor: _blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _blue,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: [
              const Tab(text: 'Daftar'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Approval'),
                    if (_unapprovedUsers.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _unapprovedUsers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'History Ditolak'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserListTab(),
            _buildApprovalTab(),
            _buildRejectedHistoryTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openFabMenu,
          backgroundColor: const Color(0xFF1A56C4),
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
              _UserNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                currentIndex: 4,
                onTap: _onTabTapped,
              ),
              _UserNavItem(
                icon: Icons.article_outlined,
                label: 'News',
                index: 1,
                currentIndex: 4,
                onTap: _onTabTapped,
              ),
              const SizedBox(width: 56),
              _UserNavItem(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                index: 3,
                currentIndex: 4,
                onTap: _onTabTapped,
              ),
              _UserNavItem(
                icon: Icons.menu,
                label: 'Menu',
                index: 4,
                currentIndex: 4,
                onTap: _onTabTapped,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserListTab() {
    final users = _filteredUsers;
    final filters = ['Semua', 'User', 'Admin', 'Superadmin', 'Inactive'];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: filters.map((f) {
                final isSelected = _selectedFilter == f;
                String label = f;
                if (f == 'Semua') label = 'Semua (${_allUsers.length})';
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = f);
                    },
                    selectedColor: _blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? _blue : Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada pengguna ditemukan.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      padding: AppSafeInsets.bottomNavListPadding(context),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isActive =
                            user['is_active'] == 1 || user['is_active'] == true;
                        final role = (user['role'] ?? 'user').toString();
                        final name = user['full_name'] ?? 'Unknown';
                        final initials = name.isNotEmpty
                            ? name
                                .trim()
                                .split(' ')
                                .map((e) => e.isNotEmpty ? e[0] : '')
                                .take(2)
                                .join()
                                .toUpperCase()
                            : '?';
                        final dept = user['department'] ?? 'No Dept';
                        final jabatanVal = user['jabatan'] ??
                            user['position'] ??
                            user['job_title'] ??
                            'Staff';
                        final posisiVal =
                            user['position'] ?? user['job_title'] ?? 'Staff';
                        final displayJob = jabatanVal == posisiVal
                            ? jabatanVal
                            : '$jabatanVal • $posisiVal';

                        Color avatarColor = Colors.blue;
                        if (role == 'superadmin') avatarColor = Colors.purple;
                        if (role == 'admin') avatarColor = Colors.orange;
                        if (!isActive) avatarColor = Colors.grey;

                        return GestureDetector(
                          onTap: () => _navigateToUserDetail(user),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: avatarColor,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$displayJob • $dept',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Inactive',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: avatarColor.withValues(
                                              alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          role.isEmpty
                                              ? ""
                                              : "${role[0].toUpperCase()}${role.substring(1).toLowerCase()}",
                                          style: TextStyle(
                                            color: avatarColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Menampilkan ${users.length} dari ${_allUsers.length} pengguna',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildApprovalTab() {
    if (_isLoadingUnapproved) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_unapprovedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Semua pengguna sudah disetujui',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSafeInsets.bottomNavListPadding(context),
      itemCount: _unapprovedUsers.length,
      itemBuilder: (context, index) {
        final user = _unapprovedUsers[index];
        final name = user['full_name'] ?? 'Unknown';
        final initials = name.isNotEmpty
            ? name
                .trim()
                .split(' ')
                .map((e) => e.isNotEmpty ? e[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : '?';
        final email = user['personal_email'] ?? user['email'] ?? '-';

        return GestureDetector(
          onTap: () => _navigateToUserDetail(user),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.orange.withValues(alpha: 0.1),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'NIK: ${user['employee_id'] ?? '-'}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user['company'] ?? '-',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isSuperadmin) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectUser(user['id'].toString()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Reject',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                _approveUser(user['id'].toString()),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Approve',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRejectedHistoryTab() {
    if (_isLoadingRejected) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rejectedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat penolakan',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSafeInsets.bottomNavListPadding(context),
      itemCount: _rejectedUsers.length,
      itemBuilder: (context, index) {
        final log = _rejectedUsers[index];
        final name = log['full_name'] ?? 'Unknown';
        final nik = log['employee_id'] ?? '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () =>
                _navigateToUserDetail(log), // Passing log as user object
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'NIK: $nik • ${log['company'] ?? '-'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (log['rejection_reason'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Alasan: ${log['rejection_reason']}',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── User Detail Screen ──────────────────────────────────────────────────────

class UserDetailScreen extends StatefulWidget {
  final dynamic user;
  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  static const _blue = Color(0xFF1A56C4);
  late String _selectedRole;
  late bool _isActive;
  bool _isLoading = false;
  bool _isSuperadmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _selectedRole = (widget.user['role'] ?? 'user').toString().toLowerCase();
    _isActive =
        widget.user['is_active'] == 1 || widget.user['is_active'] == true;
  }

  Future<void> _checkAccess() async {
    final user = await StorageService.getUser();
    if (mounted) {
      setState(() {
        _isSuperadmin = user?['role']?.toString().toLowerCase() == 'superadmin';
      });
    }
  }

  Future<void> _approveUser() async {
    setState(() => _isLoading = true);
    final response = await ApiService.put(
      '/admin/users/${widget.user['id']}/approve',
      {},
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengguna berhasil disetujui!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.errorMessage ?? 'Gagal menyetujui.')),
        );
      }
    }
  }

  Future<void> _rejectUser() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Tolak Pendaftaran',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Berikan alasan penolakan (opsional):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Contoh: Data tidak valid atau bukan karyawan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final response = await ApiService.post(
        '/admin/users/${widget.user['id']}/reject',
        {'reason': reasonCtrl.text.trim()},
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pendaftaran ditolak. Email notifikasi telah dikirim.',
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.errorMessage ?? 'Gagal menolak.')),
          );
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      // Include all fields because backend validation might require them for PUT
      final data = {
        'full_name': widget.user['full_name'],
        'employee_id': widget.user['employee_id'],
        'personal_email': widget.user['personal_email'] ?? widget.user['email'],
        'phone_number': widget.user['phone_number'],
        'department': widget.user['department'],
        'jabatan': widget.user['jabatan'] ??
            widget.user['position'] ??
            widget.user['job_title'] ??
            '',
        'position': widget.user['position'] ?? widget.user['job_title'] ?? '',
        'company': widget.user['company'],
        'tipe_afiliasi': widget.user['tipe_afiliasi'],
        'role': _selectedRole,
        'is_active': _isActive ? 1 : 0,
      };

      final response = await ApiService.put(
        '/admin/users/${widget.user['id']}',
        data,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perubahan berhasil disimpan')),
          );
          Navigator.pop(context, true);
        } else {
          // Show the specific error if available
          String errorMsg = response.errorMessage ?? 'Gagal menyimpan';
          if (response.data != null && response.data['message'] != null) {
            errorMsg = response.data['message'];
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Pengguna',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'Yakin ingin menghapus pengguna ini secara permanen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final response = await ApiService.delete(
          '/admin/users/${widget.user['id']}',
        );
        if (mounted) {
          if (response.success) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Pengguna dihapus')));
            Navigator.pop(context, true);
          } else {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.errorMessage ?? 'Gagal menghapus'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _openDetailFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetailFabMenuSheet(
        onEdit: () async {
          Navigator.pop(context);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserFormScreen(userToEdit: widget.user),
            ),
          );
          if (result == true && mounted) Navigator.pop(context, true);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteUser();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['full_name'] ?? 'Unknown';
    final initials = name.isNotEmpty
        ? name
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';
    final dept = widget.user['department'] ?? 'No Dept';
    final jabatanVal = widget.user['jabatan'] ??
        widget.user['position'] ??
        widget.user['job_title'] ??
        'Staff';
    final posisiVal =
        widget.user['position'] ?? widget.user['job_title'] ?? 'Staff';
    final displayJob =
        jabatanVal == posisiVal ? jabatanVal : '$jabatanVal / $posisiVal';
    final role = (widget.user['role'] ?? 'user').toString().toLowerCase();
    final isLogEntry = widget.user['registration_status'] == 'rejected' ||
        widget.user.containsKey('rejected_at');

    Color avatarColor = Colors.green;
    if (role == 'superadmin') avatarColor = Colors.purple;
    if (role == 'admin') avatarColor = Colors.orange;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'User Detail',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: avatarColor,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.work_outline,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$displayJob • $dept',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatusBadge(
                              role.isEmpty
                                  ? ""
                                  : "${role[0].toUpperCase()}${role.substring(1).toLowerCase()}",
                              Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(
                              _isActive ? 'AKTIF' : 'INAKTIF',
                              _isActive ? Colors.green : Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLogEntry) ...[
                    _buildSectionTitle('ALASAN PENOLAKAN'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        widget.user['rejection_reason'] ??
                            'Tidak ada alasan yang diberikan.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('INFORMASI PENGGUNA'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDetailItem(
                          Icons.badge_outlined,
                          'NIK / Employee ID',
                          widget.user['employee_id'] ?? '-',
                        ),
                        _buildDetailDivider(),
                        _buildDetailItem(
                          Icons.email_outlined,
                          'Email Pribadi',
                          widget.user['personal_email'] ??
                              widget.user['email'] ??
                              '-',
                        ),
                        _buildDetailDivider(),
                        _buildDetailItem(
                          Icons.phone_outlined,
                          'Nomor HP',
                          widget.user['phone_number'] ?? '-',
                        ),
                        _buildDetailDivider(),
                        _buildDetailItem(
                          Icons.business_outlined,
                          'Perusahaan',
                          widget.user['company'] ?? '-',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!isLogEntry) ...[
                    if (widget.user['registration_status'] != 'rejected') ...[
                      _buildSectionTitle('PENGATURAN AKSES & ROLE'),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          _buildModernRoleCard(
                            'user',
                            'User',
                            'Akses dasar untuk pelaporan hazard.',
                            Icons.person_outline,
                          ),
                          const SizedBox(height: 12),
                          _buildModernRoleCard(
                            'admin',
                            'Admin',
                            'Kelola data, approval, dan laporan.',
                            Icons.admin_panel_settings_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildModernRoleCard(
                            'superadmin',
                            'Superadmin',
                            'Akses penuh ke seluruh sistem.',
                            Icons.security_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (_isSuperadmin &&
                          !_isActive &&
                          widget.user['registration_status'] == 'pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _rejectUser,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Reject Registration',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _approveUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Approve User',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_isSuperadmin)
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _isActive = !_isActive);
                              },
                              icon: Icon(
                                _isActive
                                    ? Icons.lock_outline
                                    : Icons.lock_open,
                                color: Colors.grey.shade700,
                                size: 18,
                              ),
                              label: Text(
                                _isActive ? 'Deactivate' : 'Activate',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save, size: 18),
                              label: const Text(
                                'Simpan Perubahan',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                  SizedBox(
                    height: AppSafeInsets.bottomNavScrollPadding(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isSuperadmin
          ? FloatingActionButton(
              onPressed: _openDetailFabMenu,
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
            _UserNavItem(
              icon: Icons.home,
              label: 'Home',
              index: 0,
              currentIndex: 4,
              onTap: _onDetailTabTapped,
            ),
            _UserNavItem(
              icon: Icons.article_outlined,
              label: 'News',
              index: 1,
              currentIndex: 4,
              onTap: _onDetailTabTapped,
            ),
            const SizedBox(width: 56),
            _UserNavItem(
              icon: Icons.inbox_outlined,
              label: 'Inbox',
              index: 3,
              currentIndex: 4,
              onTap: _onDetailTabTapped,
            ),
            _UserNavItem(
              icon: Icons.menu,
              label: 'Menu',
              index: 4,
              currentIndex: 4,
              onTap: _onDetailTabTapped,
            ),
          ],
        ),
      ),
    );
  }

  void _onDetailTabTapped(int index) {
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

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDivider() =>
      Divider(height: 1, indent: 64, color: Colors.grey.shade100);

  Widget _buildModernRoleCard(
    String roleValue,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedRole == roleValue;
    return GestureDetector(
      onTap: _isSuperadmin
          ? () => setState(() => _selectedRole = roleValue)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _blue.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _blue : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _blue.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? _blue : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade400,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? _blue : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: _blue, size: 24)
            else
              Icon(
                Icons.circle_outlined,
                color: Colors.grey.shade300,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

// ── User Form Screen (CRUD Create/Edit) ─────────────────────────────────────

class UserFormScreen extends StatefulWidget {
  final dynamic userToEdit;
  const UserFormScreen({super.key, this.userToEdit});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  static const _blue = Color(0xFF1A56C4);
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _nikCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _workEmailCtrl;
  late TextEditingController _hpCtrl;
  late TextEditingController _jabatanCtrl;
  late TextEditingController _posisiCtrl;

  late TextEditingController _passwordCtrl;

  String _tipeAfiliasi = 'Owner';
  String? _selectedPerusahaan;
  String? _selectedPerusahaanKontraktor;
  String? _selectedSubKontraktor;
  String? _selectedDept;
  String _role = 'user';
  bool _isLoading = false;

  List<String> _ownerList = [];
  List<String> _kontraktorList = [];
  List<String> _subkontraktorList = [];
  List<String> _departemenList = [];

  Future<void> _fetchDepartments() async {
    try {
      final depts = await DepartmentService.getDepartments();
      if (mounted) {
        setState(() {
          _departemenList = depts.map((e) => e.name).toList();

          final d = widget.userToEdit?['department'] ?? '';
          if (d.isNotEmpty && !_departemenList.contains(d)) {
            _departemenList.add(d);
            _selectedDept = d;
          } else if (d.isNotEmpty) {
            _selectedDept = d;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching departments: $e');
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final owners = await CompanyService.getCompanies(
        category: 'owner',
        active: true,
      );
      final contractors = await CompanyService.getCompanies(
        category: 'kontraktor',
        active: true,
      );
      final subContractors = await CompanyService.getCompanies(
        category: 'subkontraktor',
        active: true,
      );

      if (mounted) {
        setState(() {
          _ownerList = owners.map((e) => e.name).toList();
          _kontraktorList = contractors.map((e) => e.name).toList();
          _subkontraktorList = subContractors.map((e) => e.name).toList();

          // Ensure edited user's values are in the list if not present
          final p = widget.userToEdit?['company'] ?? '';
          if (p.isNotEmpty && !_ownerList.contains(p)) {
            _ownerList.add(p);
            _selectedPerusahaan = p;
          } else if (p.isNotEmpty) {
            _selectedPerusahaan = p;
          }

          final pk = widget.userToEdit?['perusahaan_kontraktor'] ?? '';
          if (pk.isNotEmpty && !_kontraktorList.contains(pk)) {
            _kontraktorList.add(pk);
            _selectedPerusahaanKontraktor = pk;
          } else if (pk.isNotEmpty) {
            _selectedPerusahaanKontraktor = pk;
          }

          final sk = widget.userToEdit?['sub_kontraktor'] ?? '';
          if (sk.isNotEmpty && !_subkontraktorList.contains(sk)) {
            _subkontraktorList.add(sk);
            _selectedSubKontraktor = sk;
          } else if (sk.isNotEmpty) {
            _selectedSubKontraktor = sk;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching companies: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
    _fetchDepartments();
    _nameCtrl = TextEditingController(
      text: widget.userToEdit?['full_name'] ?? '',
    );
    _nikCtrl = TextEditingController(
      text: widget.userToEdit?['employee_id'] ?? '',
    );
    _emailCtrl = TextEditingController(
      text: widget.userToEdit?['personal_email'] ??
          widget.userToEdit?['email'] ??
          '',
    );
    _workEmailCtrl = TextEditingController(
      text: widget.userToEdit?['work_email'] ?? '',
    );
    _hpCtrl = TextEditingController(
      text: widget.userToEdit?['phone_number'] ?? '',
    );
    _jabatanCtrl = TextEditingController(
      text: widget.userToEdit?['jabatan'] ?? '',
    );
    _posisiCtrl = TextEditingController(
      text: widget.userToEdit?['position'] ??
          widget.userToEdit?['job_title'] ??
          '',
    );

    _passwordCtrl = TextEditingController();

    _tipeAfiliasi = widget.userToEdit?['tipe_afiliasi'] ?? 'Owner';
    if (_tipeAfiliasi == 'Sub-Kontraktor') _tipeAfiliasi = 'Sub-Kont.';

    if (widget.userToEdit != null) {
      _role = (widget.userToEdit['role'] ?? 'user').toString().toLowerCase();
    }
    _checkFormAccess();
  }

  Future<void> _checkFormAccess() async {
    final user = await StorageService.getUser();
    final role = user?['role']?.toString().toLowerCase();
    if (role != 'superadmin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Akses Ditolak. Hanya Superadmin yang dapat mengubah data user.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'full_name': _nameCtrl.text.trim(),
      'employee_id': _nikCtrl.text.trim(),
      'personal_email': _emailCtrl.text.trim(),
      'work_email': _workEmailCtrl.text.trim(),
      'phone_number': _hpCtrl.text.trim(),
      'department': _selectedDept ?? '',
      'jabatan': _jabatanCtrl.text.trim(),
      'position': _posisiCtrl.text.trim(),
      'company': _selectedPerusahaan ?? '',
      'tipe_afiliasi':
          _tipeAfiliasi == 'Sub-Kont.' ? 'Sub-Kontraktor' : _tipeAfiliasi,
      'perusahaan_kontraktor': _selectedPerusahaanKontraktor,
      'sub_kontraktor': _selectedSubKontraktor,
      'role': _role,
    };

    if (_passwordCtrl.text.isNotEmpty) {
      data['password'] = _passwordCtrl.text;
    }

    try {
      dynamic response;
      if (widget.userToEdit != null) {
        response = await ApiService.put(
          '/admin/users/${widget.userToEdit['id']}',
          data,
        );
      } else {
        response = await ApiService.post('/admin/users', data);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.userToEdit == null
                    ? 'Pengguna dibuat'
                    : 'Pengguna diperbarui',
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.errorMessage ?? 'Gagal menyimpan')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.userToEdit != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Pengguna' : 'Tambah Pengguna',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: AppSafeInsets.pagePadding(
          context,
          left: 24,
          top: 24,
          right: 24,
          bottom: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField('Nama Lengkap', _nameCtrl, required: true),
              _buildField('NIK / Employee ID', _nikCtrl, required: true),
              _buildField('Nomor HP', _hpCtrl, required: true, isPhone: true),
              _buildField(
                'Email Pribadi',
                _emailCtrl,
                required: true,
                isEmail: true,
              ),
              _buildField(
                'Email Kantor (Opsional)',
                _workEmailCtrl,
                isEmail: true,
              ),
              if (!isEdit)
                _buildField(
                  'Password',
                  _passwordCtrl,
                  required: true,
                  obscure: true,
                )
              else
                _buildField(
                  'Password (Isi untuk mengganti)',
                  _passwordCtrl,
                  obscure: true,
                ),
              const Divider(height: 32),
              _buildAfiliasiRow(),
              _buildDropdown(
                'Perusahaan Owner',
                _selectedPerusahaan,
                _ownerList,
                (v) => setState(() => _selectedPerusahaan = v),
                required: true,
              ),
              if (_tipeAfiliasi == 'Kontraktor' || _tipeAfiliasi == 'Sub-Kont.')
                _buildDropdown(
                  'Perusahaan Kontraktor',
                  _selectedPerusahaanKontraktor,
                  _kontraktorList,
                  (v) => setState(() => _selectedPerusahaanKontraktor = v),
                ),
              if (_tipeAfiliasi == 'Sub-Kont.')
                _buildDropdown(
                  'Sub-Kontraktor',
                  _selectedSubKontraktor,
                  _subkontraktorList,
                  (v) => setState(() => _selectedSubKontraktor = v),
                ),
              const Divider(height: 32),
              _buildDropdown(
                'Departemen',
                _selectedDept,
                _departemenList,
                (v) => setState(() => _selectedDept = v),
                required: true,
              ),
              _buildField('Jabatan', _jabatanCtrl, required: true),
              _buildField('Posisi', _posisiCtrl, required: true),
              const SizedBox(height: 16),
              const Text(
                'Role Akses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(
                    value: 'superadmin',
                    child: Text('Superadmin'),
                  ),
                ],
                onChanged: (val) => setState(() => _role = val!),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Simpan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    bool isEmail = false,
    bool isPhone = false,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + (required ? ' *' : ''),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: isEmail
                ? TextInputType.emailAddress
                : (isPhone ? TextInputType.phone : TextInputType.text),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            validator: (v) {
              if (required && (v == null || v.trim().isEmpty)) {
                return 'Wajib diisi';
              }
              if (isPhone && v != null && v.trim().isNotEmpty) {
                if (!RegExp(r'^\+62[0-9]{8,13}$').hasMatch(v.trim())) {
                  return 'Gunakan format +62 (10-13 digit)';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + (required ? ' *' : ''),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
            validator: (v) {
              if (required && (v == null || v.isEmpty)) return 'Wajib dipilih';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAfiliasiRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipe Afiliasi *',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Owner', 'Kontraktor', 'Sub-Kont.'].map((type) {
                final isSelected = _tipeAfiliasi == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _tipeAfiliasi = type);
                    },
                    selectedColor: _blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── NAV ITEM ──────────────────────────────────────────────────────────────────
class _UserNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _UserNavItem({
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
            Icon(
              icon,
              color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
              size: 24,
            ),
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

// ── MENU TILE ─────────────────────────────────────────────────────────────────
class _UserMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _UserMenuTile({
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}

// ── FAB BOTTOM SHEET ──────────────────────────────────────────────────────────
class _UserFabMenuSheet extends StatelessWidget {
  final bool isSuperadmin;
  final VoidCallback onAddUser;
  final VoidCallback onRefreshData;
  final VoidCallback onSearch;

  const _UserFabMenuSheet({
    required this.isSuperadmin,
    required this.onAddUser,
    required this.onRefreshData,
    required this.onSearch,
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
              'Aksi Pengguna',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tambah User
          if (isSuperadmin) ...[
            _UserMenuTile(
              icon: Icons.person_add_outlined,
              iconBgColor: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1E88E5),
              title: 'Tambah Pengguna Baru',
              subtitle: 'Daftarkan admin atau user baru',
              onTap: onAddUser,
            ),
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          ],

          // Refresh / Read All
          _UserMenuTile(
            icon: Icons.refresh_rounded,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Refresh Data',
            subtitle: 'Muat ulang data pengguna terkini',
            onTap: onRefreshData,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),

          // Search
          _UserMenuTile(
            icon: Icons.search_rounded,
            iconBgColor: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFFF9800),
            title: 'Cari Pengguna',
            subtitle: 'Cari berdasarkan nama atau NIK',
            onTap: onSearch,
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

// ── Detail Screen FAB Menu Sheet ──────────────────────────────────────────────
class _DetailFabMenuSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DetailFabMenuSheet({required this.onEdit, required this.onDelete});

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
              'Aksi User',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Edit
          _UserMenuTile(
            icon: Icons.edit_outlined,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1E88E5),
            title: 'Edit Data Pengguna',
            subtitle: 'Ubah informasi dan role pengguna ini',
            onTap: onEdit,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),

          // Delete
          _UserMenuTile(
            icon: Icons.delete_outline_rounded,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFE53935),
            title: 'Hapus Pengguna',
            subtitle: 'Hapus pengguna ini secara permanen',
            onTap: onDelete,
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
