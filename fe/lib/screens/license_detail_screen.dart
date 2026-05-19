import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile_model.dart';
import '../services/profile_service.dart';
import '../utils/approval_status_ui.dart';
import '../widgets/app_safe_insets.dart';

class LicenseDetailScreen extends StatefulWidget {
  final UserLicense license;
  final VoidCallback? onRefresh;

  final bool isApprovalMode;
  final Future<void> Function(String, String)? onApprove;
  final Future<void> Function(String, String)? onReject;

  final String? submitterName;
  final String? submitterEmployeeId;
  final String? submitterDept;
  final String? submitterPosition;
  final String? submitterCompany;
  final String? submitterEmail;
  final String? submitterPhone;
  final String? submitterPhotoUrl;

  final Function(UserLicense)? onProfileEdit;
  final Function(UserLicense)? onProfileDelete;

  const LicenseDetailScreen({
    super.key,
    required this.license,
    this.onRefresh,
    this.isApprovalMode = false,
    this.onApprove,
    this.onReject,
    this.submitterName,
    this.submitterEmployeeId,
    this.submitterDept,
    this.submitterPosition,
    this.submitterCompany,
    this.submitterEmail,
    this.submitterPhone,
    this.submitterPhotoUrl,
    this.onProfileEdit,
    this.onProfileDelete,
  });

  @override
  State<LicenseDetailScreen> createState() => _LicenseDetailScreenState();
}

class _LicenseDetailScreenState extends State<LicenseDetailScreen> {
  late UserLicense _license;
  bool _isSubmitting = false;

  static const _blue = Color(0xFF1A56C4);

  @override
  void initState() {
    super.initState();
    _license = widget.license;
  }

  ApprovalStatusStyle get _approvalStyle =>
      approvalStatusStyle(_license.approvalStatus);

  bool get _isProfileActionMode =>
      !widget.isApprovalMode &&
      (widget.onProfileEdit != null || widget.onProfileDelete != null);

  bool get _hasSubmitterInfo {
    final fields = [
      widget.submitterName,
      widget.submitterEmployeeId,
      widget.submitterDept,
      widget.submitterPosition,
      widget.submitterCompany,
      widget.submitterEmail,
      widget.submitterPhone,
      widget.submitterPhotoUrl,
    ];
    return fields.any((f) => (f ?? '').trim().isNotEmpty);
  }

  String _displayValue(String? value) {
    final v = value?.trim();
    return (v != null && v.isNotEmpty) ? v : '-';
  }

  String _initials(String? name) {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return 'U';
    final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
  }

  String _formatDate(DateTime dt, {bool withTime = true}) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    if (!withTime) {
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateText(String? raw, {bool withTime = true}) {
    final dt = _parseDate(raw);
    if (dt == null) return _displayValue(raw);
    return _formatDate(dt, withTime: withTime);
  }

  ImageProvider? _resolveSubmitterPhoto() {
    final url = (widget.submitterPhotoUrl ?? '').trim();
    if (url.isEmpty) return null;
    return CachedNetworkImageProvider(url);
  }

  Future<void> _handleApprove() async {
    if (_isSubmitting || widget.onApprove == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Setujui Pengajuan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menyetujui pengajuan dokumen ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F80ED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onApprove!('license', _license.id);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleReject() async {
    if (_isSubmitting || widget.onReject == null) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onReject!('license', _license.id);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildHeroArea() {
    final fileUrl = (_license.fileUrl ?? '').trim();
    final hasImage = fileUrl.isNotEmpty;

    final fallback = Container(
      color: _blue.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.badge_outlined,
        color: _blue.withValues(alpha: 0.65),
        size: 68,
      ),
    );

    return SizedBox(
      width: double.infinity,
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: fileUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            )
          else
            fallback,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 16,
            child: Row(
              children: [
                _badge(_approvalStyle.label, _approvalStyle.fg,
                    bg: _approvalStyle.bg),
                const SizedBox(width: 8),
                _badge('LISENSI', const Color(0xFFEF6C00)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActions() {
    final rejected = _license.approvalStatus.toLowerCase() == 'rejected';

    if (rejected && widget.onProfileEdit != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => widget.onProfileEdit!(_license),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.edit_note),
          label: const Text(
            'Edit & Pengajuan Ulang',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
    }

    if (!_license.isActive) {
      if (widget.onProfileDelete != null && widget.onProfileEdit != null) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => widget.onProfileDelete!(_license),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text(
                  'Hapus Lisensi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => widget.onProfileEdit!(_license),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.history),
                label: const Text(
                  'Perpanjang',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        );
      }

      if (widget.onProfileEdit != null) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => widget.onProfileEdit!(_license),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.history),
            label: const Text(
              'Perpanjang',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        );
      }

      if (widget.onProfileDelete != null) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => widget.onProfileDelete!(_license),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text(
              'Hapus Lisensi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        );
      }
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          if (widget.onProfileEdit != null) {
            widget.onProfileEdit!(_license);
            return;
          }
          _showEditLicenseForm(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.edit),
        label: const Text(
          'Edit Lisensi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    if (widget.isApprovalMode &&
        widget.onApprove != null &&
        widget.onReject != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : _handleReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                backgroundColor:
                    const Color(0xFFC62828).withValues(alpha: 0.08),
                side: BorderSide(
                    color: const Color(0xFFC62828).withValues(alpha: 0.42)),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Tolak',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F80ED),
                foregroundColor: Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Setujui',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      );
    }

    if (_isProfileActionMode) return _buildProfileActions();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showEditLicenseForm(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.edit),
        label: const Text(
          'Edit Lisensi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiry = _parseDate(_license.expiredAt);
    final isExpired = expiry != null && expiry.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Lisensi',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroArea(),
            _card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _license.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'LISENSI',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFEF6C00),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.numbers,
                    label: 'Nomor Lisensi',
                    value: _displayValue(_license.licenseNumber),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.business_outlined,
                    label: 'Lembaga Penerbit',
                    value: _displayValue(_license.issuer),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.info_outline,
                    label: 'Status Approval',
                    value: _approvalStyle.label,
                    valueColor: _approvalStyle.fg,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.verified_outlined,
                    label: 'Status Verifikasi',
                    value: _license.isVerified
                        ? 'Terverifikasi'
                        : 'Tunggu Verifikasi',
                    valueColor: _license.isVerified
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEF6C00),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.flag_outlined,
                    label: 'Status Dokumen',
                    value: _license.isActive ? 'Aktif' : 'Expired',
                    valueColor: _license.isActive
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFD32F2F),
                  ),
                  if ((_license.submittedAt ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.access_time,
                      label: 'Tanggal Pengajuan',
                      value: _formatDateText(_license.submittedAt),
                    ),
                  ],
                  if ((_license.reviewedAt ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.history,
                      label: 'Tanggal Review',
                      value: _formatDateText(_license.reviewedAt),
                    ),
                  ],
                  if ((_license.rejectionReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFC62828),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Alasan Penolakan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _license.rejectionReason!.trim(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: Icons.badge_outlined,
                    title: 'Detail Lisensi',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.label_outline,
                    label: 'Nama',
                    value: _displayValue(_license.name),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.event_outlined,
                    label: 'Tanggal Diperoleh',
                    value: _formatDateText(_license.obtainedAt, withTime: false),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.event_busy_outlined,
                    label: 'Berlaku Sampai',
                    value: _formatDateText(_license.expiredAt, withTime: false),
                    valueColor: isExpired ? const Color(0xFFF44336) : null,
                  ),
                ],
              ),
            ),
            if (_hasSubmitterInfo)
              _card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      icon: Icons.person_outline,
                      title: 'Informasi Pemohon',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _blue.withValues(alpha: 0.15),
                          backgroundImage: _resolveSubmitterPhoto(),
                          child: _resolveSubmitterPhoto() == null
                              ? Text(
                                  _initials(widget.submitterName),
                                  style: const TextStyle(
                                    color: _blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayValue(widget.submitterName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if ((widget.submitterPosition ?? '').trim().isNotEmpty ||
                                  (widget.submitterDept ?? '').trim().isNotEmpty)
                                Text(
                                  '${_displayValue(widget.submitterPosition)} • ${_displayValue(widget.submitterDept)}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if ((widget.submitterEmployeeId ?? '').trim().isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Employee ID',
                        value: _displayValue(widget.submitterEmployeeId),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if ((widget.submitterEmail ?? '').trim().isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: _displayValue(widget.submitterEmail),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if ((widget.submitterPhone ?? '').trim().isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Telepon',
                        value: _displayValue(widget.submitterPhone),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if ((widget.submitterCompany ?? '').trim().isNotEmpty)
                      _DetailRow(
                        icon: Icons.business_outlined,
                        label: 'Perusahaan',
                        value: _displayValue(widget.submitterCompany),
                      ),
                  ],
                ),
              ),
            SizedBox(
              height: 20 + MediaQuery.of(context).padding.bottom,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: _buildActionBar(),
        ),
      ),
    );
  }

  Widget _card({required Widget child, required EdgeInsets margin}) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _badge(String label, Color color, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bg != null ? color : Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showEditLicenseForm(BuildContext context) {
    final nameCtrl = TextEditingController(text: _license.name);
    final numberCtrl = TextEditingController(text: _license.licenseNumber);
    final issuerCtrl = TextEditingController(text: _license.issuer);
    DateTime? obtainedAt =
        _license.obtainedAt != null ? DateTime.tryParse(_license.obtainedAt!) : null;
    DateTime? expiredAt =
        _license.expiredAt != null ? DateTime.tryParse(_license.expiredAt!) : null;
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
            bottom: AppSafeInsets.sheetBottomPadding(context),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Edit Lisensi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildModalLabel('Foto Lisensi'),
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 70);
                    if (picked != null) {
                      setModalState(() => newImage = picked);
                    }
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
                                  Icon(Icons.add_a_photo_outlined,
                                      color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text(
                                    'Ganti Foto',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
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
                          _buildDatePicker(
                            context,
                            obtainedAt,
                            (d) => setModalState(() => obtainedAt = d),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModalLabel('Berlaku Sampai'),
                          _buildDatePicker(
                            context,
                            expiredAt,
                            (d) => setModalState(() => expiredAt = d),
                          ),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Memperbarui lisensi...')),
                      );

                      final result = await ProfileService.updateLicense(
                        id: _license.id,
                        name: nameCtrl.text,
                        licenseNumber: numberCtrl.text,
                        issuer: issuerCtrl.text,
                        obtainedAt: obtainedAt != null
                            ? '${obtainedAt!.year}-${obtainedAt!.month.toString().padLeft(2, '0')}-${obtainedAt!.day.toString().padLeft(2, '0')}'
                            : null,
                        expiredAt: expiredAt != null
                            ? '${expiredAt!.year}-${expiredAt!.month.toString().padLeft(2, '0')}-${expiredAt!.day.toString().padLeft(2, '0')}'
                            : null,
                        imageFile: newImage,
                      );

                      if (!context.mounted) return;
                      if (result.success) {
                        widget.onRefresh?.call();
                        final profileRes = await ProfileService.getProfile();
                        if (!context.mounted) return;
                        if (profileRes.success && profileRes.data != null) {
                          final updatedLicense = profileRes.data!.licenses.firstWhere(
                            (l) => l.id == _license.id,
                            orElse: () => _license,
                          );
                          setState(() {
                            _license = updatedLicense;
                          });
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lisensi berhasil diperbarui')),
                        );
                      } else {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(result.message)));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Simpan Perubahan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      );

  InputDecoration _buildInputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue),
        ),
      );

  Widget _buildDatePicker(
    BuildContext context,
    DateTime? date,
    Function(DateTime) onPicked,
  ) {
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
                style: TextStyle(
                  fontSize: 13,
                  color: date == null ? Colors.grey.shade500 : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1A56C4), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? Colors.black87,
                  fontWeight:
                      valueColor != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
