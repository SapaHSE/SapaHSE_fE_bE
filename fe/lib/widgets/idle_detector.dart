import 'package:flutter/material.dart';

import '../services/idle_timeout_service.dart';

class IdleDetector extends StatelessWidget {
  final Widget child;
  const IdleDetector({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => IdleTimeoutService.instance.recordActivity(),
      child: child,
    );
  }
}
