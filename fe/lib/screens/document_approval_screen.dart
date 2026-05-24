import 'package:flutter/material.dart';

import '../models/inbox_item.dart';
import '../services/api_service.dart';
import '../services/approval_service.dart';
import '../services/inbox_service.dart';
import '../utils/ui_utils.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/approval_detail_sheet.dart';
import '../widgets/approval_task_card.dart';
import '../widgets/reject_reason_dialog.dart';

class DocumentApprovalScreen extends StatefulWidget {
  const DocumentApprovalScreen({super.key});

  @override
  State<DocumentApprovalScreen> createState() => _DocumentApprovalScreenState();
}

class _DocumentApprovalScreenState extends State<DocumentApprovalScreen> {
  static const _blue = Color(0xFF1A56C4);

  bool _isLoading = true;
  List<InboxItem> _pendingLicenses = [];
  List<InboxItem> _pendingCertifications = [];
  List<InboxItem> _pendingProfileChanges = [];
  List<InboxItem> _submissionHistory = [];
  String? _pendingError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoading = true;
      _pendingError = null;
      _historyError = null;
    });

    var pendingItems = <InboxItem>[];
    var historyItems = <InboxItem>[];
    String? pendingError;
    String? historyError;

    try {
      pendingItems = await ApprovalService.getPendingApprovalItems();
    } catch (e) {
      pendingError = _cleanError(e);
    }

    try {
      historyItems = await ApprovalService.getApprovalHistoryItems();
    } catch (e) {
      historyError = _cleanError(e);
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _pendingError = pendingError;
      _historyError = historyError;
      _pendingLicenses = _sortByDateDesc(
        pendingItems
            .where((item) => item.itemType == InboxItemType.approvalLicense),
      );
      _pendingCertifications = _sortByDateDesc(
        pendingItems.where(
          (item) => item.itemType == InboxItemType.approvalCertification,
        ),
      );
      _pendingProfileChanges = _sortByDateDesc(
        pendingItems.where(
          (item) => item.itemType == InboxItemType.approvalProfileChange,
        ),
      );
      _submissionHistory = _sortByDateDesc(
        historyItems.where((item) => !_isActionable(item)),
      );
    });
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  List<InboxItem> _sortByDateDesc(Iterable<InboxItem> items) {
    final list = items.toList();
    list.sort((a, b) {
      final aDate = a.submittedAt ?? a.createdAt;
      final bDate = b.submittedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    return list;
  }

  bool _isActionable(InboxItem item) {
    final status = (item.approvalStatus ?? 'pending').toLowerCase();
    return status == 'pending' || status == 'pending_changes';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Approval of Submissions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            labelColor: _blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _blue,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              _buildTab('Lisensi', _pendingLicenses.length),
              _buildTab('Sertifikat', _pendingCertifications.length),
              _buildTab('Profil', _pendingProfileChanges.length),
              _buildTab('Riwayat', _submissionHistory.length),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _pendingError != null
                      ? _buildErrorState(_pendingError!)
                      : _buildApprovalList(
                          documents: _pendingLicenses,
                          emptyIcon: Icons.badge_outlined,
                          emptyMessage: 'Tidak ada lisensi menunggu approval',
                        ),
                  _pendingError != null
                      ? _buildErrorState(_pendingError!)
                      : _buildApprovalList(
                          documents: _pendingCertifications,
                          emptyIcon: Icons.workspace_premium_outlined,
                          emptyMessage:
                              'Tidak ada sertifikasi menunggu approval',
                        ),
                  _pendingError != null
                      ? _buildErrorState(_pendingError!)
                      : _buildApprovalList(
                          documents: _pendingProfileChanges,
                          emptyIcon: Icons.person_outline,
                          emptyMessage:
                              'Tidak ada perubahan profil menunggu approval',
                        ),
                  _historyError != null
                      ? _buildErrorState(_historyError!)
                      : _buildApprovalList(
                          documents: _submissionHistory,
                          showActions: false,
                          emptyIcon: Icons.history,
                          emptyMessage: 'Belum ada history pengajuan dokumen',
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildTab(String label, int count) {
      return Tab(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (count > 0) ...[
                const SizedBox(width: 6),
                _buildBadge(count),
              ],
            ],
          ),
        ),
      );
    }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildApprovalList({
    required List<InboxItem> documents,
    required IconData emptyIcon,
    required String emptyMessage,
    bool showActions = true,
  }) {
    if (documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchDocuments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSafeInsets.pagePadding(context),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
            _buildEmptyState(icon: emptyIcon, message: emptyMessage),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDocuments,
      child: ListView.builder(
        padding: AppSafeInsets.pagePadding(context),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final item = documents[index];
          final allowActions = showActions && _isActionable(item);

          return ApprovalTaskCard(
            item: item,
            showActionButtons: false,
            onTap: () async {
              await _markItemRead(item);
              if (!mounted) return;
              _showApprovalDetail(item, showActionButtons: allowActions);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade200),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchDocuments,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markItemRead(InboxItem item) async {
    if (item.isRead) return;

    setState(() => item.isRead = true);
    final response = await InboxService.markRead(
      itemId: item.id,
      itemType: item.backendItemType,
    );

    if (!response.success && mounted) {
      setState(() => item.isRead = false);
    }
  }

  void _showApprovalDetail(
    InboxItem item, {
    required bool showActionButtons,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApprovalDetailSheet(
        item: item,
        showActionButtons: showActionButtons,
        onApprove: showActionButtons
            ? () => _runApprovalAction(item: item, approve: true)
            : null,
        onReject: showActionButtons
            ? () async {
                final reason = await showRejectReasonDialog(
                  context,
                  title: 'Tolak Pengajuan',
                  confirmLabel: 'Tolak',
                );
                if (reason == null) return false;
                return _runApprovalAction(
                  item: item,
                  approve: false,
                  reason: reason,
                );
              }
            : null,
        onDone: _fetchDocuments,
      ),
    );
  }

  Future<bool> _runApprovalAction({
    required InboxItem item,
    required bool approve,
    String? reason,
  }) async {
    Map<String, String>? minePermitDates;
    if (approve &&
        item.itemType == InboxItemType.approvalLicense &&
        item.itemLicenseType == 'mine_permit') {
      minePermitDates = await _pickMinePermitApprovalDates(item);
      if (minePermitDates == null) return false;
    }

    late final ApiResponse response;
    switch (item.itemType) {
      case InboxItemType.approvalLicense:
        response = approve
            ? await ApprovalService.approveLicense(
                item.id,
                obtainedAt: minePermitDates?['obtained_at'],
                expiredAt: minePermitDates?['expired_at'],
              )
            : await ApprovalService.rejectLicense(item.id, reason ?? '');
        break;
      case InboxItemType.approvalCertification:
        response = approve
            ? await ApprovalService.approveCertification(item.id)
            : await ApprovalService.rejectCertification(item.id, reason ?? '');
        break;
      case InboxItemType.approvalProfileChange:
        response = approve
            ? await ApprovalService.approveProfileChange(item.id)
            : await ApprovalService.rejectProfileChange(item.id, reason ?? '');
        break;
      default:
        return false;
    }

    if (!mounted) return false;

    if (response.success) {
      final isMinePermit =
          item.itemType == InboxItemType.approvalLicense &&
              item.itemLicenseType == 'mine_permit';
      final successMessage = approve
          ? (isMinePermit
              ? 'Mine Permit berhasil disetujui dan diaktifkan.'
              : 'Pengajuan berhasil disetujui.')
          : (isMinePermit
              ? 'Pengajuan Mine Permit berhasil ditolak.'
              : 'Pengajuan berhasil ditolak.');
      await UiUtils.showSuccessPopup(context, successMessage);
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.errorMessage ?? 'Gagal memproses persetujuan.'),
      ),
    );
    return false;
  }

  Future<Map<String, String>?> _pickMinePermitApprovalDates(
      InboxItem item) async {
    DateTime? releaseDate = item.itemObtainedAt ?? DateTime.now();
    DateTime? expiredDate =
        item.itemExpiredAt ?? DateTime.now().add(const Duration(days: 365));

    String formatPayload(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    String formatDisplay(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    Widget buildFieldLabel(String label) => Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        );

    Widget buildDateField({
      required IconData leadingIcon,
      required DateTime value,
      required VoidCallback onTap,
    }) =>
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(leadingIcon,
                    size: 20, color: const Color(0xFF1A56C4)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    formatDisplay(value),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.calendar_month_outlined,
                    size: 18, color: Colors.grey.shade500),
              ],
            ),
          ),
        );

    Future<DateTime?> pickDate({
      required BuildContext ctx,
      required DateTime initialDate,
      required DateTime firstDate,
      required DateTime lastDate,
    }) =>
        showDatePicker(
          context: ctx,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (themeCtx, child) => Theme(
            data: Theme.of(themeCtx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1A56C4),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A56C4),
                ),
              ),
            ),
            child: child!,
          ),
        );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          title: const Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  color: Color(0xFF1A56C4), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Approval Mine Permit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildFieldLabel('Tanggal Rilis'),
              buildDateField(
                leadingIcon: Icons.event_available_outlined,
                value: releaseDate!,
                onTap: () async {
                  final picked = await pickDate(
                    ctx: context,
                    initialDate: releaseDate!,
                    firstDate: DateTime.now()
                        .subtract(const Duration(days: 365 * 5)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      releaseDate = picked;
                      if (expiredDate!.isBefore(picked)) {
                        expiredDate = picked.add(const Duration(days: 365));
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              buildFieldLabel('Tanggal Expired'),
              buildDateField(
                leadingIcon: Icons.event_busy_outlined,
                value: expiredDate!,
                onTap: () async {
                  final picked = await pickDate(
                    ctx: context,
                    initialDate: expiredDate!,
                    firstDate: releaseDate!,
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setDialogState(() => expiredDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56C4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Setujui',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || releaseDate == null || expiredDate == null) {
      return null;
    }

    return {
      'obtained_at': formatPayload(releaseDate!),
      'expired_at': formatPayload(expiredDate!),
    };
  }
}
