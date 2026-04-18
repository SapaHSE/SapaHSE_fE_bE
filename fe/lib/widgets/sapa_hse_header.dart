import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/cloud_save_service.dart';
import '../screens/cloud_save_screen.dart';

class SapaHseHeader extends StatefulWidget {
  final bool isSearching;
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onSearchToggle;
  final bool showSearch;
  final bool showCloudSave;

  const SapaHseHeader({
    super.key,
    required this.isSearching,
    this.searchController,
    this.searchHint = 'Cari...',
    this.onSearchChanged,
    required this.onSearchToggle,
    this.showSearch = true,
    this.showCloudSave = true,
  });

  @override
  State<SapaHseHeader> createState() => _SapaHseHeaderState();
}

class _SapaHseHeaderState extends State<SapaHseHeader>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1A56C4);

  int _draftCount = 0;
  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectSub;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initConnectivity();
    _loadDraftCount();

    _connectSub =
        CloudSaveService.instance.connectivityStream.listen((results) async {
      final online = await CloudSaveService.isOnline();
      if (mounted) setState(() => _isOnline = online);
      _loadDraftCount(); // refresh count when connectivity changes
    });
  }

  Future<void> _initConnectivity() async {
    _isOnline = await CloudSaveService.isOnline();
    if (mounted) setState(() {});
  }

  Future<void> _loadDraftCount() async {
    final count = await CloudSaveService.instance.getDraftCount();
    if (mounted) setState(() => _draftCount = count);
  }

  @override
  void dispose() {
    _connectSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _openCloudSave() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CloudSaveScreen()),
    );
    // Refresh draft count when returning from CloudSaveScreen
    _loadDraftCount();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F8F8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!widget.isSearching) ...[
            // ── Logo ─────────────────────────────────────────────────────
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SapaHse',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _blue,
                  ),
                ),
                Text(
                  'PT. Bukit Baiduri Energi',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
          ] else ...[
            Expanded(
              child: TextField(
                controller: widget.searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: widget.onSearchChanged,
              ),
            ),
          ],

          // ── Cloud Save Icon ───────────────────────────────────────────
          if (widget.showCloudSave && !widget.isSearching)
            _CloudSaveIconButton(
              draftCount: _draftCount,
              isOnline: _isOnline,
              pulseAnim: _pulseAnim,
              onTap: _openCloudSave,
            ),

          // ── Search Toggle ─────────────────────────────────────────────
          if (widget.showSearch)
            IconButton(
              icon: Icon(
                widget.isSearching ? Icons.close : Icons.search,
                color: Colors.grey,
              ),
              onPressed: widget.onSearchToggle,
            ),
        ],
      ),
    );
  }
}

// ── Cloud Save Icon Button ────────────────────────────────────────────────────
class _CloudSaveIconButton extends StatelessWidget {
  final int draftCount;
  final bool isOnline;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _CloudSaveIconButton({
    required this.draftCount,
    required this.isOnline,
    required this.pulseAnim,
    required this.onTap,
  });

  static const _blue = Color(0xFF1A56C4);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: draftCount > 0
          ? '$draftCount laporan belum terkirim'
          : 'Cloud Save',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: draftCount > 0
                    ? const Color(0xFFEFF4FF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: draftCount > 0 && !isOnline
                    // Pulsing offline icon
                    ? FadeTransition(
                        opacity: pulseAnim,
                        child: const Icon(
                          Icons.cloud_off_outlined,
                          color: Color(0xFFFF9800),
                          size: 22,
                        ),
                      )
                    : Icon(
                        draftCount > 0
                            ? Icons.cloud_upload_outlined
                            : Icons.cloud_outlined,
                        color: draftCount > 0 ? _blue : Colors.grey,
                        size: 22,
                      ),
              ),
            ),

            // Badge: draft count
            if (draftCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? _blue
                        : const Color(0xFFFF9800),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFF8F8F8), width: 1.5),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    draftCount > 99 ? '99+' : '$draftCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}