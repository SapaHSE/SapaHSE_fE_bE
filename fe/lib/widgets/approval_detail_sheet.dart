import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/inbox_item.dart';

class ApprovalDetailSheet extends StatefulWidget {
  final InboxItem item;
  final Future<bool> Function()? onApprove;
  final Future<bool> Function()? onReject;
  final VoidCallback? onDone;
  final bool showActionButtons;

  const ApprovalDetailSheet({
    super.key,
    required this.item,
    this.onApprove,
    this.onReject,
    this.onDone,
    this.showActionButtons = true,
  });

  @override
  State<ApprovalDetailSheet> createState() => _ApprovalDetailSheetState();
}

class _ApprovalDetailSheetState extends State<ApprovalDetailSheet> {
  bool _submitting = false;

  static const _regColor = Color(0xFF1A56C4);
  static const _licenseColor = Color(0xFFEF6C00);
  static const _certColor = Color(0xFF6A1B9A);

  Color get _accent {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return _regColor;
      case InboxItemType.approvalLicense:
        return _licenseColor;
      case InboxItemType.approvalCertification:
        return _certColor;
      default:
        return _regColor;
    }
  }

  IconData get _icon {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return Icons.person_add_alt_1;
      case InboxItemType.approvalLicense:
        return Icons.badge_outlined;
      case InboxItemType.approvalCertification:
        return Icons.workspace_premium;
      default:
        return Icons.assignment_turned_in_outlined;
    }
  }

  String get _category {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return 'REGISTRASI USER';
      case InboxItemType.approvalLicense:
        return 'INPUT LISENSI';
      case InboxItemType.approvalCertification:
        return 'INPUT SERTIFIKAT';
      default:
        return 'PENGAJUAN';
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year;
    return '$dd/$mm/$yyyy';
  }

  ({String label, Color bg, Color fg, Color border}) _statusStyle(
    String? rawStatus,
  ) {
    final status = (rawStatus ?? 'pending').toLowerCase();
    switch (status) {
      case 'approved':
        return (
          label: 'Disetujui',
          bg: const Color(0xFFE8F5E9),
          fg: const Color(0xFF2E7D32),
          border: const Color(0xFFB7E1BC)
        );
      case 'rejected':
        return (
          label: 'Ditolak',
          bg: const Color(0xFFFFEBEE),
          fg: const Color(0xFFC62828),
          border: const Color(0xFFFFCDD2)
        );
      default:
        return (
          label: 'Menunggu',
          bg: const Color(0xFFFFF8E1),
          fg: const Color(0xFFEF6C00),
          border: const Color(0xFFFFE082)
        );
    }
  }

  Future<void> _runAction(Future<bool> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context);
      widget.onDone?.call();
    }
  }

  Widget _row(String label, String? value) {
    final text = (value == null || value.trim().isEmpty) ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final submitDate = item.submittedAt ?? item.createdAt;
    final status = _statusStyle(item.approvalStatus);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon, color: _accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _category,
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: status.bg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: status.border),
                              ),
                              child: Text(
                                status.label,
                                style: TextStyle(
                                  color: status.fg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((item.description ?? '').trim().isNotEmpty)
                    Text(
                      item.description!,
                      style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                    ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  _row('Pemohon', item.submitterName),
                  _row('Departemen', item.submitterDept),
                  _row('Perusahaan', item.submitterCompany),
                  _row('Tanggal Pengajuan', _fmtDate(submitDate)),
                  _row('Status', status.label),
                  _row('Email', item.submitterEmail),
                  _row('NIP', item.submitterEmployeeId),
                  _row('Jabatan', item.submitterPosition),
                  _row('Telepon', item.submitterPhone),
                  if ((item.rejectionReason ?? '').trim().isNotEmpty)
                    _row('Alasan Ditolak', item.rejectionReason),
                  if (item.itemType == InboxItemType.approvalLicense) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 10),
                    _row('Nama Lisensi', item.itemName),
                    _row('Nomor Lisensi', item.itemNumber),
                    _row('Tgl Terbit', _fmtDate(item.itemObtainedAt)),
                    _row('Tgl Kadaluarsa', _fmtDate(item.itemExpiredAt)),
                  ],
                  if (item.itemType == InboxItemType.approvalCertification) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 10),
                    _row('Nama Sertifikat', item.itemName),
                    _row('Penerbit', item.itemIssuer),
                    _row('Tgl Terbit', _fmtDate(item.itemObtainedAt)),
                    _row('Tgl Kadaluarsa', _fmtDate(item.itemExpiredAt)),
                  ],
                  if ((item.itemFileUrl ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Lampiran Dokumen',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: item.itemFileUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 180,
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: const Text(
                            'Preview tidak tersedia',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: widget.showActionButtons &&
                        widget.onApprove != null &&
                        widget.onReject != null
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _submitting
                                  ? null
                                  : () => _runAction(widget.onReject!),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submitting
                                  ? null
                                  : () => _runAction(widget.onApprove!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('Setujui'),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56C4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Tutup'),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
