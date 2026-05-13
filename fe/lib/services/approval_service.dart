import 'api_service.dart';

class ApprovalService {
  static Future<ApiResponse> approveRegistration(String id) {
    return ApiService.put('/admin/users/$id/approve', {});
  }

  static Future<ApiResponse> rejectRegistration(String id, String reason) {
    return ApiService.post('/admin/users/$id/reject', {
      'reason': reason.trim(),
    });
  }

  static Future<ApiResponse> approveLicense(String id) {
    return ApiService.put('/admin/licenses/$id/approve', {});
  }

  static Future<ApiResponse> rejectLicense(String id, String reason) {
    return ApiService.post('/admin/licenses/$id/reject', {
      'reason': reason.trim(),
    });
  }

  static Future<ApiResponse> approveCertification(String id) {
    return ApiService.put('/admin/certifications/$id/approve', {});
  }

  static Future<ApiResponse> rejectCertification(String id, String reason) {
    return ApiService.post('/admin/certifications/$id/reject', {
      'reason': reason.trim(),
    });
  }
}
