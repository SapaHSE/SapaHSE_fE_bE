import '../services/api_service.dart';

String? normalizeStorageUrl(String? value) {
  if (value == null) return null;

  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }

  final baseUri = Uri.parse(ApiService.baseUrl);
  final origin = '${baseUri.scheme}://${baseUri.host}'
      '${baseUri.hasPort ? ':${baseUri.port}' : ''}';

  if (trimmed.startsWith('storage/')) {
    return '$origin/$trimmed';
  }

  return '$origin/storage/$trimmed';
}
