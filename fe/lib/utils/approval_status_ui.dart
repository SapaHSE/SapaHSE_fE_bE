import 'package:flutter/material.dart';

typedef ApprovalStatusStyle = ({
  String label,
  Color bg,
  Color fg,
  Color border,
});

String normalizeApprovalStatus(String? rawStatus) {
  final status = (rawStatus ?? 'pending').trim().toLowerCase();
  if (status == 'approved' || status == 'rejected' || status == 'pending_changes') return status;
  return 'pending';
}

ApprovalStatusStyle approvalStatusStyle(String? rawStatus) {
  final status = normalizeApprovalStatus(rawStatus);
  switch (status) {
    case 'approved':
      return (
        label: 'Validate',
        bg: const Color(0xFFE8F5E9),
        fg: const Color(0xFF2E7D32),
        border: const Color(0xFFC8E6C9),
      );
    case 'rejected':
      return (
        label: 'Rejected',
        bg: const Color(0xFFFFEBEE),
        fg: const Color(0xFFC62828),
        border: const Color(0xFFFFCDD2),
      );
    case 'pending_changes':
      return (
        label: 'Menunggu Persetujuan Perubahan',
        bg: const Color(0xFFFFF8E1),
        fg: const Color(0xFFE65100),
        border: const Color(0xFFFFE082),
      );
    default: // pending / validating
      return (
        label: 'Validating',
        bg: const Color(0xFFE3F2FD),
        fg: const Color(0xFF2196F3),
        border: const Color(0xFFBBDEFB),
      );
  }
}
