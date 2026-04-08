import 'api_service.dart';
import 'storage_service.dart';
import '../models/user_model.dart';

class ProfileService {
  // ── Get profile from API (always fresh) ──────────────────────────────────
  static Future<ProfileResult> getProfile() async {
    final response = await ApiService.get('/profile');

    if (!response.success) {
      return ProfileResult.error(
          response.errorMessage ?? 'Gagal memuat profil.');
    }

    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return ProfileResult.error('Respons server tidak valid.');
    }

    // Update local cache with fresh data
    await StorageService.saveUser(userData);
    return ProfileResult.success(UserModel.fromJson(userData));
  }

  // ── Update profile (email, phone, position, department) ──────────────────
  static Future<ProfileResult> updateProfile({
    String? email,
    String? phoneNumber,
    String? position,
    String? department,
  }) async {
    final body = <String, dynamic>{};
    if (email != null) body['email'] = email;
    if (phoneNumber != null) body['phone_number'] = phoneNumber;
    if (position != null) body['position'] = position;
    if (department != null) body['department'] = department;

    final response = await ApiService.post('/profile', body);

    if (!response.success) {
      return ProfileResult.error(
          response.errorMessage ?? 'Gagal menyimpan profil.');
    }

    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return ProfileResult.error('Respons server tidak valid.');
    }

    await StorageService.saveUser(userData);
    return ProfileResult.success(UserModel.fromJson(userData));
  }

  // ── Change password ───────────────────────────────────────────────────────
  static Future<SimpleResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword != confirmPassword) {
      return SimpleResult.error('Password baru dan konfirmasi tidak cocok.');
    }
    if (newPassword.length < 6) {
      return SimpleResult.error('Password baru minimal 6 karakter.');
    }

    final response = await ApiService.post('/profile/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': confirmPassword,
    });

    if (!response.success) {
      return SimpleResult.error(
          response.errorMessage ?? 'Gagal mengubah password.');
    }

    return SimpleResult.success(
        response.data['message'] ?? 'Password berhasil diubah.');
  }
}

// ── Result wrappers ───────────────────────────────────────────────────────────
class ProfileResult {
  final bool success;
  final UserModel? user;
  final String? errorMessage;

  ProfileResult._({required this.success, this.user, this.errorMessage});

  factory ProfileResult.success(UserModel user) =>
      ProfileResult._(success: true, user: user);

  factory ProfileResult.error(String message) =>
      ProfileResult._(success: false, errorMessage: message);
}

class SimpleResult {
  final bool success;
  final String message;

  SimpleResult._({required this.success, required this.message});

  factory SimpleResult.success(String message) =>
      SimpleResult._(success: true, message: message);

  factory SimpleResult.error(String message) =>
      SimpleResult._(success: false, message: message);
}
