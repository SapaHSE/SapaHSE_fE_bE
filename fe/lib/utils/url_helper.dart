import '../services/api_service.dart';

String? normalizeStorageUrl(String? value) {
  if (value == null) return null;

  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  final baseUri = Uri.parse(ApiService.baseUrl);
  final origin = '${baseUri.scheme}://${baseUri.host}'
      '${baseUri.hasPort ? ':${baseUri.port}' : ''}';

  if (uri != null && uri.hasScheme) {
    if (uri.scheme == 'http' && uri.host == baseUri.host) {
      return uri.replace(scheme: baseUri.scheme, port: baseUri.hasPort ? baseUri.port : null).toString();
    }
    return trimmed;
  }

  if (trimmed.startsWith('storage/')) {
    return '$origin/$trimmed';
  }

  return '$origin/storage/$trimmed';
}
