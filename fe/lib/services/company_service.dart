import '../models/company_model.dart';
import 'api_service.dart';

class CompanyService {
  // ── Companies ─────────────────────────────────────────────────────────────

  static Future<List<CompanyData>> getCompanies({bool? active, String? category}) async {
    String query = '';
    List<String> params = [];
    if (active != null) params.add('active=$active');
    if (category != null) params.add('category=$category');
    if (params.isNotEmpty) query = '?${params.join('&')}';

    final response = await ApiService.get('/companies$query');
    if (response.success && response.data['data'] != null) {
      final list = response.data['data'] as List;
      return list.map((e) => CompanyData.fromJson(e)).toList();
    }
    throw Exception(response.errorMessage ?? 'Gagal mengambil data perusahaan');
  }

  static Future<CompanyData?> createCompany(String name, String category, {String? code}) async {
    final response = await ApiService.post('/companies', {
      'name': name,
      'category': category,
      if (code != null && code.isNotEmpty) 'code': code,
    });
    if (response.success && response.data['data'] != null) {
      return CompanyData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<CompanyData?> updateCompany(int id, String name, String category, {String? code}) async {
    final response = await ApiService.put('/companies/$id', {
      'name': name,
      'category': category,
      if (code != null && code.isNotEmpty) 'code': code,
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

    final response = await ApiService.get('/areas$query');
    if (response.success && response.data['data'] != null) {
      final list = response.data['data'] as List;
      return list.map((e) => AreaData.fromJson(e)).toList();
    }
    throw Exception(response.errorMessage ?? 'Gagal mengambil data area');
  }

  static Future<AreaData?> createArea(int companyId, String name, {String? code}) async {
    final response = await ApiService.post('/areas', {
      'company_id': companyId,
      'name': name,
      if (code != null && code.isNotEmpty) 'code': code,
    });
    if (response.success && response.data['data'] != null) {
      return AreaData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<AreaData?> updateArea(int id, int companyId, String name, {String? code}) async {
    final response = await ApiService.put('/areas/$id', {
      'company_id': companyId,
      'name': name,
      if (code != null && code.isNotEmpty) 'code': code,
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

  static Future<bool> toggleAreaStatus(int id) async {
    final response = await ApiService.post('/areas/$id/toggle', {});
    return response.success;
  }
}
