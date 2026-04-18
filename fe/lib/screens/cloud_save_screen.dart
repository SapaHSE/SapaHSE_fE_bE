import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/report_store.dart';
import '../services/cloud_save_service.dart';
import 'dart:async';

class CloudSaveScreen extends StatefulWidget {
  const CloudSaveScreen({super.key});

  @override
  State<CloudSaveScreen> createState() => _CloudSaveScreenState();
}

class _CloudSaveScreenState extends State<CloudSaveScreen>
    with SingleTickerProviderStateMixin {
  // ── Constants ────────────────────────────────────────────────────────────
  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);

  // ── State ─────────────────────────────────────────────────────────────────
  List<ReportDraft> _drafts = [];
  bool _isOnline = false;
  bool _isSyncing = false;
  bool _isLoading = true;
  StreamSubscription<List<ConnectivityResult>>? _connectSub;
  late AnimationController _syncAnimController;

  @override
  void initState() {
    super.initState();
    _syncAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _init();
    _connectSub =
        CloudSaveService.instance.connectivityStream.listen((results) async {
      final online = await CloudSaveService.isOnline();
      if (mounted) setState(() => _isOnline = online);
      _loadDrafts(); // refresh count when connectivity changes
    });
  }

  Future<void> _init() async {
    _isOnline = await CloudSaveService.isOnline();
    await _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final drafts = await CloudSaveService.instance.getDrafts();
    if (mounted) setState(() { _drafts = drafts; _isLoading = false; });
  }

  @override
  void dispose() {
    _connectSub?.cancel();
    _syncAnimController.dispose();
    super.dispose();
  }

  // ── Sync ─────────────────────────────────────────────────────────────────
  Future<void> _syncAll() async {
    if (!_isOnline || _isSyncing) return;
    setState(() => _isSyncing = true);
    _syncAnimController.repeat();

    await CloudSaveService.instance.syncAll(
      uploadFn: (draft) async {
        return ReportStore.instance.submitDraft(draft);
      },
      onEach: (draft, success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              Icon(
                success ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success
                      ? '${draft.title} berhasil dikirim'
                      : '${draft.title} gagal dikirim',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ]),
            backgroundColor: success
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ));
        }
      },
    );

    _syncAnimController.stop();
    _syncAnimController.reset();
    await _loadDrafts();
    if (mounted) setState(() => _isSyncing = false);
  }

  // ── Delete draft ──────────────────────────────────────────────────────────
  Future<void> _deleteDraft(ReportDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Draft?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Draft "${draft.title}" akan dihapus permanen.',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CloudSaveService.instance.deleteDraft(draft.id);
      await _loadDrafts();
    }
  }

  // ── Format date ───────────────────────────────────────────────────────────
  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_outlined, color: _blue, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Cloud Save',
              style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_drafts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _isSyncing
                  ? RotationTransition(
                      turns: _syncAnimController,
                      child: const Icon(Icons.sync, color: _blue, size: 22),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync, color: _blue, size: 22),
                      tooltip: 'Sinkronisasi sekarang',
                      onPressed: _isOnline ? _syncAll : null,
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : Column(
              children: [
                // ── Online/Offline Banner ──────────────────────────────────
                _buildStatusBanner(),

                // ── Draft list ────────────────────────────────────────────
                Expanded(
                  child: _drafts.isEmpty ? _buildEmpty() : _buildList(),
                ),
              ],
            ),

      // ── Sync FAB ─────────────────────────────────────────────────────────
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: (_drafts.isNotEmpty && _isOnline)
            ? FloatingActionButton.extended(
                key: const ValueKey('sync_fab'),
                onPressed: _isSyncing ? null : _syncAll,
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_isSyncing ? 'Mengirim...' : 'Kirim Semua'),
              )
            : const SizedBox.shrink(key: ValueKey('no_fab')),
      ),
    );
  }

  // ── Status Banner ─────────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _isOnline ? const Color(0xFF1B5E20) : const Color(0xFF37474F),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline
                ? 'Online — laporan dapat dikirim sekarang'
                : 'Offline — laporan akan disimpan sebagai draft',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? const Color(0xFF69F0AE) : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _blueLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_done_outlined, size: 44, color: _blue),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tidak ada draft tersimpan',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Laporan yang dibuat saat offline\nakan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Draft List ────────────────────────────────────────────────────────────
  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadDrafts,
      color: _blue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _drafts.length,
        itemBuilder: (context, i) => _DraftCard(
          draft: _drafts[i],
          isOnline: _isOnline,
          formatDate: _formatDate,
          onDelete: () => _deleteDraft(_drafts[i]),
          onSync: _isSyncing
              ? null
              : _isOnline
                  ? () async {
                      setState(() => _isSyncing = true);
                      _syncAnimController.repeat();
                      final ok =
                          await ReportStore.instance.submitDraft(_drafts[i]);
                      if (ok) {
                        await CloudSaveService.instance
                            .deleteDraft(_drafts[i].id);
                      }
                      _syncAnimController.stop();
                      _syncAnimController.reset();
                      await _loadDrafts();
                      if (mounted) setState(() => _isSyncing = false);
                    }
                  : null,
        ),
      ),
    );
  }
}

// ── Draft Card ────────────────────────────────────────────────────────────────
class _DraftCard extends StatelessWidget {
  final ReportDraft draft;
  final bool isOnline;
  final String Function(DateTime) formatDate;
  final VoidCallback onDelete;
  final VoidCallback? onSync;

  const _DraftCard({
    required this.draft,
    required this.isOnline,
    required this.formatDate,
    required this.onDelete,
    required this.onSync,
  });

  static const _blue = Color(0xFF1A56C4);

  Color get _typeColor =>
      draft.type == DraftType.hazard
          ? const Color(0xFFF44336)
          : const Color(0xFF1565C0);

  IconData get _typeIcon =>
      draft.type == DraftType.hazard
          ? Icons.warning_amber_rounded
          : Icons.search;

  String get _typeLabel =>
      draft.type == DraftType.hazard ? 'Hazard' : 'Inspeksi';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // ── Top accent bar (draft type color) ──────────────────────────
            Container(
              height: 3,
              color: _typeColor,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row 1: type badge + date ───────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_typeIcon, size: 11, color: _typeColor),
                            const SizedBox(width: 4),
                            Text(_typeLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _typeColor,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Cloud save badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOnline
                                  ? Icons.cloud_upload_outlined
                                  : Icons.cloud_off_outlined,
                              size: 11,
                              color: _blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'Siap Kirim' : 'Menunggu Koneksi',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: _blue,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Title ────────────────────────────────────────────────
                  Text(
                    draft.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Meta ────────────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        formatDate(draft.createdAt),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          draft.data['location'] as String? ?? '-',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Actions ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline,
                              size: 15, color: Colors.red),
                          label: const Text('Hapus',
                              style: TextStyle(fontSize: 12, color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: onSync,
                          icon: Icon(
                            isOnline
                                ? Icons.cloud_upload_outlined
                                : Icons.cloud_off_outlined,
                            size: 15,
                          ),
                          label: Text(
                            isOnline ? 'Kirim Sekarang' : 'Tidak Ada Koneksi',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isOnline ? _blue : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
