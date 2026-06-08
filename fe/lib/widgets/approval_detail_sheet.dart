import 'package:flutter/material.dart';

import '../models/inbox_item.dart';
import '../utils/approval_status_ui.dart';
import 'report_style_detail_widgets.dart';

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
  final ScrollController _scrollController = ScrollController();
  double _dragDistance = 0;
  bool _isDraggingDown = false;
  bool _canCloseThisDrag = false;
  static const double _closeThreshold = 30.0;
  static const double _topEpsilon = 0.5;

  static const _blue = Color(0xFF1A56C4);
  static const _licenseColor = Color(0xFFEF6C00);
  static const _certColor = Color(0xFF6A1B9A);
  static const _profileColor = Color(0xFF00897B);

  Color get _typeColor {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return _blue;
      case InboxItemType.approvalLicense:
        return _licenseColor;
      case InboxItemType.approvalCertification:
        return _certColor;
      case InboxItemType.approvalProfileChange:
        return _profileColor;
      default:
        return _blue;
    }
  }

  String get _typeLabel {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return 'Registrasi';
      case InboxItemType.approvalLicense:
        return 'Lisensi';
      case InboxItemType.approvalCertification:
        return 'Sertifikat';
      case InboxItemType.approvalProfileChange:
        return 'Profil';
      default:
        return 'Approval';
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
      case InboxItemType.approvalProfileChange:
        return Icons.edit_note;
      default:
        return Icons.assignment_turned_in_outlined;
    }
  }

  bool get _isRegistration =>
      widget.item.itemType == InboxItemType.approvalRegistration;

  bool get _isLicense => widget.item.itemType == InboxItemType.approvalLicense;

  bool get _isProfileChange =>
      widget.item.itemType == InboxItemType.approvalProfileChange;

  ApprovalStatusStyle get _approvalStyle =>
      approvalStatusStyle(widget.item.approvalStatus);

  bool get _isPending {
    final status = normalizeApprovalStatus(widget.item.approvalStatus);
    return status == 'pending' ||
        status == 'pending_hrd' ||
        status == 'pending_admin';
  }

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

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      final atTop = notification.metrics.extentBefore <= _topEpsilon;
      final isUserDrag = notification.dragDetails != null;
      _canCloseThisDrag = atTop && isUserDrag;
      _isDraggingDown = false;
      _dragDistance = 0;
    } else if (notification is ScrollUpdateNotification) {
      if (!_canCloseThisDrag || notification.dragDetails == null) return false;

      final atTop = notification.metrics.extentBefore <= _topEpsilon;
      final delta = notification.dragDetails?.delta.dy ?? 0;

      if (atTop && delta > 0) {
        _isDraggingDown = true;
        _dragDistance += delta;
        setState(() {});
      } else if (_isDraggingDown && (!atTop || delta < 0)) {
        _isDraggingDown = false;
        if (_dragDistance != 0) {
          _dragDistance = 0;
          setState(() {});
        }
      }
    } else if (notification is OverscrollNotification) {
      if (!_canCloseThisDrag || notification.dragDetails == null) return false;

      final atTop = notification.metrics.extentBefore <= _topEpsilon;
      if (!atTop) return false;

      final pullDelta = notification.dragDetails?.delta.dy ?? 0;
      if (pullDelta > 0) {
        _isDraggingDown = true;
        _dragDistance += pullDelta;
        setState(() {});
      } else if (_isDraggingDown && pullDelta < 0) {
        _isDraggingDown = false;
        if (_dragDistance != 0) {
          _dragDistance = 0;
          setState(() {});
        }
      }
    } else if (notification is ScrollEndNotification) {
      final shouldClose = _canCloseThisDrag && _dragDistance > _closeThreshold;
      if (shouldClose) {
        Navigator.pop(context);
        return false;
      }

      final shouldResetUi = _dragDistance != 0;
      _dragDistance = 0;
      _isDraggingDown = false;
      _canCloseThisDrag = false;
      if (shouldResetUi) {
        setState(() {});
      }
    }
    return false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  Widget _buildProfileChangesSection(InboxItem item) {
    final changes = item.profileChanges;
    if (changes.isEmpty) {
      return const SizedBox(height: 12);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.compare_arrows, size: 16, color: _profileColor),
            const SizedBox(width: 8),
            Text(
              'Detail Perubahan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _profileColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...changes.map((change) => _buildChangeRow(change)),
      ],
    );
  }

  Widget _buildChangeRow(ProfileChangeItem change) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            change.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sebelum',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      change.oldValue.isEmpty ? '-' : change.oldValue,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.red.shade300,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward,
                    size: 14, color: Colors.grey.shade400),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sesudah',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      change.newValue.isEmpty ? '-' : change.newValue,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroArea() {
    final fileUrl = (widget.item.itemFileUrl ?? '').trim();
    final submitterPhoto = (widget.item.submitterPhotoUrl ?? '').trim();
    final heroImageUrl =
        fileUrl.isNotEmpty ? fileUrl : (_isRegistration ? submitterPhoto : '');

    final registrationFallback = _isRegistration
        ? Container(
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
          )
        : null;

    return ReportStyleDetailHero(
      imageUrl: heroImageUrl,
      accentColor: _typeColor,
      fallbackIcon: _typeIcon,
      height: 200,
      fallback: registrationFallback,
      badges: [
        ReportStyleDetailBadge(
          label: _approvalStyle.label,
          color: _approvalStyle.fg,
        ),
        ReportStyleDetailBadge(label: _typeLabel, color: _typeColor),
      ],
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
    final isProfileChange = _isProfileChange;
    final submitterRole = [
      (item.submitterPosition ?? '').trim(),
      (item.submitterDept ?? '').trim(),
    ].where((v) => v.isNotEmpty).join(' • ');
    final sheetOffsetY = _dragDistance.clamp(0.0, sheetHeight * 0.35);

    return SizedBox(
      height: sheetHeight,
      child: Transform.translate(
        offset: Offset(0, sheetOffsetY),
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
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: ListView(
                    controller: _scrollController,
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
                            ReportStyleDetailCard(
                              margin: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayTitle,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _typeLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _typeColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Divider(height: 24),
                                  if ((item.description ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    ReportStyleDetailRow(
                                      icon: Icons.description_outlined,
                                      label: 'Deskripsi',
                                      value: item.description!.trim(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  ReportStyleDetailRow(
                                    icon: Icons.access_time,
                                    label: 'Tanggal Pengajuan',
                                    value: _formatDate(submitDate),
                                  ),
                                  const SizedBox(height: 12),
                                  ReportStyleDetailRow(
                                    icon: Icons.info_outline,
                                    label: 'Status',
                                    value: status.label,
                                    valueColor: status.fg,
                                  ),
                                  if ((item.rejectionReason ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEBEE),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFFFCDD2),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Color(0xFFC62828),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Alasan Penolakan',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Color(0xFFC62828),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.rejectionReason!.trim(),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFFC62828),
                                                  ),
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
                            const SizedBox(height: 12),
                            ReportStyleDetailCard(
                              margin: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ReportStyleSectionHeader(
                                    icon: Icons.person_outline,
                                    title: 'Informasi Pemohon',
                                  ),
                                  const SizedBox(height: 12),
                                  ReportStyleDetailRow(
                                    icon: Icons.person_outline,
                                    label: 'Pemohon',
                                    value: _displayValue(item.submitterName),
                                  ),
                                  if (submitterRole.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.work_outline,
                                      label: 'Jabatan / Departemen',
                                      value: submitterRole,
                                    ),
                                  ],
                                  if ((item.submitterEmployeeId ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.badge_outlined,
                                      label: 'NIP',
                                      value: _displayValue(
                                          item.submitterEmployeeId),
                                    ),
                                  ],
                                  if ((item.submitterEmail ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.email_outlined,
                                      label: 'Email',
                                      value: _displayValue(item.submitterEmail),
                                    ),
                                  ],
                                  if ((item.submitterPhone ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.phone_outlined,
                                      label: 'Telepon',
                                      value: _displayValue(item.submitterPhone),
                                    ),
                                  ],
                                  if ((item.submitterCompany ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.business_outlined,
                                      label: 'Perusahaan',
                                      value:
                                          _displayValue(item.submitterCompany),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!_isPending &&
                                (item.reviewerName ?? '').trim().isNotEmpty)
                              ReportStyleDetailCard(
                                margin: EdgeInsets.zero,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const ReportStyleSectionHeader(
                                      icon: Icons.verified_user_outlined,
                                      title: 'Informasi Reviewer',
                                    ),
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.person_outline,
                                      label: 'Nama Reviewer',
                                      value: _displayValue(item.reviewerName),
                                    ),
                                    if ((item.reviewerEmployeeId ?? '')
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ReportStyleDetailRow(
                                        icon: Icons.badge_outlined,
                                        label: 'NIP Reviewer',
                                        value: _displayValue(
                                            item.reviewerEmployeeId),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            ReportStyleDetailCard(
                              margin: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ReportStyleSectionHeader(
                                    icon: Icons.assignment_outlined,
                                    title: 'Detail Pengajuan',
                                  ),
                                  const SizedBox(height: 12),
                                  ReportStyleDetailRow(
                                    icon: Icons.category_outlined,
                                    label: 'Jenis',
                                    value: _typeLabel,
                                  ),
                                  const SizedBox(height: 12),
                                  ReportStyleDetailRow(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'Tanggal Pengajuan',
                                    value: _formatDate(submitDate),
                                  ),
                                  const SizedBox(height: 12),
                                  ReportStyleDetailRow(
                                    icon: Icons.verified_outlined,
                                    label: 'Status',
                                    value: status.label,
                                    valueColor: status.fg,
                                  ),
                                  if (hasDocumentDetails) ...[
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: _isLicense
                                          ? Icons.badge_outlined
                                          : Icons.workspace_premium_outlined,
                                      label: _isLicense
                                          ? 'Nama Lisensi'
                                          : 'Nama Sertifikat',
                                      value: _displayValue(item.itemName),
                                    ),
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.pin_outlined,
                                      label: _isLicense
                                          ? 'Nomor Lisensi'
                                          : 'Nomor Sertifikat',
                                      value: _displayValue(item.itemNumber),
                                    ),
                                    if (_isLicense &&
                                        (item.itemVehicleEquipment ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ReportStyleDetailRow(
                                        icon: Icons.local_shipping_outlined,
                                        label: 'Vehicle Equipment',
                                        value: _displayValue(
                                            item.itemVehicleEquipment),
                                      ),
                                    ],
                                    if (_isLicense &&
                                        (item.itemSimIndonesiaType ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ReportStyleDetailRow(
                                        icon: Icons.credit_card_outlined,
                                        label: 'SIM Indonesia',
                                        value: _displayValue(
                                            item.itemSimIndonesiaType),
                                      ),
                                    ],
                                    if (_isLicense &&
                                        (item.itemSimType ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ReportStyleDetailRow(
                                        icon: Icons.verified_user_outlined,
                                        label: 'SIM Type (LIC)',
                                        value: _displayValue(item.itemSimType),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.account_balance_outlined,
                                      label: 'Lembaga Penerbit',
                                      value: _displayValue(item.itemIssuer),
                                    ),
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.event_available_outlined,
                                      label: 'Tanggal Terbit',
                                      value: item.itemObtainedAt != null
                                          ? _formatDateShort(
                                              item.itemObtainedAt!)
                                          : '-',
                                    ),
                                    const SizedBox(height: 12),
                                    ReportStyleDetailRow(
                                      icon: Icons.event_busy_outlined,
                                      label: 'Tanggal Kadaluarsa',
                                      value: item.itemExpiredAt != null
                                          ? _formatDateShort(
                                              item.itemExpiredAt!)
                                          : '-',
                                    ),
                                  ],
                                  if (isProfileChange)
                                    _buildProfileChangesSection(item),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                                            title: Text(
                                                _isRegistration
                                                    ? 'Setujui Pendaftaran'
                                                    : 'Setujui Pengajuan',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            content: Text(_isRegistration
                                                ? 'Apakah Anda yakin ingin menyetujui pendaftaran akun ini?'
                                                : 'Apakah Anda yakin ingin menyetujui pengajuan dokumen ini?'),
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
                                                        BorderRadius.circular(
                                                            8),
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
      ),
    );
  }
}
