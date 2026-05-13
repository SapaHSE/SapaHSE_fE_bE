import 'package:flutter/material.dart';

typedef ApprovalStatusStyle = ({
  String label,
  Color bg,
  Color fg,
  Color border,
});

String normalizeApprovalStatus(String? rawStatus) {
  final status = (rawStatus ?? 'pending').trim().toLowerCase();
  if (status == 'approved' || status == 'rejected') return status;
  return 'pending';
}

ApprovalStatusStyle approvalStatusStyle(String? rawStatus) {
  final status = normalizeApprovalStatus(rawStatus);
  final openColor = const Color(0xFF2196F3); // ReportStatus.open
  final closedColor = const Color(0xFF757575); // ReportStatus.closed
  switch (status) {
    case 'approved':
      return (
        label: 'Approved',
        bg: openColor.withValues(alpha: 0.1),
        fg: openColor,
        border: openColor.withValues(alpha: 0.3),
      );
    case 'rejected':
      return (
        label: 'Rejected',
        bg: closedColor.withValues(alpha: 0.1),
        fg: closedColor,
        border: closedColor.withValues(alpha: 0.3),
      );
    default:
      return (
        label: 'Validating',
        bg: openColor.withValues(alpha: 0.1),
        fg: openColor,
        border: openColor.withValues(alpha: 0.3),
      );
  }
}
