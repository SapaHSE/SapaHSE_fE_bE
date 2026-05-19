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

  bool get _isRegistration => item.itemType == InboxItemType.approvalRegistration;
  bool get _isLicense => item.itemType == InboxItemType.approvalLicense;

  Color get _accent {
    switch (item.itemType) {
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

  String get _typeLabel {
    switch (item.itemType) {
      case InboxItemType.approvalRegistration:
        return 'REGISTRASI';
      case InboxItemType.approvalLicense:
        return 'LICENSE';
      case InboxItemType.approvalCertification:
        return 'CERTIFICATE';
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
    if (!_isRegistration && imageUrl.isNotEmpty) {
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
    if (_isRegistration && photoUrl.isNotEmpty) {
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

    if (_isRegistration) {
      return _buildRegistrationDefaultImage();
    }

    return _buildInputDefaultIcon();
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 120,
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Expanded(child: _buildImagePreview()),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: _accent,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submittedAt = item.submittedAt ?? item.createdAt;
    final status = _statusStyle(item.approvalStatus);
    final statusPending = normalizeApprovalStatus(item.approvalStatus) == 'pending';
    final showActions = showActionButtons &&
        statusPending &&
        onApprove != null &&
        onReject != null;

    final submitter = (item.submitterName ?? 'Pemohon').trim();
    final department = (item.submitterDept ?? '').trim();
    final submitterLine =
        department.isEmpty ? submitter : '$submitter • $department';
    final metaInfo = _metaInfo;
    final hasMetaInfo = metaInfo != null && metaInfo.trim().isNotEmpty;
    final cardContentHeight = showActions
        ? (hasMetaInfo ? 142.0 : 136.0)
        : (hasMetaInfo ? 138.0 : 130.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.25)),
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.25),
                            ),
                            if (hasMetaInfo) ...[
                              const SizedBox(height: 4),
                              Text(
                                metaInfo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 13,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _formatDate(submittedAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    submitterLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child:                            Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: status.fg.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: status.fg.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  status.label,
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
