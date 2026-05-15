import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/profile_model.dart';
import '../services/profile_service.dart';
import '../main.dart';
import '../widgets/fab_notched_bottom_bar.dart';

class LicenseDetailScreen extends StatefulWidget {
  final UserLicense license;
  final VoidCallback onRefresh;

  final bool isApprovalMode;
  final Future<void> Function(String, String)? onApprove;
  final Future<void> Function(String, String)? onReject;

  const LicenseDetailScreen({
    super.key,
    required this.license,
    required this.onRefresh,
    this.isApprovalMode = false,
    this.onApprove,
    this.onReject,
  });

  @override
  State<LicenseDetailScreen> createState() => _LicenseDetailScreenState();
}

class _LicenseDetailScreenState extends State<LicenseDetailScreen> {
  late UserLicense _license;

  @override
  void initState() {
    super.initState();
    _license = widget.license;
  }

  void _onTabTapped(int index) {
    if (index == 4) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAktif = _license.isActive;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Detail Lisensi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Header ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
              ),
              child: _license.fileUrl != null
                  ? InteractiveViewer(
                      child: Image.network(
                        _license.fileUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                                child: Icon(Icons.broken_image,
                                    size: 64, color: Colors.grey)),
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined,
                              size: 80, color: Color(0xFF1A56C4)),
                          SizedBox(height: 12),
                          Text('Tidak ada foto lisensi',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
            ),

            // ── License Info Card ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _license.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_license.isVerified
                              ? const Color(0xFFFFF3E0)
                              : isAktif
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          !_license.isVerified
                              ? 'Tunggu Verifikasi'
                              : isAktif ? 'Aktif' : 'Expired',
                          style: TextStyle(
                            color: !_license.isVerified
                                ? const Color(0xFFEF6C00)
                                : isAktif
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No. ${_license.licenseNumber}',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),

                  _buildDetailSection('INFORMASI UMUM', [
                    _buildDetailRow('Lembaga Penerbit', _license.issuer ?? '-'),
                    _buildDetailRow('Status Verifikasi',
                        _license.isVerified ? 'Terverifikasi' : 'Tunggu Verifikasi',
                        valueColor: _license.isVerified
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFEF6C00)),
                  ]),

                  const SizedBox(height: 24),

                  _buildDetailSection('MASA BERLAKU', [
                    _buildDetailRow('Tanggal Diperoleh',
                        _license.obtainedAt != null
                            ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(_license.obtainedAt!))
                            : '-'),
                    _buildDetailRow('Berlaku Sampai',
                        _license.expiredAt != null
                            ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(_license.expiredAt!))
                            : '-'),
                  ]),

                  // ── Approval Actions ─────────────────────────────────────────────
                  if (widget.isApprovalMode) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              if (widget.onReject != null) {
                                await widget.onReject!('license', _license.id);
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (widget.onApprove != null) {
                                await widget.onApprove!('license', _license.id);
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Quick Action: Edit (Moved to FAB) ──────────────────────
                  const SizedBox(height: 100), // Spacer for bottom navigation
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FabNotchedBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DetailNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                onTap: _onTabTapped),
            _DetailNavItem(
                icon: Icons.article_outlined,
                label: 'News',
                index: 1,
                onTap: _onTabTapped),
            const SizedBox(width: 56),
            _DetailNavItem(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                index: 3,
                onTap: _onTabTapped),
            _DetailNavItem(
                icon: Icons.menu,
                label: 'Menu',
                index: 4,
                isActive: true,
                onTap: _onTabTapped),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (widget.isApprovalMode) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fitur tambah dokumen sedang disiapkan')),
            );
          } else {
            _showEditLicenseForm(context);
          }
        },
        backgroundColor: const Color(0xFF1A56C4),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        
        child: Icon(widget.isApprovalMode ? Icons.add : Icons.edit, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: valueColor ?? Colors.black),
          ),
        ],
      ),
    );
  }

  void _showEditLicenseForm(BuildContext context) {
    // We can navigate back to MyProfile with an action, or implement it here.
    // For a better UX, we'll implement a simple edit modal here.
    final nameCtrl = TextEditingController(text: _license.name);
    final numberCtrl = TextEditingController(text: _license.licenseNumber);
    final issuerCtrl = TextEditingController(text: _license.issuer);
    DateTime? obtainedAt = _license.obtainedAt != null ? DateTime.tryParse(_license.obtainedAt!) : null;
    DateTime? expiredAt = _license.expiredAt != null ? DateTime.tryParse(_license.expiredAt!) : null;
    XFile? newImage;

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
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Edit Lisensi',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),

                // Image Picker
                _buildModalLabel('Foto Lisensi'),
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (picked != null) setModalState(() => newImage = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: newImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(newImage!.path), fit: BoxFit.cover),
                          )
                        : _license.fileUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(_license.fileUrl!, fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text('Ganti Foto', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildModalLabel('Nama Lisensi'),
                TextField(
                  controller: nameCtrl,
                  decoration: _buildInputDecoration('Nama Lisensi'),
                ),
                const SizedBox(height: 16),
                _buildModalLabel('Nomor Lisensi'),
                TextField(
                  controller: numberCtrl,
                  decoration: _buildInputDecoration('Nomor Lisensi'),
                ),
                const SizedBox(height: 16),
                _buildModalLabel('Lembaga Penerbit'),
                TextField(
                  controller: issuerCtrl,
                  decoration: _buildInputDecoration('Lembaga Penerbit'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModalLabel('Tanggal Diperoleh'),
                          _buildDatePicker(context, obtainedAt, (d) => setModalState(() => obtainedAt = d)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModalLabel('Berlaku Sampai'),
                          _buildDatePicker(context, expiredAt, (d) => setModalState(() => expiredAt = d)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      // Show loading on current screen
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memperbarui lisensi...')));
                      
                      final result = await ProfileService.updateLicense(
                        id: _license.id,
                        name: nameCtrl.text,
                        licenseNumber: numberCtrl.text,
                        issuer: issuerCtrl.text,
                        obtainedAt: obtainedAt != null ? "${obtainedAt!.year}-${obtainedAt!.month.toString().padLeft(2,'0')}-${obtainedAt!.day.toString().padLeft(2,'0')}" : null,
                        expiredAt: expiredAt != null ? "${expiredAt!.year}-${expiredAt!.month.toString().padLeft(2,'0')}-${expiredAt!.day.toString().padLeft(2,'0')}" : null,
                        imageFile: newImage,
                      );

                      if (!context.mounted) return;
                      if (result.success) {
                        widget.onRefresh();
                        // Re-fetch profile to get updated license
                        final profileRes = await ProfileService.getProfile();
                        if (!context.mounted) return;
                        if (profileRes.success && profileRes.data != null) {
                          final updatedLicense =
                              profileRes.data!.licenses.firstWhere(
                            (l) => l.id == _license.id,
                            orElse: () => _license,
                          );
                          setState(() {
                            _license = updatedLicense;
                          });
                        }
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Lisensi berhasil diperbarui')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result.message)));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A56C4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      
                    ),
                    child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  InputDecoration _buildInputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A56C4))),
      );

  Widget _buildDatePicker(BuildContext context, DateTime? date, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date == null ? 'Pilih' : '${date.day}/${date.month}/${date.year}',
                style: TextStyle(fontSize: 13, color: date == null ? Colors.grey.shade500 : Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool isActive;
  final Function(int) onTap;

  const _DetailNavItem({
    required this.icon,
    required this.label,
    required this.index,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                size: 24),
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
