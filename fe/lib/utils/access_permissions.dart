import 'dart:convert';

import 'value_parser.dart';

class AccessPermissionOption {
  final String key;
  final String label;
  final String description;

  const AccessPermissionOption({
    required this.key,
    required this.label,
    required this.description,
  });
}

const List<AccessPermissionOption> accessPermissionOptions = [
  AccessPermissionOption(
    key: 'dashboard_overview',
    label: 'Dashboard Overview',
    description: 'Melihat ringkasan statistik dashboard.',
  ),
  AccessPermissionOption(
    key: 'manage_hazard_reports',
    label: 'Manajemen Hazard',
    description: 'Mengelola laporan hazard dari dashboard.',
  ),
  AccessPermissionOption(
    key: 'manage_inspection_reports',
    label: 'Manajemen Inspection',
    description: 'Mengelola laporan inspeksi dari dashboard.',
  ),
  AccessPermissionOption(
    key: 'manage_news',
    label: 'Berita',
    description: 'Membuat dan mengatur berita HSE.',
  ),
  AccessPermissionOption(
    key: 'manage_announcements',
    label: 'Pengumuman',
    description: 'Membuat pengumuman biasa atau urgent.',
  ),
  AccessPermissionOption(
    key: 'manage_users',
    label: 'User Management',
    description: 'Mengelola akun, role, status, dan akses user.',
  ),
  AccessPermissionOption(
    key: 'document_approvals',
    label: 'Approval Dokumen',
    description: 'Memproses lisensi, sertifikasi, dan perubahan profil.',
  ),
  AccessPermissionOption(
    key: 'manage_master_data',
    label: 'Master Data',
    description: 'Mengelola company, department, lokasi, dan kategori.',
  ),
  AccessPermissionOption(
    key: 'manage_violations',
    label: 'Violation & Incident',
    description: 'Mengelola violation dan incident user.',
  ),
];

const List<String> accessPermissionKeys = [
  'dashboard_overview',
  'manage_hazard_reports',
  'manage_inspection_reports',
  'manage_news',
  'manage_announcements',
  'manage_users',
  'document_approvals',
  'manage_master_data',
  'manage_violations',
];

Map<String, bool> defaultAccessPermissionsForRole(String? role) {
  final permissions = {
    for (final key in accessPermissionKeys) key: false,
  };
  final normalizedRole = role?.trim().toLowerCase() ?? '';

  if (normalizedRole == 'superadmin' || normalizedRole == 'super admin') {
    return {
      for (final key in accessPermissionKeys) key: true,
    };
  }

  if (normalizedRole == 'admin') {
    for (final key in [
      'dashboard_overview',
      'manage_hazard_reports',
      'manage_inspection_reports',
      'manage_news',
      'manage_announcements',
      'manage_users',
      'document_approvals',
      'manage_violations',
    ]) {
      permissions[key] = true;
    }
  }

  return permissions;
}

Map<String, bool> normalizeAccessPermissions(
  dynamic raw, {
  String? role,
}) {
  final normalized = defaultAccessPermissionsForRole(role);
  final normalizedRole = role?.trim().toLowerCase() ?? '';
  if (normalizedRole == 'superadmin' || normalizedRole == 'super admin') {
    return normalized;
  }

  dynamic source = raw;

  if (source is String && source.trim().isNotEmpty) {
    try {
      source = jsonDecode(source);
    } catch (_) {
      source = null;
    }
  }

  if (source is Map) {
    source.forEach((key, value) {
      final permissionKey = key.toString();
      if (normalized.containsKey(permissionKey)) {
        normalized[permissionKey] = parseFlexibleBool(value);
      }
    });
  }

  return normalized;
}

bool userHasAccess(Map<String, dynamic>? user, String permissionKey) {
  if (user == null) return false;
  final role = user['role']?.toString();
  return normalizeAccessPermissions(
        user['access_permissions'],
        role: role,
      )[permissionKey] ??
      false;
}

bool userHasAnyAccess(Map<String, dynamic>? user, Iterable<String> keys) {
  return keys.any((key) => userHasAccess(user, key));
}
