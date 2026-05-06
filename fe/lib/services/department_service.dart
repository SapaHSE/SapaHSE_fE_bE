import '../models/department_model.dart';
import 'api_service.dart';

class DepartmentService {
  static Future<List<DepartmentData>> getDepartments() async {
    final response = await ApiService.get('/departments', auth: false);
    if (response.success && response.data['data'] != null) {
      final list = response.data['data'] as List;
      return list.map((e) => DepartmentData.fromJson(e)).toList();
    }
    throw Exception(response.errorMessage ?? 'Gagal mengambil data departemen');
  }

  static Future<DepartmentData?> createDepartment(String name) async {
    final response = await ApiService.post('/departments', {'name': name});
    if (response.success && response.data['data'] != null) {
      return DepartmentData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<DepartmentData?> updateDepartment(int id, String name) async {
    final response = await ApiService.put('/departments/$id', {'name': name});
    if (response.success && response.data['data'] != null) {
      return DepartmentData.fromJson(response.data['data']);
    }
    return null;
  }

  static Future<bool> deleteDepartment(int id) async {
    final response = await ApiService.delete('/departments/$id');
    return response.success;
  }
}
