import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../widgets/sapa_hse_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _topTabController;
  XFile? _avatarFile;


  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _topTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _topTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _avatarFile = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        child: Column(
          children: [
            // ── Custom Header with TabBar (Replacing AppBar) ────────────────
            Container(
              color: const Color(0xFFF8F8F8),
              child: Column(
                children: [
                  SapaHseHeader(
                    isSearching: _isSearching,
                    searchController: _searchController,
                    searchHint: 'Cari di profil...',
                    showSearch: false,
                    onSearchToggle: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                        }
                      });
                    },
                  ),
                  TabBar(
                    controller: _topTabController,
                    labelColor: const Color(0xFF1565C0),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xFF1565C0),
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Profile'),
                      Tab(text: 'App'),
                      Tab(text: 'Settings'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _topTabController,
                children: [
                  _ProfileTab(avatarFile: _avatarFile, onPickImage: _pickImage),
                  const _AppTab(),
                  const _SettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatefulWidget {
  final XFile? avatarFile;
  final VoidCallback onPickImage;
  const _ProfileTab({required this.avatarFile, required this.onPickImage});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  int _selectedSubTab = 0;
  bool _isLoading = true;
  String? _error;

  ProfileData? _profileData;
  String _name = '';
  String _position = '';
  String _department = '';
  String _company = '';
  String _email = '';
  String _phone = '';
  String _employeeId = '';
  String? _profilePhoto;

  final List<Map<String, dynamic>> _subTabs = [
    {'label': 'Biodata', 'icon': Icons.person},
    {'label': 'License', 'icon': Icons.credit_card},
    {'label': 'Certification', 'icon': Icons.workspace_premium},
    {'label': 'Medical', 'icon': Icons.medical_services},
  ];

  ImageProvider? _getAvatarImage() {
    if (widget.avatarFile != null) {
      final file = File(widget.avatarFile!.path);
      return FileImage(file);
    }
    if (_profilePhoto != null && _profilePhoto!.isNotEmpty) {
      return NetworkImage(_profilePhoto!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ProfileService.getProfile();

    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _profileData = result.data!;
        _name = result.data!.fullName;
        _position = result.data!.position ?? '';
        _department = result.data!.department ?? '';
        _company = result.data!.company ?? '';
        _email = result.data!.email;
        _phone = result.data!.phoneNumber ?? '';
        _employeeId = result.data!.employeeId;
        _profilePhoto = result.data!.profilePhoto;
        _isLoading = false;
      });
    } else {
      // Check if unauthorized - redirect to login
      if (result.errorMessage?.toLowerCase().contains('unauthenticated') ==
              true ||
          result.errorMessage?.toLowerCase().contains('tidak sah') == true) {
        _handleLogout();
        return;
      }
      setState(() {
        _error = result.errorMessage ?? 'Gagal memuat profil';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await StorageService.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _name);
    final positionCtrl = TextEditingController(text: _position);
    final deptCtrl = TextEditingController(text: _department);
    final companyCtrl = TextEditingController(text: _company);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_outlined,
                color: Color(0xFF1565C0), size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Edit Profil',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogField(
                  label: 'Nama Lengkap',
                  ctrl: nameCtrl,
                  icon: Icons.person_outline),
              const SizedBox(height: 14),
              _DialogField(
                  label: 'Jabatan',
                  ctrl: positionCtrl,
                  icon: Icons.work_outline),
              const SizedBox(height: 14),
              _DialogField(
                  label: 'Departemen',
                  ctrl: deptCtrl,
                  icon: Icons.business_outlined),
              const SizedBox(height: 14),
              _DialogField(
                  label: 'Perusahaan (PT)',
                  ctrl: companyCtrl,
                  icon: Icons.apartment_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _name =
                    nameCtrl.text.trim().isEmpty ? _name : nameCtrl.text.trim();
                _position = positionCtrl.text.trim().isEmpty
                    ? _position
                    : positionCtrl.text.trim();
                _department = deptCtrl.text.trim().isEmpty
                    ? _department
                    : deptCtrl.text.trim();
                _company = companyCtrl.text.trim().isEmpty
                    ? _company
                    : companyCtrl.text.trim();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Profil berhasil diperbarui'),
                  ]),
                  backgroundColor: const Color(0xFF1565C0),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1565C0)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Avatar + name ──────────────────────────────────────────
          Container(
            width: double.infinity,
            color: const Color(0xFFF0F0F0),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    onPressed: _showEditProfileDialog,
                    icon: const Icon(Icons.edit_outlined,
                        color: Color(0xFF1565C0)),
                    tooltip: 'Edit Profil',
                  ),
                ),
                Column(
                  children: [
                    GestureDetector(
                      onTap: widget.onPickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: const Color(0xFFD0D0D0),
                            backgroundImage: _getAvatarImage(),
                            child: widget.avatarFile == null &&
                                    (_profilePhoto == null ||
                                        _profilePhoto!.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 60, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1565C0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _position,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _department,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _company,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ],
            ),
          ),

          // ── Sub-tab icon buttons ───────────────────────────────────
          Container(
            color: const Color(0xFFF0F0F0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(_subTabs.length, (i) {
                final isActive = _selectedSubTab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSubTab = i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFBDBDBD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _subTabs[i]['icon'] as IconData,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _subTabs[i]['label'] as String,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 4),

          // ── Sub-tab content ────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.02, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: SizedBox(
              key: ValueKey(_selectedSubTab),
              child: _buildSubTabContent(),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return _BiodataContent(
          employeeId: _employeeId,
          email: _email,
          phone: _phone,
        );
      case 1:
        return _LicenseContent(licenses: _profileData?.licenses ?? []);
      case 2:
        return _CertificationContent(
            certifications: _profileData?.certifications ?? []);
      case 3:
        return _MedicalContent(medicals: _profileData?.medicals ?? []);
      default:
        return const SizedBox();
    }
  }
}

// ── Dialog field helper ───────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  const _DialogField(
      {required this.label, required this.ctrl, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
          ),
        ),
      ],
    );
  }
}

// ── BIODATA ───────────────────────────────────────────────────────────────────
class _BiodataContent extends StatefulWidget {
  final String employeeId;
  final String email;
  final String phone;

  const _BiodataContent({
    required this.employeeId,
    required this.email,
    required this.phone,
  });

  @override
  State<_BiodataContent> createState() => _BiodataContentState();
}

class _BiodataContentState extends State<_BiodataContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.email);
    _phoneCtrl = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final result = await ProfileService.updateProfile(
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
              ? 'Profil berhasil disimpan'
              : (result.errorMessage ?? 'Gagal menyimpan')),
          backgroundColor:
              result.success ? const Color(0xFF1565C0) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormField(
              label: 'NIK',
              child: _ReadOnlyField(value: widget.employeeId),
            ),
          const SizedBox(height: 14),
          _FormField(
            label: 'Email Address',
            child: _EditableField(
                controller: _emailCtrl,
                hint: 'Masukkan email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email wajib diisi';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Format email tidak valid';
                  }
                  return null;
                }),
          ),
          const SizedBox(height: 14),
          _FormField(
            label: 'Telephone Number',
            child: _EditableField(
                controller: _phoneCtrl,
                hint: 'Masukkan nomor telepon',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(13)
                ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan Perubahan',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ── LICENSE ───────────────────────────────────────────────────────────────────
class _LicenseContent extends StatefulWidget {
  final List<UserLicense> licenses;

  const _LicenseContent({required this.licenses});

  @override
  State<_LicenseContent> createState() => _LicenseContentState();
}

class _LicenseContentState extends State<_LicenseContent> {
  late List<UserLicense> _licenses;

  @override
  void initState() {
    super.initState();
    _licenses = List.from(widget.licenses);
  }

  @override
  void didUpdateWidget(covariant _LicenseContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.licenses != widget.licenses) {
      _licenses = List.from(widget.licenses);
    }
  }

  void _showAddLicenseDialog() {
    final nameCtrl = TextEditingController();
    final noCtrl = TextEditingController();
    final expCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tambah License',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama License')),
            TextField(
                controller: noCtrl,
                decoration: const InputDecoration(labelText: 'Nomor License')),
            TextField(
                controller: expCtrl,
                decoration:
                    const InputDecoration(labelText: 'Tanggal Berlaku (Exp)')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final response = await ProfileService.updateProfile();
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    _licenses.insert(
                        0,
                        UserLicense(
                          id: '',
                          name: nameCtrl.text,
                          licenseNumber: noCtrl.text,
                          expiredAt: expCtrl.text.isEmpty ? null : expCtrl.text,
                          status: 'active',
                        ));
                  });
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showAddLicenseDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add License'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0)),
            ),
          ),
          ..._licenses.map((l) {
            final isActive = l.isActive;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFE3F2FD)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.credit_card,
                        color: isActive ? const Color(0xFF1565C0) : Colors.red,
                        size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('No: ${l.licenseNumber}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        Text('Exp: ${l.expiredAt ?? "-"}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF4CAF50) : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(isActive ? 'Aktif' : 'Kadaluarsa',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── CERTIFICATION ─────────────────────────────────────────────────────────────
class _CertificationContent extends StatefulWidget {
  final List<UserCertification> certifications;

  const _CertificationContent({required this.certifications});

  @override
  State<_CertificationContent> createState() => _CertificationContentState();
}

class _CertificationContentState extends State<_CertificationContent> {
  late List<UserCertification> _certs;

  @override
  void initState() {
    super.initState();
    _certs = List.from(widget.certifications);
  }

  @override
  void didUpdateWidget(covariant _CertificationContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.certifications != widget.certifications) {
      _certs = List.from(widget.certifications);
    }
  }

  void _showAddCertificationDialog() {
    final nameCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tambah Certification',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nama Sertifikasi')),
            TextField(
                controller: issuerCtrl,
                decoration: const InputDecoration(labelText: 'Penerbit')),
            TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(labelText: 'Tahun'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _certs.insert(
                      0,
                      UserCertification(
                        id: '',
                        name: nameCtrl.text,
                        issuer: issuerCtrl.text.isEmpty ? '-' : issuerCtrl.text,
                        year: int.tryParse(yearCtrl.text),
                        status: 'active',
                      ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showAddCertificationDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Certification'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0)),
            ),
          ),
          ..._certs.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium,
                        color: Color(0xFF6A1B9A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('Penerbit: ${c.issuer}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        Text('Tahun: ${c.year ?? "-"}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.isActive ? const Color(0xFF4CAF50) : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(c.isActive ? 'Aktif' : 'Kadaluarsa',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── MEDICAL ───────────────────────────────────────────────────────────────────
class _MedicalContent extends StatelessWidget {
  final List<UserMedical> medicals;

  const _MedicalContent({required this.medicals});

  McuStatus _parseMcuStatus(String? result) {
    if (result == null) return McuStatus.fitToWork;
    final lower = result.toLowerCase();
    if (lower.contains('fit to work') && !lower.contains('limit'))
      return McuStatus.fitToWork;
    if (lower.contains('fit with') ||
        lower.contains('limit') ||
        lower.contains('restriction')) return McuStatus.fitWithLimitation;
    if (lower.contains('not fit') || lower.contains('unfit'))
      return McuStatus.notFitToWork;
    return McuStatus.fitToWork;
  }

  @override
  Widget build(BuildContext context) {
    final latestMedical = medicals.isNotEmpty ? medicals.first : null;

    final records = [
      {'label': 'Golongan Darah', 'value': latestMedical?.bloodType ?? '-'},
      {'label': 'Tinggi Badan', 'value': latestMedical?.height ?? '-'},
      {'label': 'Berat Badan', 'value': latestMedical?.weight ?? '-'},
      {'label': 'Tekanan Darah', 'value': latestMedical?.bloodPressure ?? '-'},
      {'label': 'Alergi', 'value': latestMedical?.allergies ?? 'Tidak Ada'},
      {'label': 'MCU Terakhir', 'value': latestMedical?.checkupDate ?? '-'},
      {'label': 'Hasil MCU', 'value': latestMedical?.result ?? '-'},
      {
        'label': 'MCU Berikutnya',
        'value': latestMedical?.nextCheckupDate ?? '-'
      },
    ];

    final history = medicals
        .map((m) => _MedicalHistory(
              id: m.id,
              patientName: m.patientName ?? '',
              title: m.title ?? 'Medical Check-Up',
              date: m.checkupDate ?? '-',
              doctor: m.doctorName ?? '-',
              doctorContact: m.doctorContact ?? '-',
              facility: m.facilityName ?? '-',
              clinicContact: m.facilityContact ?? '-',
              mcuStatus: _parseMcuStatus(m.result),
              notes: m.doctorNotes ?? m.result ?? '',
              items: m.checklistItems
                  .map((i) => _CheckItem(i.label, i.done))
                  .toList(),
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Data medis dasar ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              children: List.generate(records.length, (i) {
                final r = records[i];
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    child: Row(children: [
                      Expanded(
                          flex: 2,
                          child: Text(r['label']!,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54))),
                      const Text(': ',
                          style:
                              TextStyle(fontSize: 13, color: Colors.black54)),
                      Expanded(
                          flex: 3,
                          child: Text(r['value']!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87))),
                    ]),
                  ),
                  if (i < records.length - 1)
                    Divider(
                        height: 1,
                        color: Colors.grey.shade100,
                        indent: 16,
                        endIndent: 16),
                ]);
              }),
            ),
          ),

          const SizedBox(height: 20),

          // ── Medical History header ─────────────────────────────────────
          Row(children: [
            const Text('Riwayat Pemeriksaan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A56C4).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${history.length} riwayat',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1A56C4),
                      fontWeight: FontWeight.bold)),
            ),
          ]),

          const SizedBox(height: 10),

          // ── History list ───────────────────────────────────────────────
          ...history.map((h) => _MedicalHistoryCard(history: h)),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Medical fitment status enum ──────────────────────────────────────────────
enum McuStatus {
  fitToWork,
  fitWithLimitation,
  notFitToWork,
}

extension McuStatusInfo on McuStatus {
  String get label {
    switch (this) {
      case McuStatus.fitToWork:
        return 'Fit to Work';
      case McuStatus.fitWithLimitation:
        return 'Fit with Limitation';
      case McuStatus.notFitToWork:
        return 'Not Fit to Work';
    }
  }

  Color get color {
    switch (this) {
      case McuStatus.fitToWork:
        return const Color(0xFF4CAF50); // Hijau
      case McuStatus.fitWithLimitation:
        return const Color(0xFFFF9800); // Oranye
      case McuStatus.notFitToWork:
        return const Color(0xFFF44336); // Merah
    }
  }

  IconData get icon {
    switch (this) {
      case McuStatus.fitToWork:
        return Icons.check_circle_outline;
      case McuStatus.fitWithLimitation:
        return Icons.warning_amber_outlined;
      case McuStatus.notFitToWork:
        return Icons.cancel_outlined;
    }
  }
}

// ── Medical history model ─────────────────────────────────────────────────────
class _CheckItem {
  final String label;
  final bool done;
  const _CheckItem(this.label, this.done);
}

class _MedicalHistory {
  final String id;
  final String patientName;
  final String title;
  final String date;
  final String doctor;
  final String doctorContact;
  final String facility;
  final String clinicContact;
  final McuStatus mcuStatus;
  final String notes;
  final List<_CheckItem> items;

  const _MedicalHistory({
    required this.id,
    required this.patientName,
    required this.title,
    required this.date,
    required this.doctor,
    required this.doctorContact,
    required this.facility,
    required this.clinicContact,
    required this.mcuStatus,
    required this.notes,
    required this.items,
  });
}

// ── Medical history card ──────────────────────────────────────────────────────
class _MedicalHistoryCard extends StatelessWidget {
  final _MedicalHistory history;
  const _MedicalHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final status = history.mcuStatus;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _MedicalDetailScreen(history: history)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(status.icon, color: status.color, size: 22),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(history.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 11, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(history.date,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 10),
                    const Icon(Icons.local_hospital_outlined,
                        size: 11, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(history.facility,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // MCU status badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(status.icon, size: 10, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(status.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Medical Detail Screen ─────────────────────────────────────────────────────
class _MedicalDetailScreen extends StatelessWidget {
  final _MedicalHistory history;
  const _MedicalDetailScreen({required this.history});

  @override
  Widget build(BuildContext context) {
    final done = history.items.where((i) => i.done).length;
    final total = history.items.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detail Pemeriksaan',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A56C4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.medical_services_outlined,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(history.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  // ── Nama Pasien ────────────────────────────────────────
                  _HeaderRow(
                      Icons.person_outline, 'Pasien', history.patientName),
                  const SizedBox(height: 6),
                  _HeaderRow(
                      Icons.calendar_today_outlined, 'Tanggal', history.date),
                  const SizedBox(height: 6),
                  _HeaderRow(Icons.medical_information_outlined, 'Dokter',
                      history.doctor),
                  const SizedBox(height: 6),
                  _HeaderRow(Icons.phone_outlined, 'Kontak Dokter',
                      history.doctorContact),
                  const SizedBox(height: 6),
                  _HeaderRow(Icons.local_hospital_outlined, 'Fasilitas',
                      history.facility),
                  const SizedBox(height: 6),
                  _HeaderRow(Icons.phone_outlined, 'Kontak Klinik',
                      history.clinicContact),
                  const SizedBox(height: 16),
                  // ── MCU Status ─────────────────────────────────────────
                  const Text('Status Kelaikan Kerja:',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _McuStatusChip(
                      status: McuStatus.fitToWork,
                      isSelected: history.mcuStatus == McuStatus.fitToWork,
                    ),
                    const SizedBox(width: 8),
                    _McuStatusChip(
                      status: McuStatus.fitWithLimitation,
                      isSelected:
                          history.mcuStatus == McuStatus.fitWithLimitation,
                    ),
                    const SizedBox(width: 8),
                    _McuStatusChip(
                      status: McuStatus.notFitToWork,
                      isSelected: history.mcuStatus == McuStatus.notFitToWork,
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Checklist progress ───────────────────────────────────────
            _SectionCard(
              title: 'Checklist Pemeriksaan',
              trailing: Text('$done/$total selesai',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A56C4),
                      fontWeight: FontWeight.w600)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(done == total
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF1A56C4)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Items
                  ...history.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: item.done
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: item.done
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : const Icon(Icons.remove,
                                    color: Colors.grey, size: 14),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: item.done
                                        ? Colors.black87
                                        : Colors.grey,
                                    decoration: item.done
                                        ? null
                                        : TextDecoration.lineThrough)),
                          ),
                          Text(item.done ? 'Selesai' : 'Tidak',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: item.done
                                      ? const Color(0xFF4CAF50)
                                      : Colors.grey)),
                        ]),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Catatan dokter ───────────────────────────────────────────
            _SectionCard(
              title: 'Catatan Dokter',
              child: Text(
                history.notes,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.6),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets for detail screen ─────────────────────────────────────────
class _HeaderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeaderRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: Colors.white60),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),
      ]);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (trailing != null) ...[const Spacer(), trailing!],
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _McuStatusChip extends StatelessWidget {
  final McuStatus status;
  final bool isSelected;
  const _McuStatusChip({required this.status, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? status.color.withValues(alpha: 0.2)
            : Colors.transparent,
        border: Border.all(
          color: isSelected ? status.color : Colors.white24,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon,
              size: 14, color: isSelected ? status.color : Colors.white60),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? status.color : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// APP TAB
// ══════════════════════════════════════════════════════════════════════════════
class _AppTab extends StatelessWidget {
  const _AppTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Aplikasi'),
          _SettingCard(children: [
            _MenuRow(
              icon: Icons.dashboard_outlined,
              iconColor: const Color(0xFF1A56C4),
              label: 'Dashboard Laporan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            _MenuRow(
              icon: Icons.health_and_safety_outlined,
              iconColor: const Color(0xFF4CAF50),
              label: 'Module Plugin',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Module Plugin akan segera hadir')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SETTINGS TAB
// ══════════════════════════════════════════════════════════════════════════════
class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _notifPush = true;
  String _language = 'Indonesia';
  bool _darkTheme = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Aplikasi'),
          _SettingCard(children: [
            _SwitchRow(
              icon: Icons.notifications_outlined,
              iconColor: const Color(0xFF1565C0),
              label: 'Notifikasi Push',
              subtitle: 'Terima notifikasi laporan & pengumuman',
              value: _notifPush,
              onChanged: (v) => setState(() => _notifPush = v),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            _SwitchRow(
              icon: Icons.dark_mode_outlined,
              iconColor: const Color(0xFF37474F),
              label: 'Tema Gelap',
              subtitle: 'Aktifkan mode dark theme',
              value: _darkTheme,
              onChanged: (v) => setState(() => _darkTheme = v),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            _DropdownRow(
              icon: Icons.language,
              iconColor: const Color(0xFF1A56C4),
              label: 'Bahasa Aplikasi',
              subtitle: 'Pilih bahasa tampilan',
              value: _language,
              items: const ['Indonesia', 'English'],
              onChanged: (v) {
                if (v != null) setState(() => _language = v);
              },
            ),
          ]),
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Akun'),
          _SettingCard(children: [
            _MenuRow(
              icon: Icons.lock_outline,
              iconColor: const Color(0xFF1565C0),
              label: 'Ubah Password',
              onTap: () => _showChangePasswordDialog(context),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            _MenuRow(
              icon: Icons.privacy_tip_outlined,
              iconColor: const Color(0xFF1A56C4),
              label: 'Privasi & Keamanan',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privasi & Keamanan')),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Sesi'),
          _SettingCard(children: [
            _MenuRow(
              icon: Icons.logout,
              iconColor: Colors.orange,
              label: 'Logout',
              onTap: () => _showLogoutDialog(context),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            _MenuRow(
              icon: Icons.delete_forever_outlined,
              iconColor: Colors.red,
              label: 'Hapus Akun',
              labelColor: Colors.red,
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ]),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ubah Password',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(errorMsg!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              _PasswordField(controller: oldCtrl, hint: 'Password lama'),
              const SizedBox(height: 10),
              _PasswordField(controller: newCtrl, hint: 'Password baru'),
              const SizedBox(height: 10),
              _PasswordField(
                  controller: confirmCtrl, hint: 'Konfirmasi password baru'),
            ],
          ),
          actions: [
            TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() {
                        isLoading = true;
                        errorMsg = null;
                      });

                      final result = await ProfileService.changePassword(
                        currentPassword: oldCtrl.text,
                        newPassword: newCtrl.text,
                        confirmPassword: confirmCtrl.text,
                      );

                      if (!dialogContext.mounted) return;

                      if (result.success) {
                        Navigator.pop(dialogContext);
                        await StorageService.clear();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMsg = result.message;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService.clear();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Akun',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan. Seluruh data Anda akan dihapus secara permanen.\n\nApakah Anda yakin?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.8),
        ),
      );
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: children),
      );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF1565C0),
            ),
          ],
        ),
      );
}

class _DropdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 18, color: Colors.grey),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: labelColor ?? Colors.black87)),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

class _ReadOnlyField extends StatelessWidget {
  final String value;
  const _ReadOnlyField({required this.value});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(value,
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
      );
}

class _EditableField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  const _EditableField(
      {required this.controller,
      required this.hint,
      required this.keyboardType,
      this.inputFormatters,
      this.validator});
  
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1565C0))),
        ),
      );
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const _PasswordField({required this.controller, required this.hint});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: _obscure,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1565C0))),
          suffixIcon: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: Colors.grey),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}
