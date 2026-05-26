import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';
import '../utils/approval_status_ui.dart';
import '../widgets/fab_notched_bottom_bar.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/violation_form_sheet.dart';
import '../widgets/violation_type_picker.dart';
import 'license_detail_screen.dart';
import 'certification_detail_screen.dart';
import 'violation_detail_screen.dart';
import '../services/company_service.dart';
import 'my_profile.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String? displayName;

  const UserProfileViewScreen({
    super.key,
    required this.userId,
    this.displayName,
  });

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  bool _isLoading = true;
  String? _error;
  ProfileData? _profile;
  int _selectedSubTab = 0;
  bool _isFetchingCompanies = false;
  Map<String, String> _ownerCodeByName = {};
  Map<String, String> _companyCodeLookup = {};

  final List<Map<String, dynamic>> _subTabs = [
    {
      'label': 'Biodata',
      'icon': Icons.person,
      'color': const Color(0xFF1A56C4)
    },
    {
      'label': 'Medis',
      'icon': Icons.medical_services,
      'color': const Color(0xFF1A56C4)
    },
    {'label': 'Lisensi', 'icon': Icons.badge, 'color': const Color(0xFF1A56C4)},
    {
      'label': 'Pelanggaran',
      'icon': Icons.warning_amber_rounded,
      'color': const Color(0xFF1A56C4)
    },
    {
      'label': 'Sertifikat',
      'icon': Icons.workspace_premium,
      'color': const Color(0xFF1A56C4)
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _fetchCompanyData();

    final result = await ProfileService.getUserProfileById(widget.userId);
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() {
        _profile = result.data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.errorMessage ?? 'Gagal memuat profil.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCompanyData() async {
    if (_isFetchingCompanies) return;
    _isFetchingCompanies = true;

    try {
      final results = await Future.wait([
        CompanyService.getCompanies(category: 'owner', active: true),
        CompanyService.getCompanies(category: 'kontraktor', active: true),
        CompanyService.getCompanies(category: 'subkontraktor', active: true),
      ]);

      if (!mounted) return;
      setState(() {
        _ownerCodeByName = {
          for (final company in results[0])
            if ((company.code ?? '').trim().isNotEmpty)
              companyLookupKey(company.name): company.code!.trim(),
          for (final company in results[0])
            if ((company.code ?? '').trim().isNotEmpty)
              companyLookupKey(company.code!): company.code!.trim(),
        };

        final allComps = [...results[0], ...results[1], ...results[2]];
        _companyCodeLookup = {
          for (final company in allComps)
            if ((company.code ?? '').trim().isNotEmpty)
              companyLookupKey(company.name): company.code!.trim(),
        };
      });
    } catch (e) {
      debugPrint('Error fetching companies in user profile: $e');
    } finally {
      _isFetchingCompanies = false;
    }
  }

  String _displayValue(String? value) => value?.trim() ?? '';

  void _onTabTapped(int index) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MainScreen(initialIndex: index),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  void _openViolationForm(String type) {
    final profile = _profile;
    if (profile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ViolationFormSheet(
        initialType: type,
        preSelectedUser: {
          'id': profile.id,
          'full_name': profile.fullName,
          'employee_id': profile.employeeId,
        },
        onSuccess: _load,
      ),
    );
  }

  void _openViolationTypePicker() {
    showViolationTypePicker(
      context: context,
      onSelected: _openViolationForm,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: const Text('Detail Profil',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedSubTab == 3 ? _openViolationTypePicker : () => Navigator.pop(context),
        backgroundColor: const Color(0xFF1A56C4),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(_selectedSubTab == 3 ? Icons.add : Icons.arrow_back, size: 28),
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: FabNotchedBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ProfileNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                currentIndex: 0,
                onTap: _onTabTapped),
            _ProfileNavItem(
                icon: Icons.article_outlined,
                label: 'News',
                index: 1,
                currentIndex: 0,
                onTap: _onTabTapped),
            const SizedBox(width: 56),
            _ProfileNavItem(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                index: 3,
                currentIndex: 0,
                onTap: _onTabTapped),
            _ProfileNavItem(
                icon: Icons.menu,
                label: 'Menu',
                index: 4,
                currentIndex: 0,
                onTap: _onTabTapped),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
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
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1A56C4)),
                    SizedBox(height: 24),
                    Text(
                      'Memuat Profil...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      _buildSubTabBar(),
                      const SizedBox(height: 20),
                      _buildSubTabContent(),
                      SizedBox(
                        height: AppSafeInsets.bottomNavScrollPadding(context),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _displayValue(_profile?.fullName).isNotEmpty
        ? _displayValue(_profile?.fullName)
        : (widget.displayName ?? '-');
    final positionVal = _displayValue(_profile?.position);
    final jabatanVal = _displayValue(_profile?.jabatan);
    final position = (jabatanVal.isNotEmpty &&
            positionVal.isNotEmpty &&
            jabatanVal != positionVal)
        ? '$jabatanVal • $positionVal'
        : (jabatanVal.isNotEmpty
            ? jabatanVal
            : (positionVal.isNotEmpty ? positionVal : '-'));
    final department = _displayValue(_profile?.department).isNotEmpty
        ? _displayValue(_profile?.department)
        : '-';
    final employeeId = _displayValue(_profile?.employeeId).isNotEmpty
        ? _displayValue(_profile?.employeeId)
        : '-';
    final company = formatCompanyAffiliation(
      tipeAfiliasi: _profile?.tipeAfiliasi,
      ownerCompany: _profile?.company,
      contractorCompany: _profile?.perusahaanKontraktor,
      subContractorCompany: _profile?.subKontraktor,
      ownerCompanyCodeLookup: _ownerCodeByName,
      companyCodeLookup: _companyCodeLookup,
    );

    final nameParts = name.split(RegExp(r'\s+'));
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : nameParts.isNotEmpty && nameParts[0].isNotEmpty
            ? nameParts[0][0].toUpperCase()
            : '?';

    final photoUrl = _profile?.profilePhoto?.toString();
    final hasAvatar = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF1A56C4),
            backgroundImage:
                hasAvatar ? CachedNetworkImageProvider(photoUrl) : null,
            child: !hasAvatar
                ? Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(height: 16),
          Text(name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(employeeId,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$position • $department',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13, height: 1.3)),
          ),
          const SizedBox(height: 4),
          Text(company,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSubTabBar() {
    return SizedBox(
      height: 90,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_subTabs.length, (index) {
              final tab = _subTabs[index];
              final isSelected = _selectedSubTab == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedSubTab = index),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? tab['color'] : Colors.grey.shade200,
                      width: isSelected ? 1.4 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tab['icon'],
                          color:
                              isSelected ? tab['color'] : Colors.grey.shade400,
                          size: 24),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(tab['label'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isSelected
                                    ? tab['color']
                                    : Colors.grey.shade600,
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return _BiodataContent(data: _profile);
      case 1:
        return _MedicalContent(medicals: _profile?.medicals ?? []);
      case 2:
        return _LicenseContent(licenses: _profile?.licenses ?? []);
      case 3:
        return _ViolationContent(violations: _profile?.violations ?? []);
      case 4:
        return _CertificationContent(
            certifications: _profile?.certifications ?? []);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────
// REUSABLE LAYOUT WIDGETS
// ──────────────────────────────────────────────────────────────────────────

Widget _buildTitle(String title) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0).copyWith(bottom: 8),
      child: Text(title,
          style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );

Widget _buildCard(List<Widget> children) => Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(
              children: children
                  .asMap()
                  .entries
                  .map((e) => Column(children: [
                        e.value,
                        if (e.key < children.length - 1)
                          Divider(
                              height: 1,
                              color: Colors.grey.shade100,
                              indent: 16,
                              endIndent: 16)
                      ]))
                  .toList()),
        ),
      ),
    );

Widget _buildRow(BuildContext context, String label, String value,
    {VoidCallback? onTap, Color? valueColor}) {
  Widget content = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: valueColor ?? Colors.black87,
                        height: 1.3))),
          ],
        )),
      ],
    ),
  );
  if (onTap != null) {
    return GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onTap, child: content);
  }
  return content;
}

void _copyToClipboard(BuildContext context, String label, String? value) {
  if (value != null && value != '-' && value.isNotEmpty) {
    Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label berhasil disalin'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

Future<void> _launchUrl(String urlString) async {
  final url = Uri.parse(urlString);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

// ──────────────────────────────────────────────────────────────────────────
// TAB CONTENTS (READ ONLY)
// ──────────────────────────────────────────────────────────────────────────

class _BiodataContent extends StatelessWidget {
  final ProfileData? data;
  const _BiodataContent({this.data});

  String _display(String? val) =>
      (val == null || val.trim().isEmpty) ? '-' : val.trim();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle('PERSONAL INFORMATION '),
        _buildCard([
          _buildRow(context, 'NIP', _display(data?.employeeId),
              onTap: () =>
                  _copyToClipboard(context, 'NIP', data?.employeeId)),
          _buildRow(context, 'Nama Lengkap', _display(data?.fullName),
              onTap: () =>
                  _copyToClipboard(context, 'Nama Lengkap', data?.fullName)),
          _buildRow(context, 'Email', _display(data?.personalEmail),
              onTap: () {
            final e = _display(data?.personalEmail);
            if (e != '-') _showEmailOptions(context, e);
          }),
          _buildRow(context, 'Phone', _display(data?.phoneNumber), onTap: () {
            final phone = _display(data?.phoneNumber);
            if (phone != '-') {
              _showPhoneOptions(context, phone);
            }
          }),
          _buildRow(context, 'Alamat', _display(data?.address),
              onTap: () =>
                  _copyToClipboard(context, 'Alamat', data?.address)),
        ]),
        const SizedBox(height: 24),
        _buildTitle('EMPLOYEE INFORMATION'),
        _buildCard([
          _buildRow(context, 'Tipe Afiliasi', _display(data?.tipeAfiliasi)),
          _buildRow(context, 'Perusahaan Owner', _display(data?.company)),
          if (_display(data?.tipeAfiliasi)
              .toLowerCase()
              .contains('kontraktor'))
            _buildRow(context, 'Perusahaan Kontraktor',
                _display(data?.perusahaanKontraktor)),
          if (_display(data?.tipeAfiliasi).toLowerCase().contains('sub-kont'))
            _buildRow(
                context, 'Sub-Kontraktor', _display(data?.subKontraktor)),
          _buildRow(context, 'Departemen', _display(data?.department)),
          _buildRow(context, 'Jabatan', _display(data?.jabatan)),
          _buildRow(context, 'Posisi', _display(data?.position)),
        ]),
      ],
    );
  }

  void _showEmailOptions(BuildContext context, String email) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Hubungi via Email',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.email, color: Color(0xFFD32F2F)),
              ),
              title: const Text('Kirim Email'),
              subtitle: Text(email),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('mailto:$email');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.copy, color: Color(0xFFFB8C00)),
              ),
              title: const Text('Salin Email'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(context, 'Email', email);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPhoneOptions(BuildContext context, String phone) {
    String cleanNumber = phone.replaceAll(RegExp(r'[^\d+]'), '');
    String waNumber = cleanNumber;
    if (waNumber.startsWith('0')) {
      waNumber = '62${waNumber.substring(1)}';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Hubungi Karyawan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.phone, color: Color(0xFF1E88E5)),
              ),
              title: const Text('Panggilan Telepon'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('tel:$cleanNumber');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.message, color: Color(0xFF43A047)),
              ),
              title: const Text('WhatsApp'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('https://wa.me/$waNumber');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.copy, color: Color(0xFFFB8C00)),
              ),
              title: const Text('Salin Nomor'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(context, 'Nomor Telepon', phone);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MedicalContent extends StatelessWidget {
  final List<UserMedical> medicals;
  const _MedicalContent({required this.medicals});

  Widget _buildMedicalRow(String label, String value,
          {bool isBoldValue = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                  fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  color: isBoldValue ? Colors.black : Colors.grey.shade700,
                )),
          ],
        ),
      );

  Widget _buildDivider() => Divider(
      height: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16);

  @override
  Widget build(BuildContext context) {
    if (medicals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('Tidak ada riwayat medis')),
      );
    }
    final latest = medicals.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle('INFORMATION MEDIS'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildMedicalRow('Golongan Darah', latest.bloodType ?? '-'),
              _buildDivider(),
              _buildMedicalRow('Tinggi Badan',
                  latest.height != null ? '${latest.height} cm' : '-'),
              _buildDivider(),
              _buildMedicalRow('Berat Badan',
                  latest.weight != null ? '${latest.weight} kg' : '-'),
              _buildDivider(),
              _buildMedicalRow('Tekanan Darah', latest.bloodPressure ?? '-'),
              _buildDivider(),
              _buildMedicalRow('Alergi', latest.allergies ?? 'Tidak Ada',
                  isBoldValue: true),
              _buildDivider(),
              _buildMedicalRow('MCU Terakhir', latest.checkupDate ?? '-'),
              _buildDivider(),
              _buildMedicalRow('Hasil MCU', latest.result ?? '-'),
              _buildDivider(),
              _buildMedicalRow(
                  'MCU Berikutnya', latest.nextCheckupDate ?? '-'),
              _buildDivider(),
              _buildMedicalRow(
                  'Konsumsi Obat Terakhir', latest.lastMedication ?? '-'),
              _buildDivider(),
              _buildMedicalRow(
                  'Obat Berjalan', latest.currentMedication ?? '-'),
              _buildDivider(),
              _buildMedicalRow(
                  'Penyakit Diderita', latest.currentIllness ?? '-',
                  isBoldValue: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Information medis dikelola oleh Klinik & Dokter Perusahaan',
                    style: TextStyle(
                        color: Colors.indigo.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LicenseContent extends StatelessWidget {
  final List<UserLicense> licenses;
  const _LicenseContent({required this.licenses});

  @override
  Widget build(BuildContext context) {
    if (licenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.badge_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Tidak ada lisensi',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
          ...licenses.map((l) {
            final isAktif = l.isActive;
            final approvalStatus = l.approvalStatus.toLowerCase();
            final approvalStyle = approvalStatusStyle(approvalStatus);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            LicenseDetailScreen(license: l, isReadOnly: true)));
              },
              child: Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isAktif
                            ? Colors.grey.shade200
                            : Colors.red.shade100),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (l.fileUrl != null && l.fileUrl!.isNotEmpty)
                          ? Image.network(
                              l.fileUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.badge_outlined,
                                      color: Color(0xFF1E88E5), size: 24),
                            )
                          : const Icon(Icons.badge_outlined,
                              color: Color(0xFF1E88E5), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name.isNotEmpty ? l.name : '-',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('No. ${l.licenseNumber}',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13)),
                          if (l.issuer != null && l.issuer!.isNotEmpty)
                            Text('Penerbit: ${l.issuer}',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
                          if (l.obtainedAt != null)
                            Text('Diperoleh: ${l.obtainedAt}',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12)),
                          if (l.expiredAt != null)
                            Text('Berlaku s/d: ${l.expiredAt}',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: approvalStyle.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: approvalStyle.fg.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            approvalStyle.label,
                            style: TextStyle(
                                color: approvalStyle.fg,
                                fontWeight: FontWeight.bold,
                                fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
  }
}

class _ViolationContent extends StatelessWidget {
  final List<UserViolation> violations;
  const _ViolationContent({required this.violations});

  @override
  Widget build(BuildContext context) {
    if (violations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Tidak ada riwayat pelanggaran',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle('RIWAYAT PELANGGARAN'),
        ...violations.map((v) {
          final isAktif = v.status.toLowerCase() == 'aktif';
          final color = isAktif ? Colors.red.shade700 : Colors.grey.shade700;
          final bgColor = isAktif ? Colors.red.shade50 : Colors.grey.shade100;
          final typeColor = v.type == 'Incident' ? Colors.orange.shade700 : Colors.red.shade700;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ViolationDetailScreen(violation: v)));
            },
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isAktif
                          ? Colors.red.shade100
                          : Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isAktif
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (v.fileUrl != null && v.fileUrl!.isNotEmpty)
                        ? Image.network(
                            v.fileUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(
                              Icons.warning_amber_rounded,
                              color: isAktif
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF757575),
                              size: 24,
                            ),
                          )
                        : Icon(
                            Icons.warning_amber_rounded,
                            color: isAktif
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF757575),
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _MiniBadge(
                              label: v.type,
                              fg: typeColor,
                              bg: typeColor.withValues(alpha: 0.08),
                            ),
                            _MiniBadge(
                              label: 'L${v.level}',
                              fg: color,
                              bg: bgColor,
                            ),
                            if ((v.violationCategory ?? '').isNotEmpty)
                              _MiniBadge(
                                label: v.violationCategory!,
                                fg: Colors.blueGrey.shade700,
                                bg: Colors.blueGrey.shade50,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.location ?? '-',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tanggal: ${v.dateOfViolation ?? "-"}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Berlaku s/d: ${((v.expiredAt ?? '').isEmpty) ? 'Permanen' : v.expiredAt}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        if (v.sanction != null && v.sanction!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Sanksi: ${v.sanction}',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          v.status,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;

  const _MiniBadge({
    required this.label,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _CertificationContent extends StatelessWidget {
  final List<UserCertification> certifications;
  const _CertificationContent({required this.certifications});

  @override
  Widget build(BuildContext context) {
    if (certifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Tidak ada sertifikat',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        ...certifications.map((c) {
            final approvalStatus = c.approvalStatus.toLowerCase();
            final approvalStyle = approvalStatusStyle(approvalStatus);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CertificationDetailScreen(
                            certification: c, isReadOnly: true)));
              },
              child: Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (c.fileUrl != null && c.fileUrl!.isNotEmpty)
                          ? Image.network(
                              c.fileUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.workspace_premium_outlined,
                                      color: Color(0xFF8E24AA), size: 24),
                            )
                          : const Icon(Icons.workspace_premium_outlined,
                              color: Color(0xFF8E24AA), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name.isNotEmpty ? c.name : '-',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('No. ${c.certificationNumber}',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13)),
                          if (c.issuer.isNotEmpty)
                            Text('Penerbit: ${c.issuer}',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
                          if (c.obtainedAt != null)
                            Text('Diperoleh: ${c.obtainedAt}',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12)),
                          if (c.expiredAt != null)
                            Text('Berlaku s/d: ${c.expiredAt}',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: approvalStyle.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: approvalStyle.fg.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            approvalStyle.label,
                            style: TextStyle(
                                color: approvalStyle.fg,
                                fontWeight: FontWeight.bold,
                                fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _ProfileNavItem({
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
                color: Colors.grey,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
