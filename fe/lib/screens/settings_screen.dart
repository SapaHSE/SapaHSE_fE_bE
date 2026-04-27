import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'Indonesia';
  bool _isDarkMode = false;
  bool _isPushEnabled = true;
  int _selectedStartView = 0;
  bool _isBiometricEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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

            _buildSectionHeader('TAMPILAN AWAL (HOME)'),
            _buildCard([
              _buildRadioRow(0, 'Workspace terakhir digunakan', 'Otomatis buka workspace sebelumnya'),
              _buildDivider(),
              _buildRadioRow(1, 'Selalu tampilkan Pilih workspace setiap login', 'Pilih workspace setiap kali login'),
              _buildDivider(),
              _buildRadioRow(2, 'Sesuai modul departemen saya', 'Buka modul aktif departemen otomatis'),
            ]),

            _buildSectionHeader('SINKRONISASI & PENYIMPANAN'),
            _buildCard([
              _buildActionRow(
                icon: Icons.sync,
                iconColor: const Color(0xFF43A047),
                label: 'Status Sinkronisasi',
                subtitle: 'Tersinkron 2 menit lalu • 1 menunggu',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                  child: const Text('1', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
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
                  child: const Text('Hapus', style: TextStyle(color: Color(0xFF5C38FF), fontWeight: FontWeight.bold)),
                ),
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: Icons.fingerprint,
                iconColor: const Color(0xFFF57C00),
                label: 'Login Biometrik',
                subtitle: 'Face ID / Sidik Jari',
                value: _isBiometricEnabled,
                onChanged: (v) => setState(() => _isBiometricEnabled = v),
              ),
            ]),

            _buildSectionHeader('AKUN'),
            _buildCard([
              _buildMenuRow(Icons.person_outline, 'Edit Akun / Profil', 'Biodata, lisensi, sertifikat, medis', onTap: () {}),
              _buildDivider(),
              _buildMenuRow(Icons.lock_outline, 'Ganti Kata Sandi', '', onTap: () => _showChangePasswordDialog(context)),
              _buildDivider(),
              _buildMenuRow(Icons.logout, 'Keluar', '', isDestructive: true, onTap: () => _showLogoutDialog(context)),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
    child: Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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

  Widget _buildDivider() => Divider(height: 1, color: Colors.grey.shade50, indent: 60, endIndent: 16);

  Widget _buildSwitchRow({required IconData icon, required Color iconColor, required String label, String? subtitle, required bool value, required ValueChanged<bool> onChanged}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        _buildIconBox(icon, iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (subtitle != null) Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
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

  Widget _buildDropdownRow({required IconData icon, required Color iconColor, required String label, required String subtitle, required String value, required List<String> items, required ValueChanged<String?> onChanged}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        _buildIconBox(icon, iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ],
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: onChanged,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildRadioRow(int index, String label, String subtitle) => GestureDetector(
    onTap: () => setState(() => _selectedStartView = index),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _selectedStartView == index ? const Color(0xFF1565C0) : Colors.grey.shade200, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ),
          if (_selectedStartView == index)
            const Icon(Icons.check_circle, color: Color(0xFF1565C0), size: 18)
          else
            Icon(Icons.circle_outlined, color: Colors.grey.shade200, size: 18),
        ],
      ),
    ),
  );

  Widget _buildActionRow({required IconData icon, required Color iconColor, required String label, required String subtitle, required Widget trailing}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        _buildIconBox(icon, iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );

  Widget _buildMenuRow(IconData icon, String label, String subtitle, {bool isDestructive = false, required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _buildIconBox(icon, isDestructive ? Colors.red : Colors.grey.shade400, isOutline: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDestructive ? Colors.red : Colors.black)),
                if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
        ],
      ),
    ),
  );

  Widget _buildIconBox(IconData icon, Color color, {bool isOutline = false}) => Container(
    width: 36, height: 36,
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ubah Password', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              _PasswordField(controller: oldCtrl, hint: 'Password lama'),
              const SizedBox(height: 10),
              _PasswordField(controller: newCtrl, hint: 'Password baru'),
              const SizedBox(height: 10),
              _PasswordField(controller: confirmCtrl, hint: 'Konfirmasi password baru'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
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
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
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
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1565C0))),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}
