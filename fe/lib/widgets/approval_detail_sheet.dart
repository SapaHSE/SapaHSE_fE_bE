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

  static const _regColor = Color(0xFF1A56C4);
  static const _licenseColor = Color(0xFFEF6C00);
  static const _certColor = Color(0xFF6A1B9A);

  Color get _accent {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return _regColor;
      case InboxItemType.approvalLicense:
        return _licenseColor;
      case InboxItemType.approvalCertification:
        return _certColor;
      default:
        return _regColor;
    }
  }

  IconData get _icon {
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

  String get _category {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return 'REGISTRASI USER';
      case InboxItemType.approvalLicense:
        return 'INPUT LISENSI';
      case InboxItemType.approvalCertification:
        return 'INPUT SERTIFIKAT';
      default:
        return 'PENGAJUAN';
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year;
    return '$dd/$mm/$yyyy';
  }

  ApprovalStatusStyle _statusStyle(String? rawStatus) =>
      approvalStatusStyle(rawStatus);

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

  Widget _row(String label, String? value) {
    final text = (value == null || value.trim().isEmpty) ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final submitDate = item.submittedAt ?? item.createdAt;
    final status = _statusStyle(item.approvalStatus);
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
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
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon, color: _accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _category,
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: status.bg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: status.border),
                              ),
                              child: Text(
                                status.label,
                                style: TextStyle(
                                  color: status.fg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((item.description ?? '').trim().isNotEmpty)
                    Text(
                      item.description!,
                      style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                    ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  _row('Pemohon', item.submitterName),
                  _row('Departemen', item.submitterDept),
                  _row('Perusahaan', item.submitterCompany),
                  _row('Tanggal Pengajuan', _fmtDate(submitDate)),
                  _row('Status', status.label),
                  _row('Email', item.submitterEmail),
                  _row('NIP', item.submitterEmployeeId),
                  _row('Jabatan', item.submitterPosition),
                  _row('Telepon', item.submitterPhone),
                  if ((item.rejectionReason ?? '').trim().isNotEmpty)
                    _row('Alasan Ditolak', item.rejectionReason),
                  if (item.itemType == InboxItemType.approvalLicense) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 10),
                    _row('Nama Lisensi', item.itemName),
                    _row('Nomor Lisensi', item.itemNumber),
                    _row('Tgl Terbit', _fmtDate(item.itemObtainedAt)),
                    _row('Tgl Kadaluarsa', _fmtDate(item.itemExpiredAt)),
                  ],
                  if (item.itemType == InboxItemType.approvalCertification) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 10),
                    _row('Nama Sertifikat', item.itemName),
                    _row('Penerbit', item.itemIssuer),
                    _row('Tgl Terbit', _fmtDate(item.itemObtainedAt)),
                    _row('Tgl Kadaluarsa', _fmtDate(item.itemExpiredAt)),
                  ],
                  if ((item.itemFileUrl ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Lampiran Dokumen',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ketuk gambar untuk preview',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showAttachmentPreview(item.itemFileUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: item.itemFileUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 180,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 120,
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const Text(
                              'Preview tidak tersedia',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                                backgroundColor:
                                    const Color(0xFFC62828).withValues(alpha: 0.08),
                                side: BorderSide(
                                  color: const Color(0xFFC62828).withValues(
                                    alpha: 0.42,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Tolak',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submitting
                                  ? null
                                  : () => _runAction(widget.onApprove!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2F80ED),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Setujui',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
}
