import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';
import '../main.dart';
import 'create_hazard_screen.dart';
import 'create_inspection_screen.dart';
import 'qr_scan_screen.dart';
import 'my_profile.dart';
import 'package:local_auth/local_auth.dart';
import '../widgets/minimal_dropdown.dart';
import '../widgets/fab_notched_bottom_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'Indonesia';
  bool _isDarkMode = false;
  bool _isPushEnabled = true;
  bool _isBiometricEnabled = false;
  static const _blue = Color(0xFF1A56C4);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bioEnabled = await StorageService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricEnabled = bioEnabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Biometrik tidak didukung di platform Web.')));
      return;
    }

    if (!enable) {
      await StorageService.setBiometricEnabled(false);
      setState(() => _isBiometricEnabled = false);
      return;
    }

    final user = await StorageService.getUser();
    final employeeId = user?['employee_id'] as String?;
    if (employeeId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi tidak valid.')));
      return;
    }

    final localAuth = LocalAuthentication();
    try {
      final canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      if (!canCheck) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perangkat tidak mendukung biometrik.')));
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Gunakan biometrik untuk mengaktifkan login otomatis',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        if (!mounted) return;
        final password = await _showPasswordPromptDialog(context);
        if (password != null && password.isNotEmpty) {
          await StorageService.saveBiometricCredentials(employeeId, password);
          await StorageService.setBiometricEnabled(true);
          setState(() => _isBiometricEnabled = true);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login biometrik diaktifkan.')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<String?> _showPasswordPromptDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan password Anda untuk disimpan dengan aman sebagai kredensial biometrik.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56C4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Simpan'),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsFabMenuSheet(
        currentIndex: 4,
        onScanQr: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
        },
        onCreateHazard: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateHazardScreen()));
        },
        onCreateInspection: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateInspectionScreen()));
        },
        onAddCarousel: () {
          Navigator.pop(context);
        },
        onAddNews: () {
          Navigator.pop(context);
        },
        onEditBiodata: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen(initialAction: 'edit_biodata')));
        },
        onAddLicense: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen(initialAction: 'add_license')));
        },
        onAddCertification: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen(initialAction: 'add_certification')));
        },
        onEditMedical: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen(initialAction: 'edit_medical')));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 148),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('PREFERENSI APLIKASI'),
            _buildCard([
              _buildDropdownRow(
                icon: Icons.language,
                iconColor: const Color(0xFF1976D2),
                label: 'Bahasa',
                subtitle: 'Bahasa tampilan aplikasi',
                value: _selectedLanguage,
                items: ['Indonesia', 'English'],
                onChanged: (v) => setState(() => _selectedLanguage = v!),
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: Icons.dark_mode,
                iconColor: Colors.black,
                label: 'Tema Gelap',
                value: _isDarkMode,
                onChanged: (v) => setState(() => _isDarkMode = v),
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: Icons.notifications_active,
                iconColor: const Color(0xFFFBC02D),
                label: 'Notifikasi Push',
                subtitle: 'Laporan, pengumuman, tugas',
                value: _isPushEnabled,
                onChanged: (v) => setState(() => _isPushEnabled = v),
              ),
            ]),
            _buildSectionHeader('SINKRONISASI & PENYIMPANAN'),
            _buildCard([
              _buildActionRow(
                icon: Icons.sync,
                iconColor: const Color(0xFF43A047),
                label: 'Status Sinkronisasi',
                subtitle: 'Tersinkron 2 menit lalu • 1 menunggu',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('1',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              _buildDivider(),
              _buildActionRow(
                icon: Icons.storage,
                iconColor: const Color(0xFF5C38FF),
                label: 'Local Storage',
                subtitle: '47 MB used of 500 MB',
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('Hapus',
                      style: TextStyle(
                          color: Color(0xFF5C38FF),
                          fontWeight: FontWeight.bold)),
                ),
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: Icons.fingerprint,
                iconColor: const Color(0xFFF57C00),
                label: 'Login Biometrik',
                subtitle: 'Face ID / Sidik Jari',
                value: _isBiometricEnabled,
                onChanged: _toggleBiometric,
              ),
            ]),
            _buildSectionHeader('AKUN'),
            _buildCard([
              _buildMenuRow(Icons.lock_outline, 'Ganti Kata Sandi', '',
                  onTap: () => _showChangePasswordDialog(context)),
              _buildDivider(),
              _buildMenuRow(Icons.logout, 'Keluar', '',
                  isDestructive: true, onTap: () => _showLogoutDialog(context)),
            ]),
            const SizedBox(height: 40),
          ],
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
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: FabNotchedBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SettingsNavItem(icon: Icons.home, label: 'Home', index: 0, currentIndex: 4, onTap: _onTabTapped),
            _SettingsNavItem(icon: Icons.article_outlined, label: 'News', index: 1, currentIndex: 4, onTap: _onTabTapped),
            const SizedBox(width: 56),
            _SettingsNavItem(icon: Icons.inbox_outlined, label: 'Inbox', index: 3, currentIndex: 4, onTap: _onTabTapped),
            _SettingsNavItem(icon: Icons.menu, label: 'Menu', index: 4, currentIndex: 4, onTap: _onTabTapped),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Text(title,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      );

  Widget _buildCard(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(children: children),
      );

  Widget _buildDivider() =>
      Divider(height: 1, color: Colors.grey.shade50, indent: 60, endIndent: 16);

  Widget _buildSwitchRow(
          {required IconData icon,
          required Color iconColor,
          required String label,
          String? subtitle,
          required bool value,
          required ValueChanged<bool> onChanged}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildIconBox(icon, iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF1565C0),
              activeTrackColor: const Color(0xFF1565C0).withValues(alpha: 0.2),
            ),
          ],
        ),
      );

  Widget _buildDropdownRow(
          {required IconData icon,
          required Color iconColor,
          required String label,
          required String subtitle,
          required String value,
          required List<String> items,
          required ValueChanged<String?> onChanged}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildIconBox(icon, iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
            ),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
                boxShadow: kMinimalDropdownShadow,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  items: items
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: kMinimalDropdownTextStyle)))
                      .toList(),
                  onChanged: onChanged,
                  icon: kMinimalDropdownChevron,
                  borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
                  elevation: 4,
                  dropdownColor: Colors.white,
                  style: kMinimalDropdownTextStyle,
                ),
              ),
            ),
          ],
        ),
      );


  Widget _buildActionRow(
          {required IconData icon,
          required Color iconColor,
          required String label,
          required String subtitle,
          required Widget trailing}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildIconBox(icon, iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );

  Widget _buildMenuRow(IconData icon, String label, String subtitle,
          {bool isDestructive = false, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildIconBox(
                  icon, isDestructive ? Colors.red : Colors.grey.shade400,
                  isOutline: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDestructive ? Colors.red : Colors.black)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
            ],
          ),
        ),
      );

  Widget _buildIconBox(IconData icon, Color color, {bool isOutline = false}) =>
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isOutline ? Colors.transparent : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: isOutline ? Border.all(color: Colors.grey.shade100) : null,
        ),
        child: Icon(icon, color: color, size: 20),
      );

  void _showChangePasswordDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ubah Password',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(errorMsg!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    _buildDialogField('Password Lama', oldCtrl, hint: 'Masukkan password lama'),
                    const SizedBox(height: 16),
                    _buildDialogField('Password Baru', newCtrl, hint: 'Minimal 8 karakter'),
                    const SizedBox(height: 16),
                    _buildDialogField('Konfirmasi Password Baru', confirmCtrl, hint: 'Ulangi password baru'),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          setModalState(() {
                            isLoading = true;
                            errorMsg = null;
                          });

                          final result = await ProfileService.changePassword(
                            currentPassword: oldCtrl.text,
                            newPassword: newCtrl.text,
                            confirmPassword: confirmCtrl.text,
                          );

                          if (!context.mounted) return;

                          if (result.success) {
                            Navigator.pop(context);
                            await StorageService.clear();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password berhasil diubah. Silakan login kembali.')),
                            );
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          } else {
                            setModalState(() {
                              isLoading = false;
                              errorMsg = result.message;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56C4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

  Widget _buildDialogField(String label, TextEditingController controller, {required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A56C4), width: 1.5)),
          ),
        ),
      ],
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
              await StorageService.clear();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _SettingsFabMenuSheet extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onScanQr;
  final VoidCallback onCreateHazard;
  final VoidCallback onCreateInspection;
  final VoidCallback onAddCarousel;
  final VoidCallback onAddNews;
  final VoidCallback onEditBiodata;
  final VoidCallback onAddLicense;
  final VoidCallback onAddCertification;
  final VoidCallback onEditMedical;

  const _SettingsFabMenuSheet({
    required this.currentIndex,
    required this.onScanQr,
    required this.onCreateHazard,
    required this.onCreateInspection,
    required this.onAddCarousel,
    required this.onAddNews,
    required this.onEditBiodata,
    required this.onAddLicense,
    required this.onAddCertification,
    required this.onEditMedical,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4)),
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
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Pilih Aksi',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsFabMenuTile(
            icon: Icons.qr_code_scanner,
            iconBgColor: const Color(0xFFEFF4FF),
            iconColor: const Color(0xFF1A56C4),
            title: 'Scan QR Code',
            subtitle: 'Pindai QR untuk verifikasi peralatan',
            onTap: onScanQr,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _SettingsFabMenuTile(
            icon: Icons.warning_amber_rounded,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFF44336),
            title: 'Buat Laporan Hazard',
            subtitle: 'Laporkan potensi bahaya di area kerja',
            onTap: onCreateHazard,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _SettingsFabMenuTile(
            icon: Icons.search,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            title: 'Buat Laporan Inspeksi',
            subtitle: 'Catat hasil inspeksi rutin area kerja',
            onTap: onCreateInspection,
          ),
          if (currentIndex == 0) ...[
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
            _SettingsFabMenuTile(
              icon: Icons.add_photo_alternate_outlined,
              iconBgColor: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              title: 'Tambah Gambar Carousel',
              subtitle: 'Tambah banner gambar di halaman utama',
              onTap: onAddCarousel,
            ),
          ],
          if (currentIndex == 1) ...[
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
            _SettingsFabMenuTile(
              icon: Icons.article_outlined,
              iconBgColor: const Color(0xFFFFF3E0),
              iconColor: const Color(0xFFE65100),
              title: 'Tambah Berita',
              subtitle: 'Buat dan publikasikan berita baru',
              onTap: onAddNews,
            ),
          ],
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _SettingsFabMenuTile(
            icon: Icons.person_outline,
            iconBgColor: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF8E24AA),
            title: 'Edit Biodata',
            subtitle: 'Perbarui nomor telepon & email',
            onTap: onEditBiodata,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _SettingsFabMenuTile(
            icon: Icons.badge_outlined,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1E88E5),
            title: 'Tambah Lisensi',
            subtitle: 'Tambahkan SIM/SIO',
            onTap: onAddLicense,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _SettingsFabMenuTile(
            icon: Icons.workspace_premium_outlined,
            iconBgColor: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFEF6C00),
            title: 'Tambah Sertifikat',
            subtitle: 'Tambahkan sertifikasi keahlian',
            onTap: onAddCertification,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _SettingsFabMenuTile(
            icon: Icons.medical_services_outlined,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFE53935),
            title: 'Edit Data Medis',
            subtitle: 'Perbarui info kesehatan & alergi',
            onTap: onEditMedical,
          ),
          const SizedBox(height: 8),
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
                      side: BorderSide(color: Colors.grey.shade200)),
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

class _SettingsFabMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsFabMenuTile({
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
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}

class _SettingsNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _SettingsNavItem({
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

