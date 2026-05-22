import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/profile_model.dart';
import '../services/id_card_pdf_service.dart';
import '../services/profile_service.dart';
import '../services/qr_service.dart';
import '../widgets/app_safe_insets.dart';
import 'user_profile_view_screen.dart';

bool _isSvgUrl(String value) {
  final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
  return path.endsWith('.svg');
}

class QrScanScreen extends StatefulWidget {
  final String? initialQrCode;

  const QrScanScreen({super.key, this.initialQrCode});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  int _selectedTab = 0;
  bool _torchOn = false;
  bool _hasScanned = false;
  bool _isResolvingScan = false;
  String? _rawScannedCode;
  String? _scanError;
  QrScanResult? _scanResult;

  bool _isLoadingProfile = true;
  bool _isExportingIdCard = false;
  String? _profileError;
  ProfileData? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    _controller.stop();
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

    final tableRows = await _showMinePermitReview(profile, qrCode, minePermit);
    if (tableRows == null || !mounted) return;

    setState(() => _isExportingIdCard = true);
    try {
      await IdCardPdfService.exportMinePermit(
        profile: profile,
        qrCode: qrCode,
        minePermit: minePermit,
        tableRows: tableRows,
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mine Permit Belum Tersedia'),
        content: const Text(
          'Anda belum memiliki Mine Permit yang disetujui. '
          'Silakan ajukan Mine Permit terlebih dahulu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
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
            child: const Text('Ajukan Mine Permit'),
          ),
        ],
      ),
    );
  }

  Future<List<MinePermitTableRow>?> _showMinePermitReview(
    ProfileData profile,
    String qrCode,
    UserLicense minePermit,
  ) async {
    final rows = IdCardPdfService.buildMinePermitTableRows(profile);
    return showModalBottomSheet<List<MinePermitTableRow>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MinePermitReviewSheet(
        profile: profile,
        qrCode: qrCode,
        minePermit: minePermit,
        initialRows: rows,
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
        foregroundColor: Colors.black87,
        elevation: 0,
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
      color: Colors.black,
      child: Stack(
        children: [
          if (!_hasScanned)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          if (_hasScanned) Container(color: const Color(0xFF111827)),
          if (!_hasScanned)
            CustomPaint(
              size: Size.infinite,
              painter: _ScannerOverlayPainter(),
            ),
          if (!_hasScanned)
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: CustomPaint(painter: _CornerPainter()),
              ),
            ),
          if (!_hasScanned)
            Positioned(
              bottom: 150,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white70,
                    size: 28,
                  ),
                  const SizedBox(height: 10),
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
                    'Hasil scan akan dicek otomatis',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (_hasScanned)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
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
        ],
      ),
    );
  }
}

class _MinePermitReviewSheet extends StatefulWidget {
  final ProfileData profile;
  final String qrCode;
  final UserLicense minePermit;
  final List<MinePermitTableRow> initialRows;

  const _MinePermitReviewSheet({
    required this.profile,
    required this.qrCode,
    required this.minePermit,
    required this.initialRows,
  });

  @override
  State<_MinePermitReviewSheet> createState() => _MinePermitReviewSheetState();
}

class _MinePermitReviewSheetState extends State<_MinePermitReviewSheet> {
  late final List<TextEditingController> _vehicleControllers;

  @override
  void initState() {
    super.initState();
    _vehicleControllers = widget.initialRows
        .map((row) => TextEditingController(text: row.vehicleEquipment))
        .toList();
    for (final controller in _vehicleControllers) {
      controller.addListener(_refreshPreview);
    }
  }

  @override
  void dispose() {
    for (final controller in _vehicleControllers) {
      controller
        ..removeListener(_refreshPreview)
        ..dispose();
    }
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  List<MinePermitTableRow> get _editedRows {
    return [
      for (var i = 0; i < widget.initialRows.length; i++)
        MinePermitTableRow(
          code: widget.initialRows[i].code,
          vehicleEquipment: _vehicleControllers[i].text.trim(),
          licenseNumber: widget.initialRows[i].licenseNumber,
          issuedDate: widget.initialRows[i].issuedDate,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(
                        Icons.image_search_outlined,
                        color: Color(0xFF1A56C4),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Preview Mine Permit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                children: [
                  _MinePermitPreviewPair(
                    profile: widget.profile,
                    qrCode: widget.qrCode,
                    minePermit: widget.minePermit,
                    rows: _editedRows,
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(widget.initialRows.length, (index) {
                    final row = widget.initialRows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MinePermitEditRow(
                        row: row,
                        controller: _vehicleControllers[index],
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                8,
                14,
                AppSafeInsets.sheetBottomPadding(context, base: 14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, _editedRows),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Download PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56C4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
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

class _MinePermitPreviewPair extends StatelessWidget {
  final ProfileData profile;
  final String qrCode;
  final UserLicense minePermit;
  final List<MinePermitTableRow> rows;

  const _MinePermitPreviewPair({
    required this.profile,
    required this.qrCode,
    required this.minePermit,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 540 ? 245.0 : 260.0;
        final cards = [
          _MinePermitFrontPreview(
            profile: profile,
            minePermit: minePermit,
            width: cardWidth,
          ),
          _MinePermitBackPreview(
            profile: profile,
            rows: rows,
            width: cardWidth,
          ),
        ];

        if (constraints.maxWidth >= 540) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cards[0],
              const SizedBox(width: 14),
              cards[1],
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
          ],
        );
      },
    );
  }
}

class _MinePermitFrontPreview extends StatelessWidget {
  final ProfileData profile;
  final UserLicense minePermit;
  final double width;

  const _MinePermitFrontPreview({
    required this.profile,
    required this.minePermit,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final position = profile.jabatan ?? profile.position ?? '';
    final department = profile.department ?? '';
    final logoUrl = profile.companyDetail?.logoUrl?.trim() ?? '';

    return _PreviewCardFrame(
      width: width,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 10,
            child: Center(
              child: SizedBox(
                width: 136,
                height: 36,
                child: logoUrl.isNotEmpty
                    ? (_isSvgUrl(logoUrl)
                        ? SvgPicture.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            placeholderBuilder: (_) =>
                                _companyTextHeader(profile),
                          )
                        : Image.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _companyTextHeader(profile),
                          ))
                    : _companyTextHeader(profile),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 58,
            child: Container(
              height: 31,
              color: const Color(0xFF2F73C8),
              alignment: Alignment.center,
              child: const Text(
                'MINE PERMIT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 103,
            child: Container(
              width: 98,
              height: 128,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0F7),
                border: Border.all(color: const Color(0xFF9BA7B8)),
              ),
              child: Text(
                _initials(profile.fullName),
                style: const TextStyle(
                  color: Color(0xFF245A9C),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          Positioned(
            left: 130,
            top: 104,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _frontInfo('Name', profile.fullName),
                _frontInfo(
                  'Employee ID',
                  profile.employeeId,
                ),
                _frontInfo('Position', position),
                _frontInfo('Department', department),
                _frontInfo(
                  'Company',
                  _affiliationCompanyName(profile),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 38,
            top: 254,
            child: _AccessTypePreview(),
          ),
          Positioned(
            left: 22,
            bottom: 22,
            child: _MiniSignaturePreview(profile: profile),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 1,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniCounterPreview('VIOLATION'),
                  SizedBox(width: 20),
                  _MiniCounterPreview('INCIDENT'),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 20,
            child: Column(
              children: [
                const Icon(Icons.qr_code_2, size: 72),
                const SizedBox(height: 4),
                const Text(
                  'Valid Until',
                  style: TextStyle(
                    color: Color(0xFF2F73C8),
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  IdCardPdfService.formatExpiry(minePermit.expiredAt),
                  style: const TextStyle(
                    color: Color(0xFF245A9C),
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _frontInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF2F73C8),
              fontSize: 6.5,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF303744),
              fontSize: 7.7,
              fontWeight: FontWeight.bold,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  static String _companyShort(String? company) {
    final value = (company ?? '').toLowerCase();
    if (value.contains('khotai')) return 'KHOTAI';
    return 'BBE';
  }

  static String _affiliationCompanyName(ProfileData profile) {
    final affiliation = (profile.tipeAfiliasi ?? '').toLowerCase();
    final contractor = profile.perusahaanKontraktor?.trim() ?? '';
    final subcontractor = profile.subKontraktor?.trim() ?? '';
    final owner = profile.companyDetail?.name ??
        profile.company ??
        'PT Bukit Baiduri Energi';

    if (affiliation.contains('sub') && subcontractor.isNotEmpty) {
      return subcontractor;
    }
    if (affiliation.contains('kontraktor') && contractor.isNotEmpty) {
      return contractor;
    }
    return owner;
  }

  static Widget _companyTextHeader(ProfileData profile) {
    final companyName = profile.companyDetail?.name ??
        profile.company ??
        'PT Bukit Baiduri Energi';
    final shortText = profile.companyDetail?.code ?? _companyShort(companyName);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          shortText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Color(0xFF303744),
            height: 0.95,
          ),
        ),
        Text(
          companyName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 5.5),
        ),
      ],
    );
  }
}

class _MinePermitBackPreview extends StatelessWidget {
  final ProfileData profile;
  final List<MinePermitTableRow> rows;
  final double width;

  const _MinePermitBackPreview({
    required this.profile,
    required this.rows,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final companyName =
        profile.companyDetail?.name ?? profile.company ?? 'perusahaan';
    final emergencyContact = _companyEmergencyContactText(profile);

    return _PreviewCardFrame(
      width: width,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Text(
              'SIMPER',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF28B463),
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            left: 5,
            right: 5,
            top: 68,
            child: _previewTable(rows),
          ),
          Positioned(
            left: 5,
            right: 5,
            top: 240,
            child: Container(height: 1, color: Colors.grey.shade400),
          ),
          Positioned(
            left: 6,
            right: 6,
            top: 243,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catatan:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                _rulePreview(
                  '1. Kartu ini harus dipakai selama berada di area kerja dan digunakan sebatas izin akses ke area pertambangan.',
                ),
                _rulePreview(
                  '2. Kartu ini milik $companyName, pemegang kartu wajib mengembalikan kartu ini jika habis masa berlaku.',
                ),
                _rulePreview(
                    '3. Segera laporkan ke QHSE jika kehilangan kartu ini.'),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 292,
            child: Container(
              height: 18,
              color: const Color(0xFFE5506A),
              alignment: Alignment.center,
              child: Text(
                emergencyContact.isEmpty
                    ? 'EMERGENCY CONTACT'
                    : 'EMERGENCY CONTACT: $emergencyContact',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 6.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 23,
              color: const Color(0xFF28B463),
              alignment: Alignment.center,
              child: const Text(
                'WAJIB MEMATUHI PERATURAN K3LH\nSELAMA BERADA DI JOB SITE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _companyEmergencyContactText(ProfileData profile) {
    final emergency = profile.companyDetail?.emergencyNumber?.trim() ?? '';
    final radio = [
      profile.companyDetail?.radioLabel,
      profile.companyDetail?.radioChannel,
      profile.companyDetail?.radioFrequency ??
          profile.companyDetail?.ertFreq,
    ]
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' ');
    return [
      if (emergency.isNotEmpty) emergency,
      if (radio.isNotEmpty) radio,
    ].join(' | ');
  }

  static Widget _previewTable(List<MinePermitTableRow> rows) {
    const border = BorderSide(color: Color(0xFF9BA7B8), width: 0.7);
    return Table(
      border: TableBorder.all(color: border.color, width: border.width),
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(3.05),
        2: FlexColumnWidth(0.55),
        3: FlexColumnWidth(1.2),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFF2F73C8)),
          children: [
            _PreviewHeader(''),
            _PreviewHeader('VEHICLE / EQUIPMENT'),
            _PreviewHeader('LIC'),
            _PreviewHeader('EXP DATE'),
          ],
        ),
        ...rows.map(
          (row) => TableRow(
            children: [
              _PreviewCell(row.code, bold: true),
              _PreviewCell(row.vehicleEquipment),
              _PreviewCell(row.licenseNumber),
              _PreviewCell(row.issuedDate),
            ],
          ),
        ),
      ],
    );
  }

}

class _PreviewCardFrame extends StatelessWidget {
  final double width;
  final Widget child;

  const _PreviewCardFrame({
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 55 / 86,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF4F5E70), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MiniCounterPreview extends StatelessWidget {
  final String title;

  const _MiniCounterPreview(this.title);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF245A9C),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          Table(
            border: TableBorder.all(
              color: const Color(0xFF9BA7B8),
              width: 0.7,
            ),
            children: const [
              TableRow(
                children: [
                  _PreviewCell('1', bold: true),
                  _PreviewCell('2', bold: true),
                  _PreviewCell('3', bold: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSignaturePreview extends StatelessWidget {
  final ProfileData profile;

  const _MiniSignaturePreview({required this.profile});

  @override
  Widget build(BuildContext context) {
    final logoUrl = profile.companyDetail?.logoUrl?.trim() ?? '';
    final kttSignatureUrl =
        profile.companyDetail?.kttSignatureUrl?.trim() ?? '';
    final companyStampUrl = profile.companyDetail?.companyStampUrl?.trim() ?? '';
    final kttName =
        profile.companyDetail?.kttUser?.fullName ?? 'Reno Barus, S.T';
    final companyCode = profile.companyDetail?.code ??
        _MinePermitFrontPreview._companyShort(profile.company);

    return SizedBox(
      width: 92,
      child: Column(
        children: [
          const Text(
            'Disahkan oleh,',
            style: TextStyle(
              color: Color(0xFF245A9C),
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            width: 55,
            height: 10,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF245A9C), width: 1),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            height: 14,
            child: Row(
              children: [
                Expanded(
                  child: _signatureImage(
                    kttSignatureUrl,
                    fallback: logoUrl.isNotEmpty
                        ? _signatureImage(
                            logoUrl,
                            fallback: _signatureCode(companyCode),
                          )
                        : _signatureCode(companyCode),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _signatureImage(
                    companyStampUrl,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          Text(
            kttName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 6.2, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Kepala Teknik Tambang',
            style: TextStyle(fontSize: 5.8, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  static Widget _signatureCode(String value) {
    return Center(
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF303744),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Widget _signatureImage(String url, {required Widget fallback}) {
  if (url.isEmpty) return fallback;
  return _isSvgUrl(url)
      ? SvgPicture.network(
          url,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => fallback,
        )
      : Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        );
}

class _AccessTypePreview extends StatelessWidget {
  const _AccessTypePreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          const Text(
            'ACCESS TYPE',
            style: TextStyle(
              color: Color(0xFF245A9C),
              fontSize: 5.6,
              fontWeight: FontWeight.bold,
            ),
          ),
          Table(
            border: TableBorder.all(
              color: const Color(0xFF9BA7B8),
              width: 0.4,
            ),
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(),
              4: FlexColumnWidth(),
            },
            children: const [
              TableRow(
                children: [
                  _AccessTypeCell('T1'),
                  _AccessTypeCell('T2'),
                  _AccessTypeCell('T3'),
                  _AccessTypeCell('T4'),
                  _AccessTypeCell('T5'),
                ],
              ),
              TableRow(
                children: [
                  _AccessTypeCell(''),
                  _AccessTypeCell(''),
                  _AccessTypeCell(''),
                  _AccessTypeCell(''),
                  _AccessTypeCell(''),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessTypeCell extends StatelessWidget {
  final String text;

  const _AccessTypeCell(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7.2,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 5.2,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}

Widget _rulePreview(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF303744),
        fontSize: 7.1,
        height: 1.05,
      ),
    ),
  );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final chars = parts
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
  return chars.isEmpty ? '?' : chars;
}

class _MinePermitEditRow extends StatelessWidget {
  final MinePermitTableRow row;
  final TextEditingController controller;

  const _MinePermitEditRow({
    required this.row,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              row.code,
              style: const TextStyle(
                color: Color(0xFF1A56C4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Vehicle / Equipment',
                hintText: 'Isi manual jika perlu',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
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

class _PreviewHeader extends StatelessWidget {
  final String text;

  const _PreviewHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Text(
        text,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 5.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PreviewCell extends StatelessWidget {
  final String text;
  final bool bold;

  const _PreviewCell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: text.length > 14 ? 6 : 7,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        ),
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
            Text(
              user.fullName.isEmpty ? '-' : user.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              user.employeeId.isEmpty ? '-' : user.employeeId,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
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
