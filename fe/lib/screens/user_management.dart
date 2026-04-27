import 'package:flutter/material.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  int _selectedTab = 0;

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Roles & Permissions', 'icon': Icons.admin_panel_settings, 'color': const Color(0xFF1565C0)},
    {'label': 'User List', 'icon': Icons.people_alt, 'color': const Color(0xFF2E7D32)},
    {'label': 'Approval Workflow', 'icon': Icons.assignment_turned_in, 'color': const Color(0xFFF57C00)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      tab['label'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? tab['color'] : Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
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
      case 0: return _buildPlaceholder('Manage system roles and their specific access permissions.');
      case 1: return _buildPlaceholder('View and manage all registered users in the system.');
      case 2: return _buildPlaceholder('Configure multi-level approval steps for reporting.');
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
            const Text('Feature Coming Soon', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
