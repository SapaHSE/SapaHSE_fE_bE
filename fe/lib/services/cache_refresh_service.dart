import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'announcement_service.dart';
import 'cloud_save_service.dart';
import 'inbox_service.dart';
import 'news_service.dart';
import 'offline_cache_service.dart';
import 'offline_reference_cache_service.dart';
import 'profile_service.dart';
import 'report_service.dart';
import 'storage_service.dart';

const _cacheRefreshTaskName = 'sapahse-cache-refresh';
const _cacheRefreshUniqueName = 'sapahse-cache-refresh-periodic';

@pragma('vm:entry-point')
void cacheRefreshCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await OfflineCacheService.init();

    final loggedIn = await StorageService.isLoggedIn();
    if (!loggedIn) return true;
    final online = await CloudSaveService.isOnline();
    if (!online) return true;

    await CacheRefreshService.instance.refreshStaleGroups(silent: true);
    return true;
  });
}

class CacheRefreshService with WidgetsBindingObserver {
  CacheRefreshService._();
  static final CacheRefreshService instance = CacheRefreshService._();

  Timer? _timer;
  bool _started = false;
  bool _refreshing = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _timer = Timer.periodic(
      OfflineCacheService.staleAfter,
      (_) => refreshStaleGroups(silent: true),
    );

    await _registerBackgroundRefresh();
    unawaited(refreshStaleGroups(silent: true));
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshStaleGroups(silent: true));
    } else if (state == AppLifecycleState.paused) {
      unawaited(refreshStaleGroups(silent: true));
    }
  }

  Future<void> refreshStaleGroups({
    bool force = false,
    bool silent = false,
  }) async {
    if (_refreshing) return;
    final loggedIn = await StorageService.isLoggedIn();
    if (!loggedIn) return;
    final online = await CloudSaveService.isOnline();
    if (!online) return;

    _refreshing = true;
    try {
      await Future.wait([
        _refreshGroup(
          OfflineCacheGroups.reports,
          force,
          () async {
            await ReportService.getReports(perPage: 100);
          },
        ),
        _refreshGroup(
          OfflineCacheGroups.inbox,
          force,
          () async {
            await Future.wait([
              InboxService.fetchInbox(type: 'personal', perPage: 100),
              InboxService.fetchInbox(type: 'announcement', perPage: 100),
            ]);
          },
        ),
        _refreshGroup(
          OfflineCacheGroups.news,
          force,
          () async {
            await NewsService.getNews(includeScheduled: true);
          },
        ),
        _refreshGroup(
          OfflineCacheGroups.announcements,
          force,
          () async {
            await AnnouncementService.getAnnouncements();
          },
        ),
        _refreshGroup(
          OfflineCacheGroups.profile,
          force,
          () async {
            await ProfileService.getProfile();
          },
        ),
        _refreshGroup(
          OfflineCacheGroups.references,
          force,
          () => OfflineReferenceCacheService.prefetchHazardCreateReferences(),
        ),
      ]);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshGroup(
    String group,
    bool force,
    Future<void> Function() refresh,
  ) async {
    try {
      if (!force && !await OfflineCacheService.isGroupStale(group)) return;
      await refresh();
    } catch (_) {
      // Cache refresh must never block foreground usage.
    }
  }

  Future<void> _registerBackgroundRefresh() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await Workmanager().initialize(
        cacheRefreshCallbackDispatcher,
      );
      await Workmanager().registerPeriodicTask(
        _cacheRefreshUniqueName,
        _cacheRefreshTaskName,
        frequency: OfflineCacheService.staleAfter,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {
      // Background refresh is best-effort; foreground/resume refresh remains primary.
    }
  }
}
