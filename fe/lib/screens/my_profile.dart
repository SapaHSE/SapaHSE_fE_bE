import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:sapahse/models/profile_model.dart';
import 'package:sapahse/services/profile_service.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  XFile? _avatarFile;
  int _selectedSubTab = 0;
  bool _isLoading = true;
  ProfileData? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await ProfileService.getProfile();
    if (mounted && result.success) {
      setState(() {
        _profileData = result.data;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _avatarFile = picked);
  }

  final List<Map<String, dynamic>> _subTabs = [
    {'label': 'Biodata', 'icon': Icons.person, 'color': const Color(0xFF5C38FF)},
    {'label': 'Lisensi', 'icon': Icons.badge, 'color': const Color(0xFF1E88E5)},
    {'label': 'Pelanggaran', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFFBC02D)},
    {'label': 'Sertifikat', 'icon': Icons.workspace_premium, 'color': const Color(0xFFF57C00)},
    {'label': 'Medis', 'icon': Icons.medical_services, 'color': const Color(0xFFE91E63)},
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildSubTabBar(),
            const SizedBox(height: 20),
            _buildSubTabContent(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _profileData?.fullName ?? '-';
    final initials = name.split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF5C38FF),
                backgroundImage: _getAvatarImage(),
                child: _avatarFile == null && (_profileData?.profilePhoto == null || _profileData!.profilePhoto!.isEmpty)
                    ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF5C38FF), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_profileData?.position ?? "-"} — Dept. ${_profileData?.department ?? "-"}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(_profileData?.company ?? '-', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarImage() {
    if (_avatarFile != null) {
      return FileImage(File(_avatarFile!.path));
    }
    if (_profileData?.profilePhoto != null && _profileData!.profilePhoto!.isNotEmpty) {
      return NetworkImage(_profileData!.profilePhoto!);
    }
    return null;
  }

  Widget _buildSubTabBar() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _subTabs.length,
        itemBuilder: (context, index) {
          final tab = _subTabs[index];
          final isSelected = _selectedSubTab == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedSubTab = index),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? tab['color'].withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? tab['color'] : Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab['icon'], color: isSelected ? tab['color'] : Colors.grey.shade400, size: 24),
                  const SizedBox(height: 8),
                  Text(tab['label'],
                      style: TextStyle(
                          color: isSelected ? tab['color'] : Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTabContent() {
    switch (_selectedSubTab) {
      case 0: return _BiodataContent(data: _profileData);
      case 1: return _LicenseContent(licenses: _profileData?.licenses ?? []);
      case 2: return const Center(child: Text('Pelanggaran (Coming Soon)'));
      case 3: return _CertificationContent(certifications: _profileData?.certifications ?? []);
      case 4: return _MedicalContent(medicals: _profileData?.medicals ?? []);
      default: return const SizedBox();
    }
  }
}

// ── SUB-TAB WIDGETS (INTERNAL) ──────────────────────────────────────────────

class _BiodataContent extends StatelessWidget {
  final ProfileData? data;
  const _BiodataContent({this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle('CORE DATA'),
          _buildCard([
            _buildRow('NIK', data?.employeeId ?? '-', locked: true),
            _buildRow('Nama Lengkap', data?.fullName ?? '-', locked: true),
            _buildRow('Email', data?.personalEmail ?? '-'),
            _buildRow('Phone', data?.phoneNumber ?? '-'),
            _buildRow('Alamat', 'Jl. Kelapa No. 12, BPN'),
          ]),
          const SizedBox(height: 24),
          _buildTitle('EMPLOYEE DATA'),
          _buildCard([
            _buildRow('Departemen', data?.department ?? '-', locked: true),
            _buildRow('Position', data?.position ?? '-', locked: true),
            _buildRow('Perusahaan', data?.company ?? '-', locked: true),
          ]),
        ],
      ),
    );
  }

  Widget _buildTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _buildCard(List<Widget> children) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
    child: Column(children: children.asMap().entries.map((e) => Column(children: [
      e.value, if (e.key < children.length - 1) Divider(height: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16)
    ])).toList()),
  );

  Widget _buildRow(String label, String value, {bool locked = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const Spacer(),
      Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      if (locked) ...[const SizedBox(width: 6), const Icon(Icons.lock, color: Colors.orange, size: 14)],
    ]),
  );
}

class _LicenseContent extends StatelessWidget {
  final List<UserLicense> licenses;
  const _LicenseContent({required this.licenses});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: licenses.map((l) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            const Icon(Icons.credit_card, color: Color(0xFF1E88E5)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('No: ${l.licenseNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            Text(l.isActive ? 'Aktif' : 'Expired', style: TextStyle(color: l.isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
        )).toList(),
      ),
    );
  }
}

class _CertificationContent extends StatelessWidget {
  final List<UserCertification> certifications;
  const _CertificationContent({required this.certifications});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: certifications.map((c) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            const Icon(Icons.workspace_premium, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Issuer: ${c.issuer}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
          ]),
        )).toList(),
      ),
    );
  }
}

class _MedicalContent extends StatelessWidget {
  final List<UserMedical> medicals;
  const _MedicalContent({required this.medicals});

  @override
  Widget build(BuildContext context) {
    if (medicals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.medical_information_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Data Medis tidak tersedia', style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: medicals.map((m) => _buildMedicalCard(context, m)).toList(),
      ),
    );
  }

  Widget _buildMedicalCard(BuildContext context, UserMedical medical) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services, color: Color(0xFFE91E63), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medical.title ?? 'Medical Checkup', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(medical.facilityName ?? '-', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                if (medical.result != null && medical.result!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getResultColor(medical.result).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      medical.result!,
                      style: TextStyle(color: _getResultColor(medical.result), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 8),
          _buildInfoRow('Nama Pasien', medical.patientName ?? '-'),
          _buildInfoRow('Golongan Darah', medical.bloodType ?? '-'),
          _buildInfoRow('Tinggi / Berat', '${medical.height ?? '-'} cm / ${medical.weight ?? '-'} kg'),
          _buildInfoRow('Tekanan Darah', medical.bloodPressure ?? '-'),
          _buildInfoRow('Alergi', medical.allergies ?? '-'),
          _buildInfoRow('Tanggal MCU', medical.checkupDate ?? '-'),
          _buildInfoRow('Masa Berlaku', medical.nextCheckupDate ?? '-'),
          _buildInfoRow('Dokter', medical.doctorName ?? '-'),
          if (medical.doctorNotes != null && medical.doctorNotes!.isNotEmpty)
            _buildInfoRow('Catatan', medical.doctorNotes!),
            
          if (medical.checklistItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade100),
            InkWell(
              onTap: () => _showChecklistBottomSheet(context, medical.checklistItems),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checklist, size: 18, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Lihat ${medical.checklistItems.length} Checklist Pemeriksaan',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
          ]
        ],
      ),
    );
  }

  void _showChecklistBottomSheet(BuildContext context, List<MedicalChecklistItem> checklist) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.checklist, color: Color(0xFFE91E63)),
                          SizedBox(width: 12),
                          Text('Checklist Pemeriksaan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: checklist.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (context, index) {
                          final item = checklist[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  item.done ? Icons.check_circle : Icons.cancel,
                                  color: item.done ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: item.done ? Colors.black87 : Colors.grey.shade600,
                                      decoration: item.done ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getResultColor(String? result) {
    final res = (result ?? '').toLowerCase();
    if (res.contains('fit') || res.contains('sehat') || res.contains('baik') || res.contains('pass')) return Colors.green;
    if (res.contains('unfit') || res.contains('tidak sehat') || res.contains('fail')) return Colors.red;
    return Colors.orange;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
