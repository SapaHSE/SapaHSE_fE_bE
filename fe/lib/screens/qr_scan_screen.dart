import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/profile_model.dart';
import '../services/id_card_pdf_service.dart';
import '../services/profile_service.dart';
import '../services/qr_service.dart';
import '../widgets/app_safe_insets.dart';
import 'user_profile_view_screen.dart';

class QrScanScreen extends StatefulWidget {
  final String? initialQrCode;

  const QrScanScreen({super.key, this.initialQrCode});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  int _selectedTab = 1;
  bool _torchOn = false;
  bool _hasScanned = false;
  bool _isResolvingScan = false;
  String? _rawScannedCode;
  String? _scanError;
  QrScanResult? _scanResult;
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;

  bool _isLoadingProfile = true;
  bool _isExportingIdCard = false;
  String? _profileError;
  ProfileData? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scanLineAnimation = CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOut,
    );
    _loadProfile();
    final initialQrCode = widget.initialQrCode?.trim();
    if (initialQrCode != null && initialQrCode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveExternalQr(initialQrCode);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_selectedTab != 1 || !_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_hasScanned) _controller.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _controller.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLineController.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    final result = await ProfileService.getProfile();
    if (!mounted) return;

    setState(() {
      _isLoadingProfile = false;
      if (result.success && result.data != null) {
        _profile = result.data;
      } else {
        _profileError = result.errorMessage ?? 'Gagal memuat QR profil.';
      }
    });
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;

    setState(() => _selectedTab = index);
    if (index == 0) {
      if (_controller.value.isInitialized) _controller.stop();
    } else {
      _resetScan();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned || _isResolvingScan) return;
    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _hasScanned = true;
      _isResolvingScan = true;
      _rawScannedCode = rawValue;
      _scanResult = null;
      _scanError = null;
    });

    _resolveScan(rawValue);
  }

  void _resolveExternalQr(String rawCode) {
    if (_isResolvingScan) return;

    setState(() {
      _selectedTab = 1;
      _hasScanned = true;
      _isResolvingScan = true;
      _rawScannedCode = rawCode;
      _scanResult = null;
      _scanError = null;
    });

    if (_controller.value.isInitialized) _controller.stop();
    _resolveScan(rawCode);
  }

  Future<void> _resolveScan(String rawCode) async {
    final result = await QrService.scan(rawCode);
    if (!mounted) return;

    setState(() {
      _isResolvingScan = false;
      if (result.success) {
        _scanResult = result;
      } else {
        _scanError = result.errorMessage ?? 'QR tidak ditemukan.';
      }
    });
  }

  void _resetScan() {
    setState(() {
      _hasScanned = false;
      _isResolvingScan = false;
      _rawScannedCode = null;
      _scanResult = null;
      _scanError = null;
    });
    if (_selectedTab == 1 && _controller.value.isInitialized) {
      _controller.start();
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  void _copyQrCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode QR disalin')),
    );
  }

  Future<void> _exportIdCard(ProfileData profile, String qrCode) async {
    if (_isExportingIdCard) return;

    final minePermit = UserLicense.findApprovedMinePermit(profile.licenses);
    if (minePermit == null) {
      await _showMinePermitMissingDialog();
      return;
    }

    setState(() => _isExportingIdCard = true);
    try {
      await IdCardPdfService.exportMinePermit(
        profile: profile,
        qrCode: qrCode,
        minePermit: minePermit,
        tableRows: IdCardPdfService.buildMinePermitTableRows(profile),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF ID Card berhasil dibuat')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF ID Card: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExportingIdCard = false);
    }
  }

  Future<void> _showMinePermitMissingDialog() async {
    const primaryBlue = Color(0xFF1A56C4);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.badge_outlined, color: primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mine Permit Belum Tersedia',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anda belum memiliki Mine Permit yang disetujui. '
              'Silakan ajukan Mine Permit terlebih dahulu untuk dapat '
              'mengekspor ID Card.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: primaryBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pengajuan diproses secara otomatis dari data profil Anda.',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ProfileService.requestMinePermit();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result.message),
                backgroundColor: result.success ? Colors.green : Colors.red,
              ));
              if (result.success) {
                await _loadProfile();
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Ajukan Mine Permit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openUser(ProfileData user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileViewScreen(
          userId: user.id,
          displayName: user.fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        title: const Text(
          'QR Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (_selectedTab == 1)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off,
                color: _torchOn ? const Color(0xFFF9A825) : Colors.black87,
              ),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(height: 1, color: Colors.grey.shade200),
          _buildSegmentedTabs(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _selectedTab == 0 ? _buildMyQrTab() : _buildScannerTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _QrTabButton(
            icon: Icons.qr_code_2,
            label: 'QR Saya',
            selected: _selectedTab == 0,
            onTap: () => _selectTab(0),
          ),
          _QrTabButton(
            icon: Icons.qr_code_scanner,
            label: 'Scan User',
            selected: _selectedTab == 1,
            onTap: () => _selectTab(1),
          ),
        ],
      ),
    );
  }

  Widget _buildMyQrTab() {
    if (_isLoadingProfile) {
      return const Center(
        key: ValueKey('qr-loading'),
        child: CircularProgressIndicator(color: Color(0xFF1A56C4)),
      );
    }

    if (_profileError != null) {
      return _QrMessageState(
        key: const ValueKey('qr-error'),
        icon: Icons.error_outline,
        title: 'QR belum bisa dimuat',
        message: _profileError!,
        buttonLabel: 'Coba Lagi',
        onPressed: _loadProfile,
      );
    }

    final profile = _profile;
    final employeeId = profile?.employeeId.trim() ?? '';
    final qrCode = QrService.userQrCodeFromEmployeeId(employeeId);
    if (profile == null || qrCode.isEmpty) {
      return _QrMessageState(
        key: const ValueKey('qr-empty'),
        icon: Icons.qr_code_2,
        title: 'QR belum tersedia',
        message: 'Employee ID belum tersedia untuk membuat QR profil.',
        buttonLabel: 'Refresh',
        onPressed: _loadProfile,
      );
    }

    return RefreshIndicator(
      key: const ValueKey('my-qr'),
      color: const Color(0xFF1A56C4),
      onRefresh: _loadProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          AppSafeInsets.bottomNavScrollPadding(context, gap: 24),
        ),
        children: [
          _MyQrCard(
            profile: profile,
            qrCode: qrCode,
            qrPayload: QrService.profileDeepLink(qrCode),
            isExporting: _isExportingIdCard,
            onCopy: () => _copyQrCode(qrCode),
            onExport: () => _exportIdCard(
              profile,
              QrService.profileDeepLink(qrCode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Container(
      key: const ValueKey('scan-tab'),
      color: Colors.white,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      CustomPaint(
                        painter: _ScannerFramePainter(),
                      ),
                      if (!_hasScanned)
                        AnimatedBuilder(
                          animation: _scanLineAnimation,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _ScanLinePainter(
                                progress: _scanLineAnimation.value,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!_hasScanned)
            Positioned(
              top: MediaQuery.of(context).size.width + 42,
              left: 24,
              right: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Arahkan kamera ke QR profil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Setelah terbaca, hasilnya muncul di bawah untuk dibuka',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_hasScanned)
            DraggableScrollableSheet(
              initialChildSize: 0.36,
              minChildSize: 0.12,
              maxChildSize: 0.72,
              snap: true,
              snapSizes: const [0.12, 0.36, 0.72],
              builder: (context, scrollController) => SingleChildScrollView(
                controller: scrollController,
                child: _ScanResultSheet(
                  rawCode: _rawScannedCode,
                  isLoading: _isResolvingScan,
                  result: _scanResult,
                  error: _scanError,
                  onReset: _resetScan,
                  onOpenUser: _openUser,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QrTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QrTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A56C4) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyQrCard extends StatelessWidget {
  final ProfileData profile;
  final String qrCode;
  final String qrPayload;
  final bool isExporting;
  final VoidCallback onCopy;
  final VoidCallback onExport;

  const _MyQrCard({
    required this.profile,
    required this.qrCode,
    required this.qrPayload,
    required this.isExporting,
    required this.onCopy,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final photo = profile.profilePhoto;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final initials = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isNotEmpty ? part[0] : '')
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1A56C4),
                backgroundImage: hasPhoto ? NetworkImage(photo) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        initials.isEmpty ? '?' : initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isEmpty ? '-' : profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.employeeId.isEmpty ? '-' : profile.employeeId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.department ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF111827),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD6E4FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 16, color: Color(0xFF1A56C4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    qrCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A56C4),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isExporting ? null : onExport,
              icon: isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label:
                  Text(isExporting ? 'Membuat PDF...' : 'Export ID Card PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56C4),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF9DB7E8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Salin Kode QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A56C4),
                side: const BorderSide(color: Color(0xFF1A56C4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _QrMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56C4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanResultSheet extends StatelessWidget {
  final String? rawCode;
  final bool isLoading;
  final QrScanResult? result;
  final String? error;
  final VoidCallback onReset;
  final ValueChanged<ProfileData> onOpenUser;
  final VoidCallback onClose;

  const _ScanResultSheet({
    required this.rawCode,
    required this.isLoading,
    required this.result,
    required this.error,
    required this.onReset,
    required this.onOpenUser,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final user = result?.user;
    final asset = result?.asset;
    final isSuccess = result?.success == true;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        AppSafeInsets.sheetBottomPadding(context, base: 20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          if (isLoading) ...[
            const CircularProgressIndicator(color: Color(0xFF1A56C4)),
            const SizedBox(height: 16),
            const Text(
              'Mengecek QR...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (rawCode != null) ...[
              const SizedBox(height: 8),
              Text(
                rawCode!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ] else if (user != null) ...[
            _ResultIcon(
              icon: Icons.person,
              color: const Color(0xFF1A56C4),
              background: const Color(0xFFEFF4FF),
            ),
            const SizedBox(height: 12),
            _ResultInfoRow(
              label: 'Nama Lengkap',
              value: user.fullName.isEmpty ? '-' : user.fullName,
            ),
            _ResultInfoRow(
              label: 'NIP',
              value: user.employeeId.isEmpty ? '-' : user.employeeId,
            ),
            const SizedBox(height: 8),
            _ResultInfoRow(
              label: 'Departemen',
              value: user.department ?? '-',
            ),
            _ResultInfoRow(
              label: 'Jabatan',
              value: user.jabatan ?? user.position ?? '-',
            ),
          ] else if (asset != null) ...[
            _ResultIcon(
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF2E7D32),
              background: const Color(0xFFE8F5E9),
            ),
            const SizedBox(height: 12),
            Text(
              asset.assetName.isEmpty ? '-' : asset.assetName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 12),
            _ResultInfoRow(label: 'Tipe', value: asset.assetType),
            _ResultInfoRow(label: 'Lokasi', value: asset.location),
            _ResultInfoRow(label: 'Kondisi', value: asset.condition),
          ] else ...[
            _ResultIcon(
              icon: Icons.error_outline,
              color: const Color(0xFFD32F2F),
              background: const Color(0xFFFFEBEE),
            ),
            const SizedBox(height: 12),
            const Text(
              'QR tidak valid',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'QR tidak ditemukan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan Lagi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A56C4),
                    side: const BorderSide(color: Color(0xFF1A56C4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isSuccess && user != null
                      ? () => onOpenUser(user)
                      : onClose,
                  icon: Icon(
                    isSuccess && user != null
                        ? Icons.person_search
                        : Icons.check,
                    size: 18,
                  ),
                  label: Text(
                      isSuccess && user != null ? 'Lihat Profil' : 'Selesai'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _ResultIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 30),
    );
  }
}

class _ResultInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.58);
    const cutoutSize = 260.0;
    final cutoutLeft = (size.width - cutoutSize) / 2;
    final cutoutTop = (size.height - cutoutSize) / 2;
    final cutout = Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutSize, cutoutSize);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(14)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final inset = size.width * 0.12;
    final scanRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(18)),
      guidePaint,
    );

    const len = 36.0;
    const radius = 16.0;
    final left = scanRect.left;
    final top = scanRect.top;
    final right = scanRect.right;
    final bottom = scanRect.bottom;

    canvas.drawPath(
      Path()
        ..moveTo(left, top + len)
        ..lineTo(left, top + radius)
        ..arcToPoint(Offset(left + radius, top),
            radius: const Radius.circular(radius))
        ..lineTo(left + len, top),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right - len, top)
        ..lineTo(right - radius, top)
        ..arcToPoint(Offset(right, top + radius),
            radius: const Radius.circular(radius))
        ..lineTo(right, top + len),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - len)
        ..lineTo(left, bottom - radius)
        ..arcToPoint(Offset(left + radius, bottom),
            radius: const Radius.circular(radius), clockwise: false)
        ..lineTo(left + len, bottom),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right - len, bottom)
        ..lineTo(right - radius, bottom)
        ..arcToPoint(Offset(right, bottom - radius),
            radius: const Radius.circular(radius), clockwise: false)
        ..lineTo(right, bottom - len),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLinePainter extends CustomPainter {
  final double progress;

  const _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.12;
    final scanRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final y = scanRect.top + scanRect.height * progress;
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0xFF60A5FA),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(scanRect.left, y - 1, scanRect.width, 2))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.18)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(scanRect.left + 10, y),
      Offset(scanRect.right - 10, y),
      glowPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left + 10, y),
      Offset(scanRect.right - 10, y),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 14.0;

    canvas.drawPath(
      Path()
        ..moveTo(0, len + r)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len + r, 0),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - len - r, 0)
        ..lineTo(size.width - r, 0)
        ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
        ..lineTo(size.width, len + r),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len - r)
        ..lineTo(0, size.height - r)
        ..arcToPoint(Offset(r, size.height), radius: const Radius.circular(r))
        ..lineTo(len + r, size.height),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - len - r, size.height)
        ..lineTo(size.width - r, size.height)
        ..arcToPoint(Offset(size.width, size.height - r),
            radius: const Radius.circular(r))
        ..lineTo(size.width, size.height - len - r),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
