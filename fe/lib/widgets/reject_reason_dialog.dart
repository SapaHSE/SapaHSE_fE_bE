import 'package:flutter/material.dart';

Future<String?> showRejectReasonDialog(
  BuildContext context, {
  String title = 'Tolak Pengajuan',
  String description = 'Berikan alasan penolakan:',
  String hintText = 'Contoh: Dokumen tidak jelas atau data belum lengkap.',
  String confirmLabel = 'Tolak',
  bool requireReason = true,
}) async {
  final reasonCtrl = TextEditingController();
  String? errorText;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                errorText: errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (requireReason && reason.isEmpty) {
                setModalState(() => errorText = 'Alasan penolakan wajib diisi.');
                return;
              }
              Navigator.pop(ctx, reason);
            },
            child: Text(
              confirmLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );

  reasonCtrl.dispose();
  return result;
}
