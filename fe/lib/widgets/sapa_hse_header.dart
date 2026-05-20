import 'package:flutter/material.dart';

import '../services/background_sync_service.dart';

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F8F8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!widget.isSearching) ...[
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
          if (widget.showCloudSave && !widget.isSearching)
            ValueListenableBuilder<bool>(
              valueListenable: BackgroundSyncService.instance.isOnline,
              builder: (_, isOnline, __) => _ConnectionIndicatorButton(
                isOnline: isOnline,
                pulseAnim: _pulseAnim,
              ),
            ),
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

class _ConnectionIndicatorButton extends StatelessWidget {
  final bool isOnline;
  final Animation<double> pulseAnim;

  const _ConnectionIndicatorButton({
    required this.isOnline,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isOnline ? 'Koneksi online' : 'Koneksi offline',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isOnline ? Colors.transparent : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: isOnline
              ? const Icon(
                  Icons.cloud_done_outlined,
                  color: Color(0xFF2E7D32),
                  size: 22,
                )
              : FadeTransition(
                  opacity: pulseAnim,
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    color: Color(0xFFFF9800),
                    size: 22,
                  ),
                ),
        ),
      ),
    );
  }
}
