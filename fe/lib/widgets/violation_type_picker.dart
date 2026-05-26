import 'package:flutter/material.dart';

import 'app_safe_insets.dart';

Future<void> showViolationTypePicker({
  required BuildContext context,
  required ValueChanged<String> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        AppSafeInsets.sheetBottomPadding(sheetContext, base: 18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Pilih Jenis Catatan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          _ViolationTypeTile(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFD32F2F),
            title: 'Beri Violation',
            subtitle: 'Catat pelanggaran disiplin atau K3',
            onTap: () {
              Navigator.pop(sheetContext);
              onSelected('Violation');
            },
          ),
          const Divider(height: 1),
          _ViolationTypeTile(
            icon: Icons.report_problem_outlined,
            color: const Color(0xFFF57C00),
            title: 'Beri Incident',
            subtitle: 'Catat insiden atau kejadian kerja',
            onTap: () {
              Navigator.pop(sheetContext);
              onSelected('Incident');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _ViolationTypeTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ViolationTypeTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}
