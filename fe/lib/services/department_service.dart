import '../models/department_model.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';

class DepartmentService {
  static Future<List<DepartmentData>> getDepartments() async {
    final response = await ApiService.get(
      '/departments',
      auth: false,
      cachePolicy: ApiCachePolicy.networkFirst,
      cacheGroup: OfflineCacheGroups.references,
    );
    if (response.success && response.data['data'] != null) {
      final list = response.data['data'] as List;
      return list.map((e) => DepartmentData.fromJson(e)).toList();
    }
    throw Exception(response.errorMessage ?? 'Gagal mengambil data departemen');
  }

  static Future<DepartmentData?> createDepartment(String name,
      {bool isHrd = false}) async {
    final response = await ApiService.post('/departments', {
      'name': name,
      'is_hrd': isHrd,
    });
    if (response.success && response.data['data'] != null) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
      return DepartmentData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<DepartmentData?> updateDepartment(int id, String name,
      {bool? isHrd}) async {
    final response = await ApiService.put('/departments/$id', {
      'name': name,
      if (isHrd != null) 'is_hrd': isHrd,
    });
    if (response.success && response.data['data'] != null) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
      return DepartmentData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<bool> deleteDepartment(int id) async {
    final response = await ApiService.delete('/departments/$id');
    if (response.success) {
      await OfflineCacheService.clearGroup(OfflineCacheGroups.references);
    }
    return response.success;
  }
}
