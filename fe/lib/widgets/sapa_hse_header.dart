import 'package:flutter/material.dart';

class SapaHseHeader extends StatelessWidget {
  final bool isSearching;
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onSearchToggle;
  final bool showSearch;

  const SapaHseHeader({
    super.key,
    required this.isSearching,
    this.searchController,
    this.searchHint = 'Cari...',
    this.onSearchChanged,
    required this.onSearchToggle,
    this.showSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F8F8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (!isSearching) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A56C4),
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
                    color: Color(0xFF1A56C4),
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
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: searchHint,
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: onSearchChanged,
              ),
            ),
          ],
          if (showSearch)
            IconButton(
              icon: Icon(
                isSearching ? Icons.close : Icons.search,
                color: Colors.grey,
              ),
              onPressed: onSearchToggle,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }
}