import 'package:flutter/material.dart';

class KategoriLaporanScreen extends StatefulWidget {
  const KategoriLaporanScreen({super.key});

  @override
  State<KategoriLaporanScreen> createState() => _KategoriLaporanScreenState();
}

class _KategoriLaporanScreenState extends State<KategoriLaporanScreen> {
  int _selectedTab = 0;

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'TTA', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFD32F2F)},
    {'label': 'KTA', 'icon': Icons.error_outline, 'color': const Color(0xFFF57C00)},
    {'label': 'Subkategori', 'icon': Icons.account_tree_outlined, 'color': const Color(0xFF1976D2)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Kategori Laporan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isSelected = _selectedTab == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = index),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? tab['color'].withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? tab['color'] : Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab['icon'], color: isSelected ? tab['color'] : Colors.grey.shade400, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    tab['label'],
                    style: TextStyle(
                      color: isSelected ? tab['color'] : Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0: return _buildPlaceholder('Kelola daftar Tindakan Tidak Aman (Unsafe Act).');
      case 1: return _buildPlaceholder('Kelola daftar Kondisi Tidak Aman (Unsafe Condition).');
      case 2: return _buildPlaceholder('Kelola subkategori detail untuk setiap temuan bahaya.');
      default: return const SizedBox();
    }
  }

  Widget _buildPlaceholder(String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_tabs[_selectedTab]['icon'], size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(_tabs[_selectedTab]['label'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 32),
            const Text('Feature Coming Soon', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
