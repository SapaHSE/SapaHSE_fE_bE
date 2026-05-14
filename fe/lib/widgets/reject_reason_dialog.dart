import 'package:flutter/material.dart';

Future<String?> showRejectReasonDialog(
  BuildContext context, {
  String title = 'Tolak Pengajuan',
  String description = 'Berikan alasan penolakan:',
  String hintText = 'Contoh: Dokumen tidak jelas atau data belum lengkap.',
  String confirmLabel = 'Tolak',
  bool requireReason = true,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _RejectReasonDialog(
      title: title,
      description: description,
      hintText: hintText,
      confirmLabel: confirmLabel,
      requireReason: requireReason,
    ),
  );
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({
    required this.title,
    required this.description,
    required this.hintText,
    required this.confirmLabel,
    required this.requireReason,
  });

  final String title;
  final String description;
  final String hintText;
  final String confirmLabel;
  final bool requireReason;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final TextEditingController _reasonCtrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    if (widget.requireReason && reason.isEmpty) {
      setState(() => _errorText = 'Alasan penolakan wajib diisi.');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              errorText: _errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
