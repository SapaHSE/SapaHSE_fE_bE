import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'dashboard_widgets.dart';

class DashboardUsersModule extends StatefulWidget {
  const DashboardUsersModule({super.key});

  @override
  State<DashboardUsersModule> createState() => _DashboardUsersModuleState();
}

class _DashboardUsersModuleState extends State<DashboardUsersModule> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserModel> _users = [];
  bool _isLoadingUsers = false;
  int _userTotalPages = 1;
  int _currentUserPage = 1;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
      _fetchUsers(page: 1);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({int page = 1}) async {
    setState(() => _isLoadingUsers = true);
    final query = '?page=$page&search=$_searchQuery';
    final response = await ApiService.get('/admin/users$query');
    if (response.success && mounted) {
      try {
        dynamic dataObj = response.data;
        final dynamic rawData = (dataObj is Map && dataObj.containsKey('data'))
            ? dataObj['data']
            : dataObj;

        List<UserModel> parsedUsers = [];
        int total = 1;
        int current = 1;

        if (rawData is Map<String, dynamic>) {
          parsedUsers = (rawData['data'] as List? ?? [])
              .map((u) => UserModel.fromJson(u))
              .toList();
          total = int.tryParse(rawData['last_page']?.toString() ?? '1') ?? 1;
          current =
              int.tryParse(rawData['current_page']?.toString() ?? '1') ?? 1;
        } else if (rawData is List) {
          parsedUsers = rawData.map((u) => UserModel.fromJson(u)).toList();
          if (dataObj is Map) {
            final meta = dataObj['meta'];
            total = int.tryParse(meta?['last_page']?.toString() ?? '1') ?? 1;
            current =
                int.tryParse(meta?['current_page']?.toString() ?? '1') ?? 1;
          }
        }

        setState(() {
          _users = parsedUsers;
          _userTotalPages = total;
          _currentUserPage = current;
          _isLoadingUsers = false;
        });
      } catch (e) {
        debugPrint('Error parsing users: $e');
        setState(() => _isLoadingUsers = false);
      }
    } else if (mounted) {
      setState(() => _isLoadingUsers = false);
    }
  }

  void _showUserForm({UserModel? user}) {
    final nameCtrl = TextEditingController(text: user?.fullName);
    final personalEmailCtrl = TextEditingController(text: user?.personalEmail);
    final workEmailCtrl = TextEditingController(text: user?.workEmail);
    final empIdCtrl = TextEditingController(text: user?.employeeId);
    final phoneCtrl = TextEditingController(text: user?.phoneNumber);
    final posCtrl = TextEditingController(text: user?.position);
    final passwordCtrl = TextEditingController();
    String? selectedCompany = user?.company;
    if (selectedCompany != null && selectedCompany.isNotEmpty) {
      selectedCompany = selectedCompany.toUpperCase();
    }
    String? selectedDept = user?.department;
    if (selectedDept != null && selectedDept.isNotEmpty) {
      selectedDept = selectedDept.toUpperCase();
    }

    String currentRole = user?.role ?? 'user';
    bool isActive = user?.isActive ?? true;
    bool isLoading = false;

    final List<String> companies = [
      'PT BUKIT BAIDURI ENERGI',
      'PT KHOTAI MAKMUR INSAN ABADI'
    ];
    final List<String> departments = [
      'HSE',
      'IT',
      'MINING',
      'HR',
      'FINANCE',
      'MAINTENANCE',
      'OPERATIONAL',
      'SECURITY',
      'LOGISTIC'
    ];

    // Ensure selected values are in the list or null
    if (selectedCompany != null && !companies.contains(selectedCompany)) {
      companies.add(selectedCompany);
    }
    if (selectedDept != null && !departments.contains(selectedDept)) {
      departments.add(selectedDept);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(user == null ? 'Tambah Akun Pengguna' : 'Edit Pengguna',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _formField(nameCtrl, 'Nama Lengkap', Icons.person_outline),
                  const SizedBox(height: 12),
                  _formField(
                      empIdCtrl, 'NIK / ID Karyawan', Icons.badge_outlined),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _formField(personalEmailCtrl, 'Email Pribadi',
                            Icons.email_outlined)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _formField(
                            workEmailCtrl, 'Email Kerja', Icons.work_outline)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _formField(phoneCtrl, 'No. Telepon',
                            Icons.phone_android_outlined)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedCompany,
                        decoration: InputDecoration(
                          labelText: 'Perusahaan',
                          prefixIcon: const Icon(Icons.business_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: companies
                            .map((e) => DropdownMenuItem(
                                value: e,
                                child:
                                    Text(e, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => selectedCompany = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _formField(
                            posCtrl, 'Jabatan', Icons.work_history_outlined)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedDept,
                        decoration: InputDecoration(
                          labelText: 'Departemen',
                          prefixIcon: const Icon(Icons.groups_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: departments
                            .map((e) => DropdownMenuItem(
                                value: e,
                                child:
                                    Text(e, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedDept = v),
                      ),
                    ),
                  ]),
                  if (user == null) ...[
                    _formField(passwordCtrl, 'Password', Icons.lock_outline,
                        obscure: true),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: currentRole,
                    decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(Icons.security_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    items: ['admin', 'superadmin', 'user']
                        .map((e) => DropdownMenuItem(
                            value: e, child: Text(e.toUpperCase())))
                        .toList(),
                    onChanged: (v) => setModalState(() => currentRole = v!),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Status Aktif',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    value: isActive,
                    activeThumbColor: const Color(0xFF1D4ED8),
                    onChanged: (v) => setModalState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child:
                    const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      ApiResponse res;
                      final data = {
                        'full_name': nameCtrl.text,
                        'employee_id': empIdCtrl.text,
                        'personal_email': personalEmailCtrl.text,
                        'work_email': workEmailCtrl.text,
                        'phone_number': phoneCtrl.text,
                        'position': posCtrl.text,
                        'company': selectedCompany,
                        'department': selectedDept,
                        'role': currentRole,
                        'is_active': isActive ? 1 : 0,
                      };

                      if (user == null) {
                        data['password'] = passwordCtrl.text;
                        res = await ApiService.post('/admin/users', data);
                      } else {
                        res = await ApiService.put(
                            '/admin/users/${user.id}', data);
                      }

                      if (res.success && context.mounted) {
                        Navigator.pop(ctx);
                        _fetchUsers(page: _currentUserPage);
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => DashboardSuccessDialog(
                              title: 'Berhasil!',
                              message: user == null
                                  ? 'Akun pengguna baru telah berhasil didaftarkan.'
                                  : 'Data profil pengguna telah berhasil diperbarui.',
                            ),
                          );
                        }
                      } else if (context.mounted) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    res.errorMessage ?? 'Gagal menyimpan data'),
                                backgroundColor: Colors.red),
                          );
                        }
                        setModalState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DashboardSectionHeader(
          title: 'Manajemen Pengguna',
          subtitle: 'Atur hak akses dan data pekerja/admin sistem.'),
      const SizedBox(height: 24),
      _buildFilterBar(),
      const SizedBox(height: 24),
      if (_isLoadingUsers)
        const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator()))
      else
        Container(
          width: double.infinity,
          decoration: dashboardCardDecoration(radius: 20),
          child: Column(children: [
            _buildResponsiveList(),
            _buildPaginationFooter(),
          ]),
        ),
    ]);
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: dashboardCardDecoration(radius: 20),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => _showUserForm(),
          icon: const Icon(Icons.person_add),
          label: const Text('Tambah Akun'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }

  Widget _buildResponsiveList() {
    final isMobile = MediaQuery.of(context).size.width < 1100;
    if (_users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(
            child: Text('No users found.',
                style: TextStyle(color: Color(0xFF94A3B8)))),
      );
    }

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: _users
              .map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: DashboardUserCard(
                        user: u,
                        onEdit: () => _showUserForm(user: u),
                        onDelete: () => _confirmDelete(u)),
                  ))
              .toList(),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: const Color(0xFFF1F5F9)),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Emp. ID')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: _users.map((u) {
            return DataRow(cells: [
              DataCell(Row(children: [
                DashboardUserAvatar(name: u.fullName, size: 32),
                const SizedBox(width: 10),
                Text(u.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
              DataCell(DashboardRoleBadge(u.role)),
              DataCell(Text(u.employeeId)),
              DataCell(Text(u.personalEmail ?? '')),
              DataCell(Text(u.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                      color: u.isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold))),
              DataCell(Row(children: [
                IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showUserForm(user: u)),
                IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                    onPressed: () => _confirmDelete(u)),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(UserModel u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => DashboardConfirmDialog(
        title: 'Hapus Pengguna',
        message:
            'Apakah Anda yakin ingin menghapus akun "${u.fullName}"? Akses pengguna ini akan dicabut sepenuhnya.',
      ),
    );

    if (confirm == true) {
      final res = await ApiService.delete('/admin/users/${u.id}');
      if (res.success && context.mounted) {
        _fetchUsers(page: _currentUserPage);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => const DashboardSuccessDialog(
              title: 'Dihapus!',
              message: 'Akun pengguna telah berhasil dihapus dari sistem.',
            ),
          );
        }
      }
    }
  }

  Widget _buildPaginationFooter() {
    if (_userTotalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page $_currentUserPage of $_userTotalPages',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Row(children: [
            DashboardPagerButton(
                icon: Icons.chevron_left,
                onPressed: _currentUserPage > 1
                    ? () => _fetchUsers(page: _currentUserPage - 1)
                    : null),
            const SizedBox(width: 8),
            DashboardPagerButton(
                icon: Icons.chevron_right,
                onPressed: _currentUserPage < _userTotalPages
                    ? () => _fetchUsers(page: _currentUserPage + 1)
                    : null),
          ]),
        ],
      ),
    );
  }
}
