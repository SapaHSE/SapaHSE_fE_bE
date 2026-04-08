import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

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

  bool _hasScanned = false;
  bool _torchOn = false;
  String? _scannedResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
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
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() {
      _hasScanned = true;
      _scannedResult = barcode.rawValue!;
    });
    _controller.stop();
  }

  void _reset() {
    setState(() {
      _hasScanned = false;
      _scannedResult = null;
    });
    _controller.start();
  }

  void _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Real Camera feed ───────────────────────────────────────────
          if (!_hasScanned)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),

          // ── Freeze frame when scanned ──────────────────────────────────
          if (_hasScanned)
            Container(color: const Color(0xFF1A1A2E)),

          // ── Dark overlay with scan window cutout ───────────────────────
          if (!_hasScanned)
            CustomPaint(
              size: Size.infinite,
              painter: _ScannerOverlayPainter(),
            ),

          // ── Corner brackets ────────────────────────────────────────────
          if (!_hasScanned)
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: CustomPaint(painter: _CornerPainter()),
              ),
            ),

          // ── Scan instruction ───────────────────────────────────────────
          if (!_hasScanned)
            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: Column(
                children: const [
                  Icon(Icons.qr_code_scanner, color: Colors.white54, size: 28),
                  SizedBox(height: 10),
                  Text(
                    'Arahkan kamera ke QR Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Scan otomatis saat QR terdeteksi',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),

          // ── Result bottom sheet ────────────────────────────────────────
          if (_hasScanned && _scannedResult != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ScanResultSheet(
                result: _scannedResult!,
                onReset: _reset,
                onClose: () => Navigator.pop(context),
              ),
            ),
        ],
      ),
    );
  }
}

// ── RESULT SHEET ──────────────────────────────────────────────────────────────
class _ScanResultSheet extends StatelessWidget {
  final String result;
  final VoidCallback onReset;
  final VoidCallback onClose;

  const _ScanResultSheet({
    required this.result,
    required this.onReset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Success icon
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF1A56C4),
              size: 32,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'QR Berhasil Dipindai!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          const SizedBox(height: 16),

          // Result card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hasil Scan:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  result,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Buttons
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
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Selesai'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── OVERLAY PAINTER ───────────────────────────────────────────────────────────
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
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

// ── CORNER PAINTER ────────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A56C4)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 14.0;

    // Top-left
    canvas.drawPath(
        Path()
          ..moveTo(0, len + r)
          ..lineTo(0, r)
          ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
          ..lineTo(len + r, 0),
        paint);

    // Top-right
    canvas.drawPath(
        Path()
          ..moveTo(size.width - len - r, 0)
          ..lineTo(size.width - r, 0)
          ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
          ..lineTo(size.width, len + r),
        paint);

    // Bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - len - r)
          ..lineTo(0, size.height - r)
          ..arcToPoint(Offset(r, size.height),
              radius: const Radius.circular(r))
          ..lineTo(len + r, size.height),
        paint);

    // Bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(size.width - len - r, size.height)
          ..lineTo(size.width - r, size.height)
          ..arcToPoint(Offset(size.width, size.height - r),
              radius: const Radius.circular(r))
          ..lineTo(size.width, size.height - len - r),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}