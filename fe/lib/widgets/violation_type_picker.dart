import 'package:flutter/material.dart';

import 'app_safe_insets.dart';
import 'minimal_dropdown.dart';

Future<void> showViolationTypePicker({
  required BuildContext context,
  required ValueChanged<String> onSelected,
  VoidCallback? onDeleteMode,
  String title = 'Aksi Violation & Incident',
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Container(
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppSafeInsets.sheetBottomPadding(sheetContext, base: 32),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ViolationTypeTile(
            icon: Icons.warning_amber_rounded,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFD32F2F),
            title: 'Add Violation',
            subtitle: 'Catat pelanggaran disiplin atau K3',
            onTap: () {
              Navigator.pop(sheetContext);
              onSelected('Violation');
            },
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ViolationTypeTile(
            icon: Icons.report_problem_outlined,
            iconBgColor: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFF57C00),
            title: 'Add Incident',
            subtitle: 'Catat insiden atau kejadian kerja',
            onTap: () {
              Navigator.pop(sheetContext);
              onSelected('Incident');
            },
          ),
          if (onDeleteMode != null) ...[
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
            _ViolationTypeTile(
              icon: Icons.delete_sweep_outlined,
              iconBgColor: const Color(0xFFFFEBEE),
              iconColor: const Color(0xFFE53935),
              title: 'Hapus Data',
              subtitle: 'Pilih satu atau beberapa data untuk dihapus',
              onTap: () {
                Navigator.pop(sheetContext);
                onDeleteMode();
              },
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: const Text('Batal', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ViolationTypeTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ViolationTypeTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
