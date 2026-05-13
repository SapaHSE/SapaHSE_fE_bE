import 'package:flutter/material.dart';

import '../models/inbox_item.dart';

class ApprovalTaskCard extends StatelessWidget {
  final InboxItem item;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isProcessing;

  const ApprovalTaskCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    this.isProcessing = false,
  });

  static const _regColor = Color(0xFF1A56C4);
  static const _licenseColor = Color(0xFFEF6C00);
  static const _certColor = Color(0xFF6A1B9A);

  Color get _accent {
    switch (item.itemType) {
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
    switch (item.itemType) {
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

  String get _categoryLabel {
    switch (item.itemType) {
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

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year;
    return '$dd/$mm/$yyyy';
  }

  @override
  Widget build(BuildContext context) {
    final submittedAt = item.submittedAt ?? item.createdAt;
    final submitter = item.submitterName ?? 'Pemohon';
    final department = item.submitterDept ?? '-';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
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
                            Text(
                              _categoryLabel,
                              style: TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: const Text(
                          'Menunggu',
                          style: TextStyle(
                            color: Color(0xFFEF6C00),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((item.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      item.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$submitter • $department',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.event_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(submittedAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isProcessing ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Setujui'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
