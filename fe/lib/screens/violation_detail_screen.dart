import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/profile_model.dart';

class ViolationDetailScreen extends StatelessWidget {
  final UserViolation violation;

  const ViolationDetailScreen({
    super.key,
    required this.violation,
  });

  static const _danger = Color(0xFFD32F2F);

  bool get _isActive => violation.status.toLowerCase() == 'aktif';

  String _displayValue(String? value) {
    final v = value?.trim();
    return (v != null && v.isNotEmpty) ? v : '-';
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
  }

  String _formatDate(DateTime dt, {bool withTime = true}) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    if (!withTime) {
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateText(String? raw, {bool withTime = false}) {
    final dt = _parseDate(raw);
    if (dt == null) return _displayValue(raw);
    return _formatDate(dt, withTime: withTime);
  }

  Future<void> _showImagePreview(BuildContext context, String imageUrl) async {
    await precacheImage(CachedNetworkImageProvider(imageUrl), context);
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
                  imageUrl: imageUrl,
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

  Widget _buildHeroArea(BuildContext context) {
    final fileUrl = (violation.fileUrl ?? '').trim();
    final hasImage = fileUrl.isNotEmpty;

    Widget fallback = Container(
      color: _danger.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.warning_amber_rounded,
        color: _danger.withValues(alpha: 0.65),
        size: 68,
      ),
    );

    return SizedBox(
      width: double.infinity,
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            GestureDetector(
              onTap: () => _showImagePreview(context, fileUrl),
              child: CachedNetworkImage(
                imageUrl: fileUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
            )
          else
            fallback,
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
          Positioned(
            bottom: 12,
            left: 16,
            child: IgnorePointer(
              child: Row(
                children: [
                  _badge(
                    violation.status,
                    _isActive ? _danger : const Color(0xFF616161),
                    bg: _isActive
                        ? const Color(0xFFFFEBEE)
                        : const Color(0xFFF5F5F5),
                  ),
                  const SizedBox(width: 8),
                  _badge('PELANGGARAN', _danger),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiry = _parseDate(violation.expiredAt);
    final expired = expiry != null && expiry.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Pelanggaran',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroArea(context),
            _card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: _danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              violation.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'PELANGGARAN',
                              style: TextStyle(
                                fontSize: 13,
                                color: _danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.description_outlined,
                    label: 'Deskripsi',
                    value: _displayValue(violation.description),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Lokasi',
                    value: _displayValue(violation.location),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.event_outlined,
                    label: 'Tanggal Pelanggaran',
                    value: _formatDateText(violation.dateOfViolation),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.event_busy_outlined,
                    label: 'Berlaku Sampai',
                    value: _formatDateText(violation.expiredAt),
                    valueColor: expired ? _danger : null,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.info_outline,
                    label: 'Status',
                    value: violation.status,
                    valueColor: _isActive ? _danger : const Color(0xFF616161),
                  ),
                ],
              ),
            ),
            if ((violation.sanction ?? '').trim().isNotEmpty)
              _card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      icon: Icons.gavel_rounded,
                      title: 'Sanksi',
                      iconColor: _danger,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: _danger,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              violation.sanction!.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFB71C1C),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, required EdgeInsets margin}) {
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

  Widget _badge(String label, Color color, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bg != null ? color : Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.iconColor = const Color(0xFF1A56C4),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? Colors.black87,
                  fontWeight:
                      valueColor != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
