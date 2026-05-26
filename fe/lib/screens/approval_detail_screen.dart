import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/inbox_item.dart';
import '../utils/approval_status_ui.dart';
import '../main.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/fab_notched_bottom_bar.dart';

/// Full-screen detail page for approval items (registration, license, certification).
/// Designed to match the visual language of [ReportDetailScreen].
class ApprovalDetailScreen extends StatefulWidget {
  final InboxItem item;
  final bool showActionButtons;
  final Future<bool> Function()? onApprove;
  final Future<bool> Function()? onReject;
  final VoidCallback? onDone;

  const ApprovalDetailScreen({
    super.key,
    required this.item,
    this.showActionButtons = false,
    this.onApprove,
    this.onReject,
    this.onDone,
  });

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  static const _blue = Color(0xFF1A56C4);

  bool _isProcessing = false;

  // ── Colors / helpers ─────────────────────────────────────────────────────
  Color get _typeColor {
    switch (widget.item.itemType) {
      case InboxItemType.approvalRegistration:
        return _blue;
      case InboxItemType.approvalLicense:
        return const Color(0xFFEF6C00);
      case InboxItemType.approvalCertification:
        return const Color(0xFF6A1B9A);
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
        return Icons.person_add_outlined;
      case InboxItemType.approvalLicense:
        return Icons.badge_outlined;
      case InboxItemType.approvalCertification:
        return Icons.workspace_premium_outlined;
      default:
        return Icons.verified_outlined;
    }
  }

  ApprovalStatusStyle get _approvalStyle =>
      approvalStatusStyle(widget.item.approvalStatus);

  bool get _isPending => normalizeApprovalStatus(widget.item.approvalStatus) == 'pending';

  String _formatDate(DateTime dt) {
    final m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime dt) {
    final m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
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

  bool get _isRegistration =>
      widget.item.itemType == InboxItemType.approvalRegistration;

  bool get _isLicense =>
      widget.item.itemType == InboxItemType.approvalLicense;

  Widget _buildHeroFallback() {
    final iconColor = _typeColor;
    final iconSize = 64.0;
    final fontSize = 40.0;

    if (_isRegistration) {
      return Container(
        color: _typeColor.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Text(
          _initials(widget.item.submitterName),
          style: TextStyle(
            color: _typeColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Container(
      color: _typeColor.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(_typeIcon, color: iconColor.withValues(alpha: 0.6), size: iconSize),
    );
  }

  // ── Bottom nav ───────────────────────────────────────────────────────────
  void _onTabTapped(int index) {
    Navigator.pushReplacement(
      context,
      _FadePageRoute(builder: (_) => MainScreen(initialIndex: index)),
    );
  }

  // ── Handlers ─────────────────────────────────────────────────────────────
  Future<void> _handleApprove() async {
    if (_isProcessing || widget.onApprove == null) return;
    setState(() => _isProcessing = true);
    try {
      final ok = await widget.onApprove!();
      if (ok && mounted) {
        widget.onDone?.call();
        if (Navigator.canPop(context)) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    if (_isProcessing || widget.onReject == null) return;
    setState(() => _isProcessing = true);
    try {
      final ok = await widget.onReject!();
      if (ok && mounted) {
        widget.onDone?.call();
        if (Navigator.canPop(context)) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedAt = widget.item.submittedAt ?? widget.item.createdAt;
    final approvalStatus = _approvalStyle;
    final showActions = widget.showActionButtons &&
        _isPending &&
        widget.onApprove != null &&
        widget.onReject != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detail Pengajuan',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: widget.onDone,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(fit: StackFit.expand, children: [
                _buildHeroFallback(),
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
                    _badge(approvalStatus.label, approvalStatus.fg),
                    const SizedBox(width: 8),
                    _badge(_typeLabel, _typeColor),
                  ]),
                ),
              ]),
            ),

            // ── Card: Informasi Pengajuan ──────────────────────────────────
            _card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeLabel,
                    style: TextStyle(
                        fontSize: 13,
                        color: _typeColor,
                        fontWeight: FontWeight.w500),
                  ),
                  const Divider(height: 24),
                  if (widget.item.description != null &&
                      widget.item.description!.isNotEmpty) ...[
                    _DetailRow(
                      icon: Icons.description_outlined,
                      label: 'Deskripsi',
                      value: widget.item.description!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DetailRow(
                    icon: Icons.access_time,
                    label: 'Tanggal Pengajuan',
                    value: _formatDate(submittedAt),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.info_outline,
                    label: 'Status',
                    value: approvalStatus.label,
                    valueColor: approvalStatus.fg,
                  ),
                  if (widget.item.rejectionReason != null &&
                      widget.item.rejectionReason!.isNotEmpty) ...[
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Alasan Penolakan',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Color(0xFFC62828))),
                                const SizedBox(height: 4),
                                Text(
                                  widget.item.rejectionReason!,
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFFC62828)),
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

            // ── Card: Informasi Pemohon ────────────────────────────────────
            _card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                      icon: Icons.person_outline, title: 'Informasi Pemohon'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _typeColor.withValues(alpha: 0.15),
                        backgroundImage: _resolveSubmitterPhoto(),
                        child: _resolveSubmitterPhoto() == null
                            ? Text(
                                _initials(widget.item.submitterName),
                                style: TextStyle(
                                    color: _typeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayValue(widget.item.submitterName),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if ((widget.item.submitterPosition ?? '')
                                    .trim()
                                    .isNotEmpty ||
                                (widget.item.submitterDept ?? '')
                                    .trim()
                                    .isNotEmpty)
                              Text(
                                '${_displayValue(widget.item.submitterPosition)} • ${_displayValue(widget.item.submitterDept)}',
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if ((widget.item.submitterEmployeeId ?? '').trim().isNotEmpty) ...[
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Employee ID',
                      value: _displayValue(widget.item.submitterEmployeeId),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((widget.item.submitterEmail ?? '').trim().isNotEmpty) ...[
                    _DetailRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: _displayValue(widget.item.submitterEmail),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((widget.item.submitterPhone ?? '').trim().isNotEmpty) ...[
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Telepon',
                      value: _displayValue(widget.item.submitterPhone),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((widget.item.submitterCompany ?? '').trim().isNotEmpty) ...[
                    _DetailRow(
                      icon: Icons.business_outlined,
                      label: 'Perusahaan',
                      value: _displayValue(widget.item.submitterCompany),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((widget.item.submitterDept ?? '').trim().isNotEmpty) ...[
                    _DetailRow(
                      icon: Icons.manage_accounts_outlined,
                      label: 'Departemen',
                      value: _displayValue(widget.item.submitterDept),
                    ),
                  ],
                ],
              ),
            ),

            // ── Card: Informasi Reviewer ────────────────────────────────────
            if (!_isPending && widget.item.reviewerName != null &&
                widget.item.reviewerName!.trim().isNotEmpty)
              _card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                        icon: Icons.verified_user_outlined, title: 'Informasi Reviewer'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _typeColor.withValues(alpha: 0.15),
                          backgroundImage: _resolveReviewerPhoto(),
                          child: _resolveReviewerPhoto() == null
                              ? Text(
                                  _initials(widget.item.reviewerName),
                                  style: TextStyle(
                                      color: _typeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayValue(widget.item.reviewerName),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if ((widget.item.reviewerEmployeeId ?? '')
                                      .trim()
                                      .isNotEmpty)
                                Text(
                                  'NIP: ${_displayValue(widget.item.reviewerEmployeeId)}',
                                  style: TextStyle(
                                      color: Colors.black54, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Card: Detail Item (type-specific) ──────────────────────────
            if (!_isRegistration)
              _card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                        icon: _typeIcon, title: 'Detail ${_isLicense ? 'Lisensi' : 'Sertifikat'}'),
                    const SizedBox(height: 12),
                    if ((widget.item.itemName ?? '').trim().isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.label_outline,
                        label: 'Nama',
                        value: _displayValue(widget.item.itemName),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_isLicense &&
                        (widget.item.itemNumber ?? '').trim().isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.numbers,
                        label: 'Nomor Lisensi',
                        value: _displayValue(widget.item.itemNumber),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!_isLicense &&
                        (widget.item.itemIssuer ?? '').trim().isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.business,
                        label: 'Penerbit',
                        value: _displayValue(widget.item.itemIssuer),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.item.itemObtainedAt != null) ...[
                      _DetailRow(
                        icon: Icons.event_outlined,
                        label: 'Tanggal Diperoleh',
                        value: _formatDateShort(widget.item.itemObtainedAt!),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.item.itemExpiredAt != null) ...[
                      _DetailRow(
                        icon: Icons.event_busy_outlined,
                        label: 'Berlaku Sampai',
                        value: _formatDateShort(widget.item.itemExpiredAt!),
                        valueColor: widget.item.itemExpiredAt!.isBefore(DateTime.now())
                            ? const Color(0xFFF44336)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),

            // ── Approval Actions ───────────────────────────────────────────
            if (showActions) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _handleReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          side: BorderSide(
                            color: const Color(0xFFC62828).withValues(alpha: 0.42),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Tolak',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F80ED),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Setujui',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(
              height: AppSafeInsets.bottomNavScrollPadding(context),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FabNotchedBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
                icon: Icons.home, label: 'Home', index: 0, onTap: _onTabTapped),
            _NavItem(
                icon: Icons.article_outlined, label: 'News', index: 1, onTap: _onTabTapped),
            const SizedBox(width: 56),
            _NavItem(
                icon: Icons.inbox_outlined, label: 'Inbox', index: 3, onTap: _onTabTapped),
            _NavItem(
                icon: Icons.menu, label: 'Menu', index: 4, onTap: _onTabTapped),
          ],
        ),
      ),
    );
  }

  ImageProvider? _resolveSubmitterPhoto() {
    final url = (widget.item.submitterPhotoUrl ?? '').trim();
    if (url.isEmpty) return null;
    return CachedNetworkImageProvider(url);
  }

  ImageProvider? _resolveReviewerPhoto() {
    final url = (widget.item.reviewerPhotoUrl ?? '').trim();
    if (url.isEmpty) return null;
    return CachedNetworkImageProvider(url);
  }

  // ── Shared helpers ───────────────────────────────────────────────────────
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

  Widget _badge(String label, Color color, {Color? bg}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: bg ?? color, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: TextStyle(
                color: bg != null ? color : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      );
}

// ── Supporting widgets ──────────────────────────────────────────────────────

class _FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget Function(BuildContext) builder;
  _FadePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
}

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
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15)),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: Colors.grey,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
