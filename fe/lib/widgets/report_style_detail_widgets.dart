import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ReportStyleDetailBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;

  const ReportStyleDetailBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: backgroundColor == null ? Colors.white : color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Future<void> showSingleImagePreview(BuildContext context, String imageUrl) async {
  final url = imageUrl.trim();
  if (url.isEmpty) return;

  final provider = CachedNetworkImageProvider(url);
  try {
    await precacheImage(provider, context);
  } catch (_) {
    // Keep preview behavior consistent even when pre-cache fails.
  }
  if (!context.mounted) return;

  final controller = TransformationController();
  var doubleTapPosition = Offset.zero;
  const doubleTapZoomScale = 2.5;

  void handleDoubleTap() {
    final currentScale = controller.value.getMaxScaleOnAxis();
    if (currentScale > 1.0) {
      controller.value = Matrix4.identity();
      return;
    }

    const scale = doubleTapZoomScale;
    controller.value = Matrix4(
      scale,
      0,
      0,
      0,
      0,
      scale,
      0,
      0,
      0,
      0,
      1,
      0,
      -doubleTapPosition.dx * (scale - 1),
      -doubleTapPosition.dy * (scale - 1),
      0,
      1,
    );
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          title: const Text(
            '1/1',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Center(
          child: GestureDetector(
            onDoubleTapDown: (details) =>
                doubleTapPosition = details.localPosition,
            onDoubleTap: handleDoubleTap,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              transformationController: controller,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(
                  color: Colors.white,
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.image,
                  color: Colors.white54,
                  size: 80,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  controller.dispose();
}

class ReportStyleDetailHero extends StatelessWidget {
  final String imageUrl;
  final Color accentColor;
  final IconData fallbackIcon;
  final List<Widget> badges;
  final double height;
  final Widget? fallback;

  const ReportStyleDetailHero({
    super.key,
    required this.imageUrl,
    required this.accentColor,
    required this.fallbackIcon,
    required this.badges,
    this.height = 220,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final fileUrl = imageUrl.trim();
    final hasImage = fileUrl.isNotEmpty;

    Widget buildFallback() =>
        fallback ??
        Container(
          color: accentColor.withValues(alpha: 0.08),
          alignment: Alignment.center,
          child: Icon(
            fallbackIcon,
            color: accentColor.withValues(alpha: 0.7),
            size: 68,
          ),
        );

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            GestureDetector(
              onTap: () => showSingleImagePreview(context, fileUrl),
              child: CachedNetworkImage(
                imageUrl: fileUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => buildFallback(),
                errorWidget: (_, __, ___) => buildFallback(),
              ),
            )
          else
            buildFallback(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (badges.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: IgnorePointer(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: badges,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ReportStyleDetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;

  const ReportStyleDetailCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ReportStyleSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const ReportStyleSectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1A56C4)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A56C4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF1A56C4).withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

class ReportStyleDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const ReportStyleDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF1A56C4).withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    return content;
  }
}
