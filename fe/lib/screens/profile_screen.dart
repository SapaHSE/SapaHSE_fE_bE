import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _topTabController;
  File? _avatarFile;

  UserModel? _user;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _topTabController = TabController(length: 3, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _topTabController.dispose();
    super.dispose();
  }

  // ── Load user: try local cache first, then API ────────────────────────────
  Future<void> _loadUser() async {
    // Show cached data instantly
    final cached = await StorageService.getUser();
    if (cached != null && mounted) {
      setState(() {
        _user = UserModel.fromJson(cached);
        _loadingUser = false;
      });
    }

    // Then refresh from API in background
    final result = await ProfileService.getProfile();
    if (result.success && mounted) {
      setState(() {
        _user = result.user;
        _loadingUser = false;
      });
    } else if (!mounted) {
      return;
    } else if (_user == null) {
      // No cache and API failed
      setState(() => _loadingUser = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {},
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _topTabController,
          labelColor: const Color(0xFF1565C0),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF1565C0),
          indicatorWeight: 2.5,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'App'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: _loadingUser && _user == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _topTabController,
              children: [
                _ProfileTab(
                  user: _user,
                  avatarFile: _avatarFile,
                  onPickImage: _pickImage,
                  onUserUpdated: (u) => setState(() => _user = u),
                ),
                const _AppTab(),
                _SettingsTab(onLogout: _logout),
              ],
            ),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatefulWidget {
  final UserModel? user;
  final File? avatarFile;
  final VoidCallback onPickImage;
  final ValueChanged<UserModel> onUserUpdated;

  const _ProfileTab({
    required this.user,
    required this.avatarFile,
    required this.onPickImage,
    required this.onUserUpdated,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  int _selectedSubTab = 0;

  final List<Map<String, dynamic>> _subTabs = [
    {'label': 'Biodata', 'icon': Icons.person},
    {'label': 'License', 'icon': Icons.credit_card},
    {'label': 'Certification', 'icon': Icons.workspace_premium},
    {'label': 'Medical', 'icon': Icons.medical_services},
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Avatar + name ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: const Color(0xFFF0F0F0),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: widget.onPickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: const Color(0xFFD0D0D0),
                        backgroundImage: widget.avatarFile != null
                            ? FileImage(widget.avatarFile!)
                            : (user?.profilePhoto != null
                                ? NetworkImage(user!.profilePhoto!)
                                    as ImageProvider
                                : null),
                        child: widget.avatarFile == null &&
                                (user?.profilePhoto == null)
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
                  user?.fullName ?? '-',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  [user?.position, user?.department]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(', '),
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                const Text(
                  'PT Bukit Baiduri Energi',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                // Role badge
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.isAdmin
                          ? const Color(0xFFFFEBEE)
                          : user.isSupervisor
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: user.isAdmin
                            ? Colors.red
                            : user.isSupervisor
                                ? Colors.orange
                                : const Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Sub-tab icon buttons ───────────────────────────────────────
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
                          Icon(_subTabs[i]['icon'] as IconData,
                              color: Colors.white, size: 24),
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

          // ── Sub-tab content ────────────────────────────────────────────
          _buildSubTabContent(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return _BiodataContent(
          user: widget.user,
          onUserUpdated: widget.onUserUpdated,
        );
      case 1:
        return const _LicenseContent();
      case 2:
        return const _CertificationContent();
      case 3:
        return const _MedicalContent();
      default:
        return const SizedBox();
    }
  }
}

// ── BIODATA ───────────────────────────────────────────────────────────────────
class _BiodataContent extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel> onUserUpdated;

  const _BiodataContent({required this.user, required this.onUserUpdated});

  @override
  State<_BiodataContent> createState() => _BiodataContentState();
}

class _BiodataContentState extends State<_BiodataContent> {
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _positionCtrl;
  late TextEditingController _departmentCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.user?.phoneNumber ?? '');
    _positionCtrl = TextEditingController(text: widget.user?.position ?? '');
    _departmentCtrl =
        TextEditingController(text: widget.user?.department ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _positionCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final result = await ProfileService.updateProfile(
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      position: _positionCtrl.text.trim(),
      department: _departmentCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      widget.onUserUpdated(result.user!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil disimpan'),
          backgroundColor: Color(0xFF1565C0),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Gagal menyimpan profil'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormField(
            label: 'NIK',
            child: _ReadOnlyField(value: widget.user?.nik ?? '-'),
          ),
          const SizedBox(height: 14),
          _FormField(
            label: 'Employee ID',
            child: _ReadOnlyField(value: widget.user?.employeeId ?? '-'),
          ),
          const SizedBox(height: 14),
          _FormField(
            label: 'Email Address',
            child: _EditableField(
                controller: _emailCtrl,
                hint: 'Masukkan email',
                keyboardType: TextInputType.emailAddress),
          ),
          const SizedBox(height: 14),
          _FormField(
            label: 'Telephone Number',
            child: _EditableField(
                controller: _phoneCtrl,
                hint: 'Masukkan nomor telepon',
                keyboardType: TextInputType.phone),
          ),
          const SizedBox(height: 14),
          _FormField(
            label: 'Posisi / Jabatan',
            child: _EditableField(
                controller: _positionCtrl,
                hint: 'Masukkan posisi',
                keyboardType: TextInputType.text),
          ),
          const SizedBox(height: 14),
          _FormField(
            label: 'Departemen',
            child: _EditableField(
                controller: _departmentCtrl,
                hint: 'Masukkan departemen',
                keyboardType: TextInputType.text),
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
    );
  }
}

// ── LICENSE ───────────────────────────────────────────────────────────────────
class _LicenseContent extends StatelessWidget {
  const _LicenseContent();

  @override
  Widget build(BuildContext context) {
    final licenses = [
      {
        'name': 'SIM A',
        'no': 'SIM-2024-001234',
        'exp': '15 Maret 2027',
        'status': 'Aktif'
      },
      {
        'name': 'SIO Operator Alat Berat',
        'no': 'SIO-2023-005678',
        'exp': '20 Juni 2026',
        'status': 'Aktif'
      },
      {
        'name': 'SIMPER',
        'no': 'SP-2022-009012',
        'exp': '10 Januari 2025',
        'status': 'Kadaluarsa'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: licenses.map((l) {
          final isActive = l['status'] == 'Aktif';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                      Text(l['name']!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('No: ${l['no']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text('Exp: ${l['exp']}',
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
                  child: Text(l['status']!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── CERTIFICATION ─────────────────────────────────────────────────────────────
class _CertificationContent extends StatelessWidget {
  const _CertificationContent();

  @override
  Widget build(BuildContext context) {
    final certs = [
      {
        'name': 'K3 Umum',
        'issuer': 'Kemnaker RI',
        'year': '2023',
        'status': 'Aktif'
      },
      {
        'name': 'Basic First Aid',
        'issuer': 'PMI Indonesia',
        'year': '2022',
        'status': 'Aktif'
      },
      {
        'name': 'ISO 45001 Internal Auditor',
        'issuer': 'BSN',
        'year': '2021',
        'status': 'Aktif'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: certs.map((c) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.workspace_premium,
                      color: Color(0xFF6A1B9A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name']!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Penerbit: ${c['issuer']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text('Tahun: ${c['year']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(c['status']!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── MEDICAL ───────────────────────────────────────────────────────────────────
class _MedicalContent extends StatelessWidget {
  const _MedicalContent();

  @override
  Widget build(BuildContext context) {
    final records = [
      {'label': 'Golongan Darah', 'value': 'O+'},
      {'label': 'Tinggi Badan', 'value': '168 cm'},
      {'label': 'Berat Badan', 'value': '65 kg'},
      {'label': 'Tekanan Darah', 'value': '120/80 mmHg'},
      {'label': 'Alergi', 'value': 'Tidak Ada'},
      {'label': 'MCU Terakhir', 'value': '10 Januari 2026'},
      {'label': 'Hasil MCU', 'value': 'Fit to Work'},
      {'label': 'MCU Berikutnya', 'value': '10 Januari 2027'},
    ];

    final history = [
      _MedicalHistory(
        id: 'mh1',
        title: 'Medical Check-Up Tahunan 2026',
        date: '10 Januari 2026',
        doctor: 'dr. Andi Wijaya, Sp.OK',
        facility: 'Klinik Pratama BBE',
        result: 'Fit to Work',
        resultColor: const Color(0xFF4CAF50),
        notes: 'Semua parameter dalam batas normal.',
        items: [
          _CheckItem('Pemeriksaan Fisik Umum', true),
          _CheckItem('Tes Darah Lengkap', true),
          _CheckItem('Tes Urine', true),
          _CheckItem('Rekam Jantung (EKG)', true),
          _CheckItem('Rontgen Dada', true),
          _CheckItem('Tes Fungsi Paru (Spirometri)', true),
          _CheckItem('Pemeriksaan Mata', true),
          _CheckItem('Tes Audiometri', true),
        ],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
          Row(children: [
            const Text('Riwayat Pemeriksaan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A56C4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${history.length} riwayat',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1A56C4),
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 10),
          ...history.map((h) => _MedicalHistoryCard(history: h)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CheckItem {
  final String label;
  final bool done;
  const _CheckItem(this.label, this.done);
}

class _MedicalHistory {
  final String id, title, date, doctor, facility, result, notes;
  final Color resultColor;
  final List<_CheckItem> items;
  const _MedicalHistory({
    required this.id,
    required this.title,
    required this.date,
    required this.doctor,
    required this.facility,
    required this.result,
    required this.resultColor,
    required this.notes,
    required this.items,
  });
}

class _MedicalHistoryCard extends StatelessWidget {
  final _MedicalHistory history;
  const _MedicalHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _MedicalDetailScreen(history: history))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: history.resultColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.medical_services_outlined,
                color: history.resultColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 10),
                const Icon(Icons.local_hospital_outlined,
                    size: 11, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(history.facility,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: history.resultColor,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(history.result,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
          ]),
        ]),
      ),
    );
  }
}

class _MedicalDetailScreen extends StatelessWidget {
  final _MedicalHistory history;
  const _MedicalDetailScreen({super.key, required this.history});

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
            onPressed: () => Navigator.pop(context)),
        title: const Text('Detail Pemeriksaan',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: const Color(0xFF1A56C4),
                borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
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
                            fontSize: 15))),
              ]),
              const SizedBox(height: 14),
              _HeaderRow(
                  Icons.calendar_today_outlined, 'Tanggal', history.date),
              const SizedBox(height: 6),
              _HeaderRow(Icons.person_outline, 'Dokter', history.doctor),
              const SizedBox(height: 6),
              _HeaderRow(
                  Icons.local_hospital_outlined, 'Fasilitas', history.facility),
              const SizedBox(height: 14),
              Row(children: [
                const Text('Hasil:',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                      color: history.resultColor,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(history.result,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Checklist Pemeriksaan',
            trailing: Text('$done/$total selesai',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A56C4),
                    fontWeight: FontWeight.w600)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                  color:
                                      item.done ? Colors.black87 : Colors.grey,
                                  decoration: item.done
                                      ? null
                                      : TextDecoration.lineThrough))),
                      Text(item.done ? 'Selesai' : 'Tidak',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.done
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey)),
                    ]),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Catatan Dokter',
            child: Text(history.notes,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.6)),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
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
                color: Colors.black.withOpacity(0.05),
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

// ══════════════════════════════════════════════════════════════════════════════
// APP TAB
// ══════════════════════════════════════════════════════════════════════════════
class _AppTab extends StatefulWidget {
  const _AppTab();

  @override
  State<_AppTab> createState() => _AppTabState();
}

class _AppTabState extends State<_AppTab> {
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
          _SectionHeader(title: 'Notifikasi'),
          _SettingCard(children: [
            _SwitchRow(
              icon: Icons.notifications_outlined,
              iconColor: const Color(0xFF1565C0),
              label: 'Notifikasi Push',
              subtitle: 'Terima notifikasi laporan & pengumuman',
              value: _notifPush,
              onChanged: (v) => setState(() => _notifPush = v),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Tampilan'),
          _SettingCard(children: [
            _SwitchRow(
              icon: Icons.dark_mode_outlined,
              iconColor: const Color(0xFF37474F),
              label: 'Tema Gelap',
              subtitle: 'Aktifkan mode dark theme',
              value: _darkTheme,
              onChanged: (v) => setState(() => _darkTheme = v),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            _MenuRow(
              icon: Icons.dashboard_outlined,
              iconColor: const Color(0xFF1A56C4),
              label: 'Dashboard Laporan',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen())),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Bahasa'),
          _SettingCard(children: [
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
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SETTINGS TAB
// ══════════════════════════════════════════════════════════════════════════════
class _SettingsTab extends StatelessWidget {
  final Future<void> Function() onLogout;
  const _SettingsTab({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Akun'),
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
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Sesi'),
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ubah Password',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);

                      final result = await ProfileService.changePassword(
                        currentPassword: oldCtrl.text,
                        newPassword: newCtrl.text,
                        confirmPassword: confirmCtrl.text,
                      );

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx); // close dialog first

                      if (result.success) {
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor: const Color(0xFF1565C0),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        // Wait for snackbar, then logout since Laravel revoked the token
                        await Future.delayed(const Duration(seconds: 2));
                        await AuthService.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      } else {
                        // Show error, stay on screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                        // Re-enable button if still in dialog (dialog is closed, so this is just safety)
                        setModalState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
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
              await onLogout();
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
            'Tindakan ini tidak dapat dibatalkan. Seluruh data Anda akan dihapus secara permanen.\n\nApakah Anda yakin?'),
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
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.8)),
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
                color: Colors.black.withOpacity(0.05),
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
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20)),
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
              ])),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF1565C0)),
        ]),
      );
}

class _DropdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, subtitle, value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.subtitle,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20)),
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
              ])),
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
        ]),
      );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  const _MenuRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      this.labelColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: labelColor ?? Colors.black87))),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ]),
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
  const _EditableField(
      {required this.controller,
      required this.hint,
      required this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
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
