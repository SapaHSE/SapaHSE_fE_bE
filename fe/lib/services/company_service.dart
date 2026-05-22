import '../models/company_model.dart';
import '../config/supabase_config.dart';
import 'api_service.dart';
import 'supabase_storage_service.dart';

class CompanyService {
  // ── Companies ─────────────────────────────────────────────────────────────

  static Future<List<CompanyData>> getCompanies({bool? active, String? category}) async {
    String query = '';
    List<String> params = [];
    if (active != null) params.add('active=$active');
    if (category != null) params.add('category=${_normalizeCategory(category)}');
    if (params.isNotEmpty) query = '?${params.join('&')}';

    final response = await ApiService.get('/companies$query', auth: false);
    if (response.success && response.data['data'] != null) {
      final list = response.data['data'] as List;
      return list.map((e) => CompanyData.fromJson(e)).toList();
    }
    throw Exception(response.errorMessage ?? 'Gagal mengambil data perusahaan');
  }

  static Future<CompanyData?> createCompany(
    String name,
    String category, {
    String? code,
    String? logoUrl,
    String? logoImagePath,
    String? kttSignatureUrl,
    String? kttSignatureImagePath,
    String? companyStampUrl,
    String? companyStampImagePath,
    String? kttUserId,
    String? emergencyNumber,
    String? ertFreq,
    String? radioLabel,
    String? radioChannel,
    String? radioFrequency,
  }) async {
    final uploadedLogoUrl = await _uploadCompanyImageIfNeeded(logoImagePath);
    final uploadedKttSignatureUrl =
        await _uploadCompanyImageIfNeeded(kttSignatureImagePath);
    final uploadedCompanyStampUrl =
        await _uploadCompanyImageIfNeeded(companyStampImagePath);
    final response = await ApiService.post('/companies', {
      'name': name,
      'category': _normalizeCategory(category),
      'code': code ?? '',
      'logo_url': uploadedLogoUrl ?? logoUrl ?? '',
      'ktt_signature_url': uploadedKttSignatureUrl ?? kttSignatureUrl ?? '',
      'company_stamp_url': uploadedCompanyStampUrl ?? companyStampUrl ?? '',
      'ktt_user_id': kttUserId ?? '',
      'emergency_number': emergencyNumber ?? '',
      'ert_freq': ertFreq ?? '',
      'radio_label': radioLabel ?? '',
      'radio_channel': radioChannel ?? '',
      'radio_frequency': radioFrequency ?? '',
    });
    if (response.success && response.data['data'] != null) {
      return CompanyData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<CompanyData?> updateCompany(
    int id,
    String name,
    String category, {
    String? code,
    String? logoUrl,
    String? logoImagePath,
    String? kttSignatureUrl,
    String? kttSignatureImagePath,
    String? companyStampUrl,
    String? companyStampImagePath,
    String? kttUserId,
    String? emergencyNumber,
    String? ertFreq,
    String? radioLabel,
    String? radioChannel,
    String? radioFrequency,
  }) async {
    final uploadedLogoUrl = await _uploadCompanyImageIfNeeded(logoImagePath);
    final uploadedKttSignatureUrl =
        await _uploadCompanyImageIfNeeded(kttSignatureImagePath);
    final uploadedCompanyStampUrl =
        await _uploadCompanyImageIfNeeded(companyStampImagePath);
    final response = await ApiService.put('/companies/$id', {
      'name': name,
      'category': _normalizeCategory(category),
      'code': code ?? '',
      'logo_url': uploadedLogoUrl ?? logoUrl ?? '',
      'ktt_signature_url': uploadedKttSignatureUrl ?? kttSignatureUrl ?? '',
      'company_stamp_url': uploadedCompanyStampUrl ?? companyStampUrl ?? '',
      'ktt_user_id': kttUserId ?? '',
      'emergency_number': emergencyNumber ?? '',
      'ert_freq': ertFreq ?? '',
      'radio_label': radioLabel ?? '',
      'radio_channel': radioChannel ?? '',
      'radio_frequency': radioFrequency ?? '',
    });
    if (response.success && response.data['data'] != null) {
      return CompanyData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<bool> deleteCompany(int id) async {
    final response = await ApiService.delete('/companies/$id');
    return response.success;
  }

  static Future<bool> toggleCompanyStatus(int id) async {
    final response = await ApiService.post('/companies/$id/toggle', {});
    return response.success;
  }

  // ── Areas ─────────────────────────────────────────────────────────────────

  static Future<List<AreaData>> getAreas({int? companyId, bool? active}) async {
    String query = '';
    List<String> params = [];
    if (companyId != null) params.add('company_id=$companyId');
    if (active != null) params.add('active=$active');
    if (params.isNotEmpty) query = '?${params.join('&')}';

    final response = await ApiService.get('/areas$query', auth: false);
    if (response.success && response.data['data'] != null) {
      final list = response.data['data'] as List;
      return list.map((e) => AreaData.fromJson(e)).toList();
    }
    throw Exception(response.errorMessage ?? 'Gagal mengambil data area');
  }

  static Future<AreaData?> createArea(
    int companyId,
    String name, {
    String? code,
    String? picUserId,
    List<String>? picUserIds,
  }) async {
    final ids = picUserIds ?? (picUserId != null ? [picUserId] : null);
    final response = await ApiService.post('/areas', {
      'company_id': companyId,
      'name': name,
      if (code != null && code.isNotEmpty) 'code': code,
      if (ids != null) 'pic_user_ids': ids,
    });
    if (response.success && response.data['data'] != null) {
      return AreaData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<AreaData?> updateArea(
    int id,
    int companyId,
    String name, {
    String? code,
    String? picUserId,
    List<String>? picUserIds,
  }) async {
    final ids = picUserIds ?? (picUserId != null ? [picUserId] : null);
    final response = await ApiService.put('/areas/$id', {
      'company_id': companyId,
      'name': name,
      if (code != null && code.isNotEmpty) 'code': code,
      if (ids != null) 'pic_user_ids': ids,
    });
    if (response.success && response.data['data'] != null) {
      return AreaData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<bool> deleteArea(int id) async {
    final response = await ApiService.delete('/areas/$id');
    return response.success;
  }

  static Future<AreaData?> toggleAreaStatus(int id) async {
    final response = await ApiService.post('/areas/$id/toggle', {});
    if (response.success && response.data['data'] != null) {
      return AreaData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<String?> _uploadCompanyImageIfNeeded(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    final uploadedUrl = await SupabaseStorageService.uploadImage(
      imagePath: imagePath,
      folder: SupabaseConfig.companyLogosFolder,
    );
    if (uploadedUrl == null) {
      throw Exception('Gagal mengunggah logo perusahaan ke Supabase.');
    }
    return uploadedUrl;
  }

  static String _normalizeCategory(String category) {
    switch (category) {
      case 'contractor':
        return 'kontraktor';
      case 'sub contractor':
        return 'subkontraktor';
      default:
        return category;
    }
  }
}
