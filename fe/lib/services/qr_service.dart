import '../models/profile_model.dart';
import 'api_service.dart';

class QrService {
  static const String deepLinkScheme = 'sapahse';
  static const String deepLinkHost = 'qr';
  static const String userCodePrefix = 'SAPA-HSE-USER-';

  static String userQrCodeFromEmployeeId(String employeeId) {
    final normalizedEmployeeId = employeeId.trim().toUpperCase();
    if (normalizedEmployeeId.isEmpty) return '';
    return '$userCodePrefix$normalizedEmployeeId';
  }

  static String profileDeepLink(String qrCode) {
    final code = qrCode.trim();
    return Uri(
      scheme: deepLinkScheme,
      host: deepLinkHost,
      path: '/scan',
      queryParameters: {'qr_code': code},
    ).toString();
  }

  static String? qrCodeFromDeepLink(String? rawLink) {
    final value = rawLink?.trim();
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != deepLinkScheme ||
        uri.host != deepLinkHost ||
        uri.path != '/scan') {
      return null;
    }

    final qrCode = uri.queryParameters['qr_code']?.trim();
    return qrCode == null || qrCode.isEmpty ? null : qrCode;
  }

  static Future<QrScanResult> scan(String rawCode) async {
    final endpoint = '/qr/scan?qr_code=${Uri.encodeComponent(rawCode)}';
    final response = await ApiService.get(endpoint);

    if (!response.success) {
      return QrScanResult.error(
        response.errorMessage ?? 'QR tidak ditemukan.',
        statusCode: response.statusCode,
      );
    }

    final type = response.data['type']?.toString();
    final data = response.data['data'] as Map<String, dynamic>?;
    if (type == null || data == null) {
      return QrScanResult.error('Respons QR tidak valid.');
    }

    if (type == 'user') {
      return QrScanResult.user(ProfileData.fromJson(data));
    }

    if (type == 'asset') {
      return QrScanResult.asset(QrAssetData.fromJson(data));
    }

    return QrScanResult.error('Jenis QR tidak dikenal.');
  }
}

class QrScanResult {
  final bool success;
  final String? type;
  final ProfileData? user;
  final QrAssetData? asset;
  final String? errorMessage;
  final int? statusCode;

  QrScanResult._({
    required this.success,
    this.type,
    this.user,
    this.asset,
    this.errorMessage,
    this.statusCode,
  });

  factory QrScanResult.user(ProfileData user) => QrScanResult._(
        success: true,
        type: 'user',
        user: user,
      );

  factory QrScanResult.asset(QrAssetData asset) => QrScanResult._(
        success: true,
        type: 'asset',
        asset: asset,
      );

  factory QrScanResult.error(String message, {int? statusCode}) =>
      QrScanResult._(
        success: false,
        errorMessage: message,
        statusCode: statusCode,
      );
}

class QrAssetData {
  final String id;
  final String qrCode;
  final String assetName;
  final String assetType;
  final String location;
  final String condition;
  final String? lastChecked;
  final String? nextCheck;
  final String? notes;

  QrAssetData({
    required this.id,
    required this.qrCode,
    required this.assetName,
    required this.assetType,
    required this.location,
    required this.condition,
    this.lastChecked,
    this.nextCheck,
    this.notes,
  });

  factory QrAssetData.fromJson(Map<String, dynamic> json) {
    return QrAssetData(
      id: json['id']?.toString() ?? '',
      qrCode: json['qr_code']?.toString() ?? '',
      assetName: json['asset_name']?.toString() ?? '',
      assetType: json['asset_type']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
      lastChecked: json['last_checked']?.toString(),
      nextCheck: json['next_check']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}
