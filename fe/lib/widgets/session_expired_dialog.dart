import 'package:flutter/material.dart';

import '../app_globals.dart';
import '../screens/login_screen.dart';

enum SessionEndReason {
  idleTimeout,
  tokenExpired,
  notLoggedIn,
}

bool _isShowing = false;

Future<void> showSessionExpiredDialog({
  SessionEndReason reason = SessionEndReason.tokenExpired,
  String? message,
}) async {
  if (_isShowing) return;
  final ctx = navigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;

  _isShowing = true;

  String title;
  String content;
  IconData icon;

  if (message != null) {
    title = 'Sesi Berakhir';
    content = message;
    icon = Icons.lock_clock;
  } else {
    switch (reason) {
      case SessionEndReason.idleTimeout:
        title = 'Tidak Ada Aktivitas';
        content =
            'Sesi kamu telah berakhir karena tidak ada aktivitas. Silakan login kembali untuk melanjutkan.';
        icon = Icons.timer_off;
      case SessionEndReason.tokenExpired:
        title = 'Sesi Berakhir';
        content =
            'Sesi kamu telah berakhir. Silakan login kembali untuk melanjutkan.';
        icon = Icons.lock_clock;
      case SessionEndReason.notLoggedIn:
        title = 'Belum Login';
        content = 'Kamu belum login. Silakan login untuk melanjutkan.';
        icon = Icons.person_off;
    }
  }

  await showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A56C4)),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(content),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Login Kembali'),
        ),
      ],
    ),
  );
  _isShowing = false;
}
