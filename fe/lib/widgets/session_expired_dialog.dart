import 'package:flutter/material.dart';

import '../app_globals.dart';
import '../screens/login_screen.dart';

bool _isShowing = false;

Future<void> showSessionExpiredDialog() async {
  if (_isShowing) return;
  final ctx = navigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;

  _isShowing = true;
  await showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_clock, color: Color(0xFF1A56C4)),
          SizedBox(width: 8),
          Text('Sesi Berakhir'),
        ],
      ),
      content: const Text(
        'Sesi kamu telah habis. Silakan login kembali untuk melanjutkan.',
      ),
      actions: [
        FilledButton(
          onPressed: () {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1A56C4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Login Kembali'),
        ),
      ],
    ),
  );
  _isShowing = false;
}
