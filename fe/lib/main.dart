import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_globals.dart';
import 'config/supabase_config.dart';
import 'services/announcement_service.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/news_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/create_hazard_screen.dart';
import 'screens/create_inspection_screen.dart';
import 'screens/qr_scan_screen.dart';
import 'widgets/fab_notched_bottom_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.black,
  ));
  await SharedPreferences.getInstance();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const BBEApp());
}

class BBEApp extends StatelessWidget {
  const BBEApp({super.key});

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      StorageService.isLoggedIn().then((loggedIn) {
        if (!loggedIn && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_clock, color: Color(0xFF1A56C4)),
                  SizedBox(width: 8),
                  Text('Sesi Berakhir'),
                ],
              ),
              content: const Text(
                'Sesi kamu telah habis. Silakan login kembali untuk melanjutkan.',
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Login Kembali'),
                ),
              ],
            ),
          );
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
          _showAddNewsSheet();
        },
      ),
    );
  }

  void _showAddNewsSheet() {
    final titleCtrl = TextEditingController();
    final excerptCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
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
                const Text('Tambah Berita',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Judul Berita',
                    hintText: 'Masukkan judul berita',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: excerptCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Ringkasan',
                    hintText: 'Masukkan ringkasan berita',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Berita berhasil ditambahkan'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Tambah'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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

  const _FabMenuSheet({
    required this.currentIndex,
    required this.onScanQr,
    required this.onCreateHazard,
    required this.onCreateInspection,
    required this.onAddAnnouncement,
    required this.onAddNews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
            subtitle: 'Pindai QR untuk verifikasi peralatan',
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
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _MenuTile(
            icon: Icons.campaign_rounded,
            iconBgColor: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF7B1FA2),
            title: 'Tambah Pengumuman',
            subtitle: 'Buat pengumuman urgent atau biasa',
            onTap: onAddAnnouncement,
          ),
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




