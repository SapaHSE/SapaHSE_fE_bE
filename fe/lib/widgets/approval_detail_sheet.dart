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

  bool get _isLicense => widget.item.itemType == InboxItemType.approvalLicense;

  ApprovalStatusStyle get _approvalStyle =>
      approvalStatusStyle(widget.item.approvalStatus);

  String _formatDate(DateTime dt) {
    final m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime dt) {
    final m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
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
                    s,
                    0,
                    0,
                    0,
                    0,
                    s,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                    x,
                    y,
                    0,
                    1,
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
    final submitterPhoto = (widget.item.submitterPhotoUrl ?? '').trim();

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
    final displayTitle = item.title.toLowerCase().startsWith('pengajuan')
        ? item.title
        : 'Pengajuan ${item.title}';
    final submitDate = item.submittedAt ?? item.createdAt;
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;
    final status = _approvalStyle;
    final isCertification =
        item.itemType == InboxItemType.approvalCertification;
    final hasDocumentDetails = _isLicense || isCertification;
    final attachmentUrl = (item.itemFileUrl ?? '').trim();
    final attachmentTitle = _isRegistration
        ? 'Foto profil'
        : _isLicense
            ? 'Lampiran lisensi'
            : 'Lampiran sertifikat';

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
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: _buildHeroArea(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _card(
                          margin: EdgeInsets.zero,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: _typeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _typeIcon,
                                  color: _typeColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _buildBadge(
                                          status.label,
                                          status.fg,
                                          bg: status.bg,
                                        ),
                                        _buildBadge(_typeLabel, _typeColor),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      displayTitle,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                    if ((item.description ?? '')
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        item.description!.trim(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(
                                icon: Icons.person_outline,
                                title: 'Data Pemohon',
                              ),
                              const SizedBox(height: 14),
                              _DetailRow(
                                icon: Icons.badge_outlined,
                                label: 'Pemohon',
                                value: _displayValue(item.submitterName),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.apartment_outlined,
                                label: 'Departemen',
                                value: _displayValue(item.submitterDept),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.business_outlined,
                                label: 'Perusahaan',
                                value: _displayValue(item.submitterCompany),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: _displayValue(item.submitterEmail),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.confirmation_number_outlined,
                                label: 'NIP',
                                value: _displayValue(item.submitterEmployeeId),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.work_outline,
                                label: 'Jabatan',
                                value: _displayValue(item.submitterPosition),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.phone_outlined,
                                label: 'Telepon',
                                value: _displayValue(item.submitterPhone),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(
                                icon: Icons.assignment_outlined,
                                title: 'Detail Pengajuan',
                              ),
                              const SizedBox(height: 14),
                              _DetailRow(
                                icon: Icons.category_outlined,
                                label: 'Jenis',
                                value: _typeLabel,
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Tanggal Pengajuan',
                                value: _formatDate(submitDate),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.verified_outlined,
                                label: 'Status',
                                value: status.label,
                                valueColor: status.fg,
                              ),
                              if (hasDocumentDetails) ...[
                                const SizedBox(height: 12),
                                _DetailRow(
                                  icon: _isLicense
                                      ? Icons.badge_outlined
                                      : Icons.workspace_premium_outlined,
                                  label: _isLicense
                                      ? 'Nama Lisensi'
                                      : 'Nama Sertifikat',
                                  value: _displayValue(item.itemName),
                                ),
                                if (_isLicense || isCertification) ...[
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                    icon: Icons.pin_outlined,
                                    label: _isLicense
                                        ? 'Nomor Lisensi'
                                        : 'Nomor Sertifikat',
                                    value: _displayValue(item.itemNumber),
                                  ),
                                ],
                                if (_isLicense || isCertification) ...[
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                    icon: Icons.account_balance_outlined,
                                    label: 'Lembaga Penerbit',
                                    value: _displayValue(item.itemIssuer),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _DetailRow(
                                  icon: Icons.event_available_outlined,
                                  label: 'Tanggal Terbit',
                                  value: item.itemObtainedAt != null
                                      ? _formatDateShort(item.itemObtainedAt!)
                                      : '-',
                                ),
                                const SizedBox(height: 12),
                                _DetailRow(
                                  icon: Icons.event_busy_outlined,
                                  label: 'Tanggal Kadaluarsa',
                                  value: item.itemExpiredAt != null
                                      ? _formatDateShort(item.itemExpiredAt!)
                                      : '-',
                                ),
                              ],
                            ],
                          ),
                        ),
                        if ((item.rejectionReason ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _card(
                            margin: EdgeInsets.zero,
                            child: _DetailRow(
                              icon: Icons.info_outline,
                              label: 'Alasan Ditolak',
                              value: item.rejectionReason!.trim(),
                              valueColor: const Color(0xFFC62828),
                            ),
                          ),
                        ],
                        if (attachmentUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _showAttachmentPreview(attachmentUrl),
                            borderRadius: BorderRadius.circular(14),
                            child: _card(
                              margin: EdgeInsets.zero,
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: _typeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: _typeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          attachmentTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tersedia',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                                                  fontWeight: FontWeight.bold)),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                    fontWeight: valueColor != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
