import 'package:flutter/material.dart';

class DraftActionFab extends StatelessWidget {
  final bool isProcessing;
  final Future<void> Function() onSend;
  final Future<void> Function() onDelete;
  final String heroTag;
  final Color color;

  const DraftActionFab({
    super.key,
    required this.isProcessing,
    required this.onSend,
    required this.onDelete,
    this.heroTag = 'draft_action_fab',
    this.color = const Color(0xFF1A56C4),
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      backgroundColor: color,
      foregroundColor: Colors.white,
      onPressed: isProcessing
          ? null
          : () => _showActions(context),
      child: isProcessing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.more_horiz),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Aksi Draft',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.send_rounded, color: Color(0xFF1A56C4)),
                title: const Text('Kirim Draft'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onSend();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                title: const Text('Hapus Draft'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onDelete();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
