bool parseFlexibleBool(
  dynamic value, {
  bool defaultValue = false,
}) {
  if (value == null) return defaultValue;

  if (value is bool) return value;
  if (value is num) return value != 0;

  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return defaultValue;

    const truthy = {'1', 'true', 'yes', 'y', 'aktif', 'active', 'on'};
    const falsy = {'0', 'false', 'no', 'n', 'nonaktif', 'inactive', 'off'};

    if (truthy.contains(normalized)) return true;
    if (falsy.contains(normalized)) return false;
  }

  return defaultValue;
}

String? parseNullableDisplayName(dynamic value) {
  if (value == null) return null;
  final parsed = value.toString().trim();
  return parsed.isEmpty ? null : parsed;
}
