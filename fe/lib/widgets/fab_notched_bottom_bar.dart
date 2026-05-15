import 'package:flutter/material.dart';

class FabNotchedBottomBar extends StatelessWidget {
  static const double defaultHeight = 60;
  static const double defaultNotchRadius = 34;

  final Widget child;
  final double height;
  final double notchRadius;
  final double elevation;
  final Color color;
  final Color shadowColor;

  const FabNotchedBottomBar({
    super.key,
    required this.child,
    this.height = defaultHeight,
    this.notchRadius = defaultNotchRadius,
    this.elevation = 8,
    this.color = Colors.white,
    this.shadowColor = Colors.black26,
  });

  static double bottomInset(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom;
  }

  static double effectiveHeight(
    BuildContext context, {
    double height = defaultHeight,
  }) {
    return height + bottomInset(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = FabNotchedBottomBar.bottomInset(context);
    return SizedBox(
      height: height + bottomInset,
      child: PhysicalShape(
        clipper: _FabNotchClipper(radius: notchRadius),
        color: color,
        elevation: elevation,
        shadowColor: shadowColor,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(height: height, child: child),
        ),
      ),
    );
  }
}

class _FabNotchClipper extends CustomClipper<Path> {
  final double radius;
  const _FabNotchClipper({required this.radius});

  @override
  Path getClip(Size size) {
    final bar = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final notch = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(size.width / 2, 0), radius: radius),
      );
    return Path.combine(PathOperation.difference, bar, notch);
  }

  @override
  bool shouldReclip(covariant _FabNotchClipper oldClipper) =>
      oldClipper.radius != radius;
}
