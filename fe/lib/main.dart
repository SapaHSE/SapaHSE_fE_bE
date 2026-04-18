import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_globals.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
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
      home: const SplashScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
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
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CreateHazardScreen()));
        },
        onCreateInspection: () {
          Navigator.pop(context);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CreateInspectionScreen()));
        },
        onAddCarousel: () {
          Navigator.pop(context);
          _showAddCarouselSheet();
        },
        onAddNews: () {
          Navigator.pop(context);
          _showAddNewsSheet();
        },
      ),
    );
  }

  void _showAddCarouselSheet() {
    XFile? pickedFile;
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Tambah Gambar Carousel',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              
              if (pickedFile != null)
                Container(
                  height: 180,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(File(pickedFile!.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 8, top: 8,
                        child: GestureDetector(
                          onTap: () => setModalState(() => pickedFile = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _ImageSourceCard(
                        icon: Icons.camera_alt_outlined,
                        label: 'Kamera',
                        color: const Color(0xFF1A56C4),
                        onTap: () async {
                          final file = await picker.pickImage(source: ImageSource.camera);
                          if (file != null) setModalState(() => pickedFile = file);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImageSourceCard(
                        icon: Icons.photo_library_outlined,
                        label: 'Galeri',
                        color: const Color(0xFF2E7D32),
                        onTap: () async {
                          final file = await picker.pickImage(source: ImageSource.gallery);
                          if (file != null) setModalState(() => pickedFile = file);
                        },
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: pickedFile == null ? null : () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Gambar carousel berhasil ditambahkan'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Simpan Banner'),
                ),
              ),
            ],
          ),
        ),
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text('Tambah Berita',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Judul Berita',
                    hintText: 'Masukkan judul berita',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: excerptCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Ringkasan',
                    hintText: 'Masukkan ringkasan berita',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFabMenu,
        backgroundColor: const Color(0xFF1A56C4),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home, label: 'Home', index: 0,
                  currentIndex: _currentIndex, onTap: _onTabTapped),
              _NavItem(icon: Icons.article_outlined, label: 'News', index: 1,
                  currentIndex: _currentIndex, onTap: _onTabTapped),
              const SizedBox(width: 48),
              _NavItem(icon: Icons.inbox_outlined, label: 'Inbox', index: 3,
                  currentIndex: _currentIndex, onTap: _onTabTapped),
              _NavItem(icon: Icons.person_outline, label: 'Profile', index: 4,
                  currentIndex: _currentIndex, onTap: _onTabTapped),
            ],
          ),
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
  final VoidCallback onAddCarousel;
  final VoidCallback onAddNews;

  const _FabMenuSheet({
    required this.currentIndex,
    required this.onScanQr,
    required this.onCreateHazard,
    required this.onCreateInspection,
    required this.onAddCarousel,
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
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40, height: 4,
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

          // ── Scan QR ───────────────────────────────────────────────
          _MenuTile(
            icon: Icons.qr_code_scanner,
            iconBgColor: const Color(0xFFEFF4FF),
            iconColor: const Color(0xFF1A56C4),
            title: 'Scan QR Code',
            subtitle: 'Pindai QR untuk verifikasi peralatan',
            onTap: onScanQr,
          ),

          Divider(height: 1, indent: 72, color: Colors.grey.shade100),

          // ── Create Hazard ─────────────────────────────────────────
          _MenuTile(
            icon: Icons.warning_amber_rounded,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFF44336),
            title: 'Buat Laporan Hazard',
            subtitle: 'Laporkan potensi bahaya di area kerja',
            onTap: onCreateHazard,
          ),

          Divider(height: 1, indent: 72, color: Colors.grey.shade100),

          // ── Create Inspection ─────────────────────────────────────
          _MenuTile(
            icon: Icons.search,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            title: 'Buat Laporan Inspeksi',
            subtitle: 'Catat hasil inspeksi rutin area kerja',
            onTap: onCreateInspection,
          ),

          // ── Tambah Gambar Carousel (Home tab) ─────────────────────
          if (currentIndex == 0) ...[
            Divider(height: 1, indent: 72, color: Colors.grey.shade100),
            _MenuTile(
              icon: Icons.add_photo_alternate_outlined,
              iconBgColor: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              title: 'Tambah Gambar Carousel',
              subtitle: 'Tambah banner gambar di halaman utama',
              onTap: onAddCarousel,
            ),
          ],

          // ── Tambah Berita (News tab) ───────────────────────────────
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

          // Cancel button
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
                width: 44, height: 44,
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
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 20),
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
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}