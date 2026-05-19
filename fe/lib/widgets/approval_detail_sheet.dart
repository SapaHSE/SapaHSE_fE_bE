import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/inbox_item.dart';
import '../utils/approval_status_ui.dart';

class ApprovalDetailSheet extends StatefulWidget {
  final InboxItem item;
  final Future<bool> Function()? onApprove;
  final Future<bool> Function()? onReject;
  final VoidCallback? onDone;
  final bool showActionButtons;

  const ApprovalDetailSheet({
    super.key,
    required this.item,
    this.onApprove,
    this.onReject,
    this.onDone,
    this.showActionButtons = true,
  });

  @override
  State<ApprovalDetailSheet> createState() => _ApprovalDetailSheetState();
}

class _ApprovalDetailSheetState extends State<ApprovalDetailSheet> {
  bool _submitting = false;

  static const _blue = Color(0xFF1A56C4);
  static const _licenseColor = Color(0xFFEF6C00);
  static const _certColor = Color(0xFF6A1B9A);

  Color get _typeColor {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return _blue;
      case InboxItemType.approvalLicense:
        return _licenseColor;
      case InboxItemType.approvalCertification:
        return _certColor;
      default:
        return _blue;
    }
  }

  String get _typeLabel {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return 'REGISTRASI';
      case InboxItemType.approvalLicense:
        return 'LISENSI';
      case InboxItemType.approvalCertification:
        return 'SERTIFIKAT';
      default:
        return 'APPROVAL';
    }
  }

  IconData get _typeIcon {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return Icons.person_add_alt_1;
      case InboxItemType.approvalLicense:
        return Icons.badge_outlined;
      case InboxItemType.approvalCertification:
        return Icons.workspace_premium;
      default:
        return Icons.assignment_turned_in_outlined;
    }
  }

  bool get _isRegistration =>
      widget.item.itemType == InboxItemType.approvalRegistration;

  bool get _isLicense =>
      widget.item.itemType == InboxItemType.approvalLicense;

  ApprovalStatusStyle get _approvalStyle =>
      approvalStatusStyle(widget.item.approvalStatus);

  String _formatDate(DateTime dt) {
    final m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime dt) {
    final m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _displayValue(String? value) {
    final v = value?.trim();
    return (v != null && v.isNotEmpty) ? v : '-';
  }

  String _initials(String? name) {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return 'U';
    final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _runAction(Future<bool> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context);
      widget.onDone?.call();
    }
  }

  Future<void> _showAttachmentPreview(String imageUrl) async {
    await precacheImage(
      CachedNetworkImageProvider(imageUrl),
      context,
    );
    if (!mounted) return;

    final images = <String>[imageUrl];
    final previewController = PageController(initialPage: 0);
    final Map<int, TransformationController> controllers = {};
    final Map<int, VoidCallback> listeners = {};
    var doubleTapPosition = Offset.zero;
    const doubleTapZoomScale = 2.5;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          var currentIndex = 0;
          var isZoomed = false;
          return StatefulBuilder(
            builder: (context, setPreviewState) {
              TransformationController controllerFor(int i) {
                final existing = controllers[i];
                if (existing != null) return existing;
                final c = TransformationController();
                void listener() {
                  final scale = c.value.getMaxScaleOnAxis();
                  final zoomed = scale > 1.0;
                  if (zoomed != isZoomed) {
                    setPreviewState(() => isZoomed = zoomed);
                  }
                }

                c.addListener(listener);
                controllers[i] = c;
                listeners[i] = listener;
                return c;
              }

              void handleDoubleTap(int i) {
                final c = controllerFor(i);
                final currentScale = c.value.getMaxScaleOnAxis();
                if (currentScale > 1.0) {
                  c.value = Matrix4.identity();
                } else {
                  const s = doubleTapZoomScale;
                  final x = -doubleTapPosition.dx * (s - 1);
                  final y = -doubleTapPosition.dy * (s - 1);
                  c.value = Matrix4(
                    s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, x, y, 0, 1,
                  );
                }
              }

              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  iconTheme: const IconThemeData(color: Colors.white),
                  elevation: 0,
                  title: Text(
                    '${currentIndex + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                extendBodyBehindAppBar: true,
                body: PageView.builder(
                  controller: previewController,
                  physics: isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (idx) {
                    final old = currentIndex;
                    setPreviewState(() {
                      currentIndex = idx;
                      isZoomed = false;
                    });
                    controllers[old]?.value = Matrix4.identity();
                  },
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: GestureDetector(
                        onDoubleTapDown: (details) =>
                            doubleTapPosition = details.localPosition,
                        onDoubleTap: () => handleDoubleTap(index),
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          transformationController: controllerFor(index),
                          child: CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.contain,
                            placeholder: (_, __) =>
                                const CircularProgressIndicator(
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
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );

    for (final entry in controllers.entries) {
      final listener = listeners[entry.key];
      if (listener != null) {
        entry.value.removeListener(listener);
      }
      entry.value.dispose();
    }
    previewController.dispose();
  }

  Widget _buildHeroArea() {
    final iconColor = _typeColor;
    final fileUrl = (widget.item.itemFileUrl ?? '').trim();
    final submitterPhoto =
        (widget.item.submitterPhotoUrl ?? '').trim();

    Widget buildHeroFallback(String photo) {
      if (_isRegistration && photo.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: photo,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: _typeColor.withValues(alpha: 0.12),
            alignment: Alignment.center,
            child: Text(
              _initials(widget.item.submitterName),
              style: TextStyle(
                color: _typeColor,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: _typeColor.withValues(alpha: 0.12),
            alignment: Alignment.center,
            child: Text(
              _initials(widget.item.submitterName),
              style: TextStyle(
                color: _typeColor,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      } else if (_isRegistration) {
        return Container(
          color: _typeColor.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Text(
            _initials(widget.item.submitterName),
            style: TextStyle(
              color: _typeColor,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else {
        return Container(
          color: _typeColor.withValues(alpha: 0.08),
          alignment: Alignment.center,
          child: Icon(
            _typeIcon,
            color: iconColor.withValues(alpha: 0.6),
            size: 64,
          ),
        );
      }
    }

    final hasImage = fileUrl.isNotEmpty;

    Widget heroContent;
    if (hasImage) {
      heroContent = GestureDetector(
        onTap: () => _showAttachmentPreview(fileUrl),
        child: CachedNetworkImage(
          imageUrl: fileUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => buildHeroFallback(submitterPhoto),
          errorWidget: (_, __, ___) => buildHeroFallback(submitterPhoto),
        ),
      );
    } else {
      heroContent = buildHeroFallback(submitterPhoto);
    }

    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(fit: StackFit.expand, children: [
        heroContent,
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
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
        // Badges
        Positioned(
          bottom: 12,
          left: 16,
          child: Row(children: [
            _buildBadge(_approvalStyle.label, _approvalStyle.fg,
                bg: _approvalStyle.bg),
            const SizedBox(width: 8),
            _buildBadge(_typeLabel, _typeColor),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final submitDate = item.submittedAt ?? item.createdAt;
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF0F0F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  // Hero area
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: _buildHeroArea(),
                  ),

                  // ── Card: Informasi Pengajuan ───────────────────────────
                  _card(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_typeLabel,
                            style: TextStyle(
                                fontSize: 13,
                                color: _typeColor,
                                fontWeight: FontWeight.w500)),
                        const Divider(height: 24),
                        if (item.description != null &&
                            item.description!.isNotEmpty) ...[
                          _DetailRow(
                            icon: Icons.description_outlined,
                            label: 'Deskripsi',
                            value: item.description!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _DetailRow(
                          icon: Icons.access_time,
                          label: 'Tanggal Pengajuan',
                          value: _formatDate(submitDate),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.info_outline,
                          label: 'Status',
                          value: _approvalStyle.label,
                          valueColor: _approvalStyle.fg,
                        ),
                        if (item.rejectionReason != null &&
                            item.rejectionReason!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFFFCDD2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFC62828), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Alasan Penolakan',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Color(0xFFC62828))),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.rejectionReason!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFC62828)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Card: Informasi Pemohon ─────────────────────────────
                  _card(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                            icon: Icons.person_outline,
                            title: 'Informasi Pemohon'),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.person_outline,
                          label: 'Nama',
                          value: _displayValue(item.submitterName),
                        ),
                        if ((item.submitterPosition ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.work_outline,
                            label: 'Jabatan',
                            value: _displayValue(item.submitterPosition),
                          ),
                        ],
                        if ((item.submitterEmployeeId ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.badge_outlined,
                            label: 'Employee ID',
                            value: _displayValue(item.submitterEmployeeId),
                          ),
                        ],
                        if ((item.submitterEmail ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _displayValue(item.submitterEmail),
                          ),
                        ],
                        if ((item.submitterPhone ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.phone_outlined,
                            label: 'Telepon',
                            value: _displayValue(item.submitterPhone),
                          ),
                        ],
                        if ((item.submitterCompany ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.business_outlined,
                            label: 'Perusahaan',
                            value: _displayValue(item.submitterCompany),
                          ),
                        ],
                        if ((item.submitterDept ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.manage_accounts_outlined,
                            label: 'Departemen',
                            value: _displayValue(item.submitterDept),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Card: Detail Item (type-specific) ───────────────────
                  if (!_isRegistration)
                    _card(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                              icon: _typeIcon,
                              title:
                                  'Detail ${_isLicense ? 'Lisensi' : 'Sertifikat'}'),
                          const SizedBox(height: 12),
                          if ((item.itemName ?? '').trim().isNotEmpty) ...[
                            _DetailRow(
                              icon: Icons.label_outline,
                              label: 'Nama',
                              value: _displayValue(item.itemName),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_isLicense &&
                              (item.itemNumber ?? '').trim().isNotEmpty) ...[
                            _DetailRow(
                              icon: Icons.numbers,
                              label: 'Nomor Lisensi',
                              value: _displayValue(item.itemNumber),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!_isLicense &&
                              (item.itemIssuer ?? '').trim().isNotEmpty) ...[
                            _DetailRow(
                              icon: Icons.business,
                              label: 'Penerbit',
                              value: _displayValue(item.itemIssuer),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (item.itemObtainedAt != null) ...[
                            _DetailRow(
                              icon: Icons.event_outlined,
                              label: 'Tanggal Diperoleh',
                              value:
                                  _formatDateShort(item.itemObtainedAt!),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (item.itemExpiredAt != null) ...[
                            _DetailRow(
                              icon: Icons.event_busy_outlined,
                              label: 'Berlaku Sampai',
                              value:
                                  _formatDateShort(item.itemExpiredAt!),
                              valueColor: item.itemExpiredAt!.isBefore(
                                      DateTime.now())
                                  ? const Color(0xFFF44336)
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Action buttons ─────────────────────────────────────────────
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  border:
                      Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: widget.showActionButtons &&
                        widget.onApprove != null &&
                        widget.onReject != null
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _submitting
                                  ? null
                                  : () => _runAction(widget.onReject!),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFC62828),
                                backgroundColor: const Color(0xFFC62828)
                                    .withValues(alpha: 0.08),
                                side: BorderSide(
                                  color: const Color(0xFFC62828)
                                      .withValues(alpha: 0.42),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Tolak',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submitting
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          title: const Text('Setujui Pengajuan',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          content: const Text(
                                              'Apakah Anda yakin ingin menyetujui pengajuan dokumen ini?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Batal'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF2F80ED),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text('Setujui'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        _runAction(widget.onApprove!);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2F80ED),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('Setujui',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56C4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Tutup'),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helper widgets ─────────────────────────────────────────────────
  Widget _card({required Widget child, required EdgeInsets margin}) =>
      Container(
        margin: margin,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );

  Widget _buildBadge(String label, Color color, {Color? bg}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg ?? color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: bg != null ? color : Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
      );
}

// ── Supporting widgets matching ReportDetailScreen design ────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF1A56C4), size: 20),
      const SizedBox(width: 8),
      Text(title,
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
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
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? Colors.black87,
                    fontWeight:
                        valueColor != null ? FontWeight.w600 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
