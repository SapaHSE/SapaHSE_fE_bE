import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/report_store.dart';
import 'cloud_save_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BACKGROUND SYNC SERVICE
/// ═══════════════════════════════════════════════════════════════════════════
/// App-wide singleton yang:
///   • Listen perubahan koneksi sepanjang aplikasi hidup (bukan hanya saat
///     layar Cloud Save terbuka).
///   • Memicu `syncAll` otomatis ketika koneksi kembali tersedia dan ada
///     draft pending.
///   • Mengekspos `ValueNotifier` (isOnline / isSyncing / draftCount) supaya
///     UI manapun bisa rebuild reaktif tanpa subscribe `connectivity_plus`
///     sendiri.
class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  bool _started = false;

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<int> draftCount = ValueNotifier<int>(0);

  /// Hook opsional untuk UI (mis. CloudSaveScreen) menampilkan snackbar
  /// per draft yang berhasil/gagal terkirim.
  void Function(ReportDraft draft, bool success)? onDraftResult;

  /// Dipanggil sekali dari `main()` setelah Supabase.initialize.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    isOnline.value = await CloudSaveService.isOnline();
    await refreshDraftCount();

    CloudSaveService.instance.connectivityStream.listen((_) async {
      final online = await CloudSaveService.isOnline();
      final wasOffline = !isOnline.value;
      isOnline.value = online;
      // Sync hanya saat transisi offline → online supaya tidak spam.
      if (online && wasOffline) {
        await syncNow();
      }
    });

    // Cold-start: kalau aplikasi dibuka dalam keadaan online dan ada draft
    // pending dari sesi sebelumnya, langsung sync.
    if (isOnline.value && draftCount.value > 0) {
      await syncNow();
    }
  }

  Future<void> refreshDraftCount() async {
    draftCount.value = await CloudSaveService.instance.getDraftCount();
  }

  /// Manual trigger (mis. tombol "Kirim Sekarang" di Cloud Save screen).
  /// Aman dipanggil berkali-kali — guard `isSyncing` mencegah double-run.
  Future<void> syncNow() async {
    if (isSyncing.value) return;
    if (!isOnline.value) return;
    await refreshDraftCount();
    if (draftCount.value == 0) return;

    isSyncing.value = true;
    try {
      await CloudSaveService.instance.syncAll(
        uploadFn: (draft) => ReportStore.instance.submitDraft(draft),
        onEach: (draft, success) {
          onDraftResult?.call(draft, success);
        },
      );
      await refreshDraftCount();
    } finally {
      isSyncing.value = false;
    }
  }

  /// Dipanggil setelah sebuah draft baru disimpan (mis. dari
  /// CreateHazardScreen) supaya `draftCount` notifier tetap akurat.
  Future<void> notifyDraftSaved() => refreshDraftCount();
}
