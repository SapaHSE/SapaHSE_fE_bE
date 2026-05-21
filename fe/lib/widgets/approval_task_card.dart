import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/inbox_item.dart';
import '../utils/approval_status_ui.dart';

class ApprovalTaskCard extends StatelessWidget {
  final InboxItem item;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool isProcessing;
  final bool showActionButtons;

  const ApprovalTaskCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onApprove,
    this.onReject,
    this.isProcessing = false,
    this.showActionButtons = false,
  });

  static const _regColor = Color(0xFF1A56C4);
  static const _licenseColor = Color(0xFFEF6C00);
  static const _certColor = Color(0xFF6A1B9A);
  static const _profileColor = Color(0xFF00897B);

  bool get _isRegistration =>
      item.itemType == InboxItemType.approvalRegistration;
  bool get _isLicense => item.itemType == InboxItemType.approvalLicense;
  bool get _isProfileChange =>
      item.itemType == InboxItemType.approvalProfileChange;

  Color get _accent {
    switch (item.itemType) {
      case InboxItemType.approvalRegistration:
        return _regColor;
      case InboxItemType.approvalLicense:
        return _licenseColor;
      case InboxItemType.approvalCertification:
        return _certColor;
      case InboxItemType.approvalProfileChange:
        return _profileColor;
      default:
        return _regColor;
    }
  }

  String get _typeLabel {
    switch (item.itemType) {
      case InboxItemType.approvalRegistration:
        return 'REGISTRASI';
      case InboxItemType.approvalLicense:
        return 'LISENSI';
      case InboxItemType.approvalCertification:
        return 'SERTIFIKAT';
      case InboxItemType.approvalProfileChange:
        return 'PROFIL';
      default:
        return 'APPROVAL';
    }
  }

  String? get _metaInfo {
    if (_isLicense) {
      if ((item.itemNumber ?? '').trim().isNotEmpty) {
        return 'No. ${item.itemNumber!.trim()}';
      }
      return null;
    }
    if (_isRegistration) {
      return null;
    }
    if ((item.itemIssuer ?? '').trim().isNotEmpty) {
      return 'Penerbit: ${item.itemIssuer!.trim()}';
    }
    return null;
  }

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year;
    return '$dd/$mm/$yyyy';
  }

  String _initials(String? name) {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return 'U';
    final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  ApprovalStatusStyle _statusStyle(String? rawStatus) =>
      approvalStatusStyle(rawStatus);

  Widget _buildInputDefaultIcon() {
    final IconData iconData;
    final Color iconColor;
    final Color iconBgColor;

    if (_isLicense) {
      iconData = Icons.badge_outlined;
      iconColor = const Color(0xFF1E88E5);
      iconBgColor = const Color(0xFFE3F2FD);
    } else {
      iconData = Icons.workspace_premium_outlined;
      iconColor = const Color(0xFF6A1B9A);
      iconBgColor = const Color(0xFFF3E5F5);
    }

    return Container(
      color: iconBgColor,
      alignment: Alignment.center,
      child: Icon(
        iconData,
        color: iconColor.withValues(alpha: 0.95),
        size: 56,
      ),
    );
  }

  Widget _buildRegistrationDefaultImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _accent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        _initials(item.submitterName),
        style: TextStyle(
          color: _accent,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final imageUrl = (item.itemFileUrl ?? '').trim();
    if (!_isRegistration && !_isProfileChange && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => _buildInputDefaultIcon(),
      );
    }

    final photoUrl = (item.submitterPhotoUrl ?? '').trim();
    if ((_isRegistration || _isProfileChange) && photoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => _buildRegistrationDefaultImage(),
      );
    }

    if (_isRegistration || _isProfileChange) {
      return _buildRegistrationDefaultImage();
    }

    return _buildInputDefaultIcon();
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 110,
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Expanded(child: _buildImagePreview()),
          Container(
            width: double.infinity,
            height: 20,
            color: _accent,
            child: Center(
              child: Text(
                _typeLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRead = item.isRead;
    final submittedAt = item.submittedAt ?? item.createdAt;
    final status = _statusStyle(item.approvalStatus);
    final normalizedStatus = normalizeApprovalStatus(item.approvalStatus);
    final statusPending =
        normalizedStatus == 'pending' || normalizedStatus == 'pending_changes';
    final showActions = showActionButtons &&
        statusPending &&
        onApprove != null &&
        onReject != null;

    final submitter = (item.submitterName ?? 'Pemohon').trim();
    final department = (item.submitterDept ?? '').trim();
    final submitterLine =
        department.isEmpty ? submitter : '$submitter • $department';
    final metaInfo = _metaInfo;
    final previewText = ((item.description ?? metaInfo) ?? '').trim();
    final hasPreviewText = previewText.isNotEmpty;
    const cardContentHeight = 122.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : const Color(0xFF1A56C4).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              SizedBox(
                height: cardContentHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLeftPanel(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 215;
                          final dense = compact || constraints.maxHeight <= 126;
                          final showPreview = hasPreviewText;
                          final metaFontSize = dense ? 9.5 : 11.0;
                          final iconSize = dense ? 9.0 : 11.0;
                          final chipVPad = dense ? 2.0 : 3.0;
                          final chipHPad = dense ? 6.0 : 8.0;
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              12,
                              dense ? 7 : 10,
                              12,
                              dense ? 6 : 9,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: dense ? 13 : 14,
                                          fontWeight: isRead
                                              ? FontWeight.w600
                                              : FontWeight.bold,
                                          color: Colors.black87),
                                    ),
                                    if (showPreview) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        previewText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: iconSize,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _formatDate(submittedAt),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: metaFontSize,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: dense ? 3 : 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: iconSize,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            submitterLine,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: metaFontSize,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: dense ? 4 : 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: chipHPad,
                                          vertical: chipVPad,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              status.fg.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: status.fg
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          status.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: status.fg,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (showActions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isProcessing ? null : onReject,
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Tolak',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isProcessing ? null : onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F80ED),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Setujui',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
