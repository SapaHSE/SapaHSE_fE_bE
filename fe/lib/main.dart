import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_globals.dart';
import 'config/supabase_config.dart';
import 'services/announcement_service.dart';
import 'services/background_sync_service.dart';
import 'services/cache_refresh_service.dart';
import 'services/idle_timeout_service.dart';
import 'services/offline_cache_service.dart';
import 'services/qr_service.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/news_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/create_hazard_screen.dart';
import 'screens/create_inspection_screen.dart';
import 'screens/qr_scan_screen.dart';
import 'screens/news_create_screen.dart';
import 'widgets/app_safe_insets.dart';
import 'widgets/fab_notched_bottom_bar.dart';
import 'widgets/idle_detector.dart';
import 'widgets/session_expired_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb) {
    // Initialize Firebase
    await Firebase.initializeApp();
    
    // Set the background messaging handler early on, as a named top-level function
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize Push Notifications
    await PushNotificationService.initialize();
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.black,
  ));
  await SharedPreferences.getInstance();
  await OfflineCacheService.init();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  await BackgroundSyncService.instance.start();
  await CacheRefreshService.instance.start();

  runApp(const BBEApp());
}

class BBEApp extends StatefulWidget {
  const BBEApp({super.key});

  @override
  State<BBEApp> createState() => _BBEAppState();
}

class _BBEAppState extends State<BBEApp> {
  static const MethodChannel _deepLinkChannel =
      MethodChannel('sapahse/deep_link');

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _deepLinkChannel.setMethodCallHandler(_handleNativeDeepLink);
      _loadInitialDeepLink();
    }
  }

  Future<void> _loadInitialDeepLink() async {
    try {
      final link = await _deepLinkChannel.invokeMethod<String>(
        'getInitialLink',
      );
      await _handleDeepLink(link);
    } on MissingPluginException {
      // Web/desktop builds do not register the native deep link channel.
    }
  }

  Future<void> _handleNativeDeepLink(MethodCall call) async {
    if (call.method != 'onDeepLink') return;
    await _handleDeepLink(call.arguments?.toString());
  }

  Future<void> _handleDeepLink(String? link) async {
    final qrCode = QrService.qrCodeFromDeepLink(link);
    if (qrCode == null) return;

    final loggedIn = await StorageService.isLoggedIn();
    if (!loggedIn) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => QrScanScreen(initialQrCode: qrCode),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SapaHse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56C4),
          primary: const Color(0xFF1A56C4),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('id')],
      builder: (context, child) => IdleDetector(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  bool _canAddAnnouncement = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserPermissions();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadUserPermissions() async {
    final user = await StorageService.getUser();
    final role = user?['role']?.toString().toLowerCase();
    final canAdd = role == 'admin' || role == 'superadmin';
    if (!mounted) return;
    setState(() {
      _canAddAnnouncement = canAdd;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pastikan timestamp terakhir ter-persist sebelum app benar-benar di-background.
      IdleTimeoutService.instance.recordActivity();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      StorageService.isLoggedIn().then((loggedIn) async {
        if (!mounted) return;
        if (!loggedIn) {
          await showSessionExpiredDialog(reason: SessionEndReason.notLoggedIn);
          return;
        }
        final expired = await IdleTimeoutService.instance.checkOnResume();
        if (!mounted) return;
        if (!expired) {
          // Re-arm in-memory ticker setelah app kembali ke foreground.
          await IdleTimeoutService.instance.start();
        }
      });
    }
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    NewsScreen(),
    SizedBox(), // FAB placeholder
    InboxScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == 2) return;
    setState(() => _currentIndex = index);
  }

  void _openFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FabMenuSheet(
        currentIndex: _currentIndex,
        onScanQr: () {
          Navigator.pop(context);
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
        },
        onCreateHazard: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateHazardScreen()));
        },
        onCreateInspection: () {
          Navigator.pop(context);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CreateInspectionScreen()));
        },
        onAddAnnouncement: () {
          Navigator.pop(context);
          _showAddAnnouncementSheet();
        },
        onAddNews: () {
          Navigator.pop(context);
          _openCreateNewsScreen();
        },
        canAddAnnouncement: _canAddAnnouncement,
      ),
    );
  }

  Future<void> _openCreateNewsScreen() async {
    final created = await Navigator.of(context).push(NewsCreateScreen.route());
    if (created == true && mounted) {
      setState(() => _currentIndex = 1);
    }
  }

  void _showAddAnnouncementSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    bool isUrgent = false;
    File? selectedImage;
    bool isSubmitting = false;
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: AppSafeInsets.keyboardOrSystemBottom(ctx),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              AppSafeInsets.defaultSheetGap,
            ),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Tambah Pengumuman Baru',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Judul Pengumuman',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Isi Pengumuman',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 70,
                      );
                      if (file != null) {
                        setModal(() => selectedImage = File(file.path));
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 32,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tambah Gambar (Opsional)',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUrgent
                              ? Icons.notification_important
                              : Icons.info_outline,
                          color: isUrgent ? Colors.red : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Status Urgent',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                isUrgent
                                    ? 'Akan muncul pop-up'
                                    : 'Muncul di list/carousel',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isUrgent,
                          activeThumbColor: Colors.red,
                          onChanged: (v) => setModal(() => isUrgent = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (titleCtrl.text.trim().isEmpty ||
                                  bodyCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Judul dan isi wajib diisi'),
                                  ),
                                );
                                return;
                              }
                              setModal(() => isSubmitting = true);
                              final success =
                                  await AnnouncementService.createAnnouncement(
                                title: titleCtrl.text.trim(),
                                body: bodyCtrl.text.trim(),
                                isUrgent: isUrgent,
                                image: selectedImage,
                              );
                              if (!mounted || !ctx.mounted) return;
                              setModal(() => isSubmitting = false);
                              if (success) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Pengumuman berhasil diterbitkan'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Gagal menerbitkan pengumuman'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56C4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Terbitkan Pengumuman',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: IndexedStack(index: _currentIndex, children: _screens),
      extendBody: true,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_fab',
        onPressed: _openFabMenu,
        backgroundColor: const Color(0xFF1A56C4),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: FabNotchedBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                currentIndex: _currentIndex,
                onTap: _onTabTapped),
            _NavItem(
                icon: Icons.article_outlined,
                label: 'News',
                index: 1,
                currentIndex: _currentIndex,
                onTap: _onTabTapped),
            const SizedBox(width: 56),
            _NavItem(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                index: 3,
                currentIndex: _currentIndex,
                onTap: _onTabTapped),
            _NavItem(
                icon: Icons.menu,
                label: 'Menu',
                index: 4,
                currentIndex: _currentIndex,
                onTap: _onTabTapped),
          ],
        ),
      ),
    );
  }
}

// ── FAB BOTTOM SHEET ──────────────────────────────────────────────────────────
class _FabMenuSheet extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onScanQr;
  final VoidCallback onCreateHazard;
  final VoidCallback onCreateInspection;
  final VoidCallback onAddAnnouncement;
  final VoidCallback onAddNews;
  final bool canAddAnnouncement;

  const _FabMenuSheet({
    required this.currentIndex,
    required this.onScanQr,
    required this.onCreateHazard,
    required this.onCreateInspection,
    required this.onAddAnnouncement,
    required this.onAddNews,
    required this.canAddAnnouncement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppSafeInsets.sheetBottomPadding(context, base: 32),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Pilih Aksi',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.qr_code_scanner,
            iconBgColor: const Color(0xFFEFF4FF),
            iconColor: const Color(0xFF1A56C4),
            title: 'Scan QR Code',
            subtitle: 'Cetak ID Card atau scan profil user',
            onTap: onScanQr,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _MenuTile(
            icon: Icons.warning_amber_rounded,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFF44336),
            title: 'Buat Laporan Hazard',
            subtitle: 'Laporkan potensi bahaya di area kerja',
            onTap: onCreateHazard,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _MenuTile(
            icon: Icons.search,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            title: 'Buat Laporan Inspeksi',
            subtitle: 'Catat hasil inspeksi rutin area kerja',
            onTap: onCreateInspection,
          ),
          if (canAddAnnouncement) ...[
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
            _MenuTile(
              icon: Icons.campaign_rounded,
              iconBgColor: const Color(0xFFF3E5F5),
              iconColor: const Color(0xFF7B1FA2),
              title: 'Tambah Pengumuman',
              subtitle: 'Buat pengumuman urgent atau biasa',
              onTap: onAddAnnouncement,
            ),
          ],
          if (currentIndex == 1) ...[
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
            _MenuTile(
              icon: Icons.article_outlined,
              iconBgColor: const Color(0xFFFFF3E0),
              iconColor: const Color(0xFFE65100),
              title: 'Tambah Berita',
              subtitle: 'Buat dan publikasikan berita baru',
              onTap: onAddNews,
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200)),
                ),
                child: const Text('Batal', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}

// ── NAV ITEM ──────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




