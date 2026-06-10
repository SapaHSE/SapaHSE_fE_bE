import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/access_permissions.dart';
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
    final jabCtrl = TextEditingController(text: user?.jabatan);
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
    Map<String, bool> accessPermissions = normalizeAccessPermissions(
      user?.accessPermissions,
      role: currentRole,
    );
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
        builder: (context, setModalState) {
          final dialogWidth = _dialogWidth(context);
          final isCompact = dialogWidth < 640;

          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              user == null ? 'Tambah Akun Pengguna' : 'Edit Pengguna',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0,
              ),
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormSection(
                      title: 'Identitas',
                      icon: Icons.badge_outlined,
                      child: Column(
                        children: [
                          _buildResponsiveFieldRow(
                            isCompact: isCompact,
                            children: [
                              _formField(nameCtrl, 'Nama Lengkap',
                                  Icons.person_outline),
                              _formField(empIdCtrl, 'NIK / ID Karyawan',
                                  Icons.badge_outlined),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildResponsiveFieldRow(
                            isCompact: isCompact,
                            children: [
                              _formField(personalEmailCtrl, 'Email Pribadi',
                                  Icons.email_outlined),
                              _formField(workEmailCtrl, 'Email Kerja',
                                  Icons.work_outline),
                            ],
                          ),
                          if (user == null) ...[
                            const SizedBox(height: 12),
                            _formField(
                                passwordCtrl, 'Password', Icons.lock_outline,
                                obscure: true),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFormSection(
                      title: 'Afiliasi Kerja',
                      icon: Icons.business_center_outlined,
                      child: Column(
                        children: [
                          _buildResponsiveFieldRow(
                            isCompact: isCompact,
                            children: [
                              _formField(phoneCtrl, 'No. Telepon',
                                  Icons.phone_android_outlined),
                              _companyDropdown(
                                selectedCompany: selectedCompany,
                                companies: companies,
                                onChanged: (v) =>
                                    setModalState(() => selectedCompany = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildResponsiveFieldRow(
                            isCompact: isCompact,
                            children: [
                              _departmentDropdown(
                                selectedDept: selectedDept,
                                departments: departments,
                                onChanged: (v) =>
                                    setModalState(() => selectedDept = v),
                              ),
                              _formField(jabCtrl, 'Jabatan',
                                  Icons.work_history_outlined),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _formField(
                              posCtrl, 'Posisi', Icons.assignment_ind_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFormSection(
                      title: 'Role & Status',
                      icon: Icons.admin_panel_settings_outlined,
                      child: _buildResponsiveFieldRow(
                        isCompact: isCompact,
                        children: [
                          _roleDropdown(
                            currentRole: currentRole,
                            onChanged: (v) => setModalState(() {
                              currentRole = v!;
                              accessPermissions =
                                  defaultAccessPermissionsForRole(currentRole);
                            }),
                          ),
                          _buildActiveStatusTile(
                            isActive: isActive,
                            onChanged: (v) => setModalState(() => isActive = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAccessPermissionPanel(
                      permissions: accessPermissions,
                      locked: currentRole.toLowerCase() == 'superadmin',
                      onChanged: (key, value) => setModalState(() {
                        accessPermissions[key] = value;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              OutlinedButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton.icon(
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
                          'jabatan': jabCtrl.text,
                          'company': selectedCompany,
                          'department': selectedDept,
                          'role': currentRole,
                          'access_permissions': accessPermissions,
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
                                  content: Text(res.errorMessage ??
                                      'Gagal menyimpan data'),
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
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                  elevation: 0,
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text(
                  'Simpan',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
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
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF1D4ED8), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  double _dialogWidth(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width - 40;
    return availableWidth.clamp(300.0, 820.0).toDouble();
  }

  Widget _buildResponsiveFieldRow({
    required bool isCompact,
    required List<Widget> children,
  }) {
    if (isCompact) {
      return Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _companyDropdown({
    required String? selectedCompany,
    required List<String> companies,
    required ValueChanged<String?> onChanged,
  }) {
    return _dropdownField(
      label: 'Perusahaan',
      icon: Icons.business_outlined,
      value: selectedCompany,
      items: companies,
      onChanged: onChanged,
    );
  }

  Widget _departmentDropdown({
    required String? selectedDept,
    required List<String> departments,
    required ValueChanged<String?> onChanged,
  }) {
    return _dropdownField(
      label: 'Departemen',
      icon: Icons.groups_outlined,
      value: selectedDept,
      items: departments,
      onChanged: onChanged,
    );
  }

  Widget _roleDropdown({
    required String currentRole,
    required ValueChanged<String?> onChanged,
  }) {
    return _dropdownField(
      label: 'Role',
      icon: Icons.security_outlined,
      value: currentRole,
      items: const ['admin', 'superadmin', 'user'],
      itemLabelBuilder: (value) => value.toUpperCase(),
      onChanged: onChanged,
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String value)? itemLabelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: _fieldDecoration(label: label, icon: icon),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF64748B),
        size: 22,
      ),
      borderRadius: BorderRadius.circular(14),
      dropdownColor: Colors.white,
      menuMaxHeight: 320,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      selectedItemBuilder: (context) => items
          .map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                itemLabelBuilder?.call(item) ?? item,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(
                  itemLabelBuilder?.call(item) ?? item,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF1D4ED8),
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
      ),
    );
  }

  Widget _buildActiveStatusTile({
    required bool isActive,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SwitchListTile(
        title: const Text(
          'Status Aktif',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          isActive
              ? 'Akun dapat login dan menggunakan aplikasi.'
              : 'Akun tidak dapat login.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        value: isActive,
        activeThumbColor: const Color(0xFF1D4ED8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildAccessPermissionPanel({
    required Map<String, bool> permissions,
    required bool locked,
    required void Function(String key, bool value) onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hak Akses Modul',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Aktifkan modul yang boleh dikelola akun ini.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (locked) ...[
            const SizedBox(height: 10),
            const Text(
              'Superadmin otomatis memiliki semua akses.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 10.0;
              final useGrid = constraints.maxWidth >= 640;
              final itemWidth = useGrid
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: accessPermissionOptions.map((option) {
                  final value = locked || (permissions[option.key] ?? false);
                  return SizedBox(
                    width: itemWidth,
                    child: _buildAccessPermissionTile(
                      option: option,
                      value: value,
                      locked: locked,
                      onChanged: (nextValue) =>
                          onChanged(option.key, nextValue),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccessPermissionTile({
    required AccessPermissionOption option,
    required bool value,
    required bool locked,
    required ValueChanged<bool> onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 82),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              activeThumbColor: const Color(0xFF1D4ED8),
              onChanged: locked ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessSummary(Map<String, bool> permissions) {
    final activeOptions = accessPermissionOptions
        .where((option) => permissions[option.key] ?? false)
        .toList();

    if (activeOptions.isEmpty) {
      return const Text(
        'Tidak ada',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      );
    }

    final visibleOptions = activeOptions.take(3).toList();
    final remainingCount = activeOptions.length - visibleOptions.length;

    return SizedBox(
      width: 260,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ...visibleOptions.map(
            (option) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                option.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
          ),
          if (remainingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
        ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final searchField = TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none),
          );
          final addButton = ElevatedButton.icon(
            onPressed: () => _showUserForm(),
            icon: const Icon(Icons.person_add),
            label: const Text('Tambah Akun'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                addButton,
              ],
            );
          }

          return Row(children: [
            Expanded(child: searchField),
            const SizedBox(width: 16),
            addButton,
          ]);
        },
      ),
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

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Theme(
            data: Theme.of(context)
                .copyWith(dividerColor: const Color(0xFFF1F5F9)),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Akses')),
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
                  DataCell(_buildAccessSummary(u.accessPermissions)),
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
    if (!mounted) return;

    if (confirm == true) {
      final res = await ApiService.delete('/admin/users/${u.id}');
      if (!mounted) return;
      if (res.success) {
        _fetchUsers(page: _currentUserPage);
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
