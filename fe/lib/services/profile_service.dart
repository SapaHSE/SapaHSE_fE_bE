import 'api_service.dart';
import 'storage_service.dart';
import '../models/profile_model.dart';

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

    await StorageService.saveUser(userData);
    return ProfileResult.success(ProfileData.fromJson(userData));
  }

  // ── Get licenses from profile ────────────────────────────────────────────────────────
  static Future<LicensesResult> getLicenses() async {
    final response = await ApiService.get('/profile');
    if (!response.success) {
      return LicensesResult.error(response.errorMessage ?? 'Gagal memuat lisensi.');
    }
    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return LicensesResult.error('Respons server tidak valid.');
    }
    final licenses = (userData['licenses'] as List<dynamic>?)
            ?.map((l) => UserLicense.fromJson(l as Map<String, dynamic>))
            .toList() ??
        [];
    return LicensesResult.success(licenses);
  }

  // ── Get certifications from profile ──────────────────────────────────────────────
  static Future<CertificationsResult> getCertifications() async {
    final response = await ApiService.get('/profile');
    if (!response.success) {
      return CertificationsResult.error(response.errorMessage ?? 'Gagal memuat sertifikasi.');
    }
    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return CertificationsResult.error('Respons server tidak valid.');
    }
    final certs = (userData['certifications'] as List<dynamic>?)
            ?.map((c) => UserCertification.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    return CertificationsResult.success(certs);
  }

  // ── Get medicals from profile ──────────────────────────────────────────────────────
  static Future<MedicalsResult> getMedicals() async {
    final response = await ApiService.get('/profile');
    if (!response.success) {
      return MedicalsResult.error(response.errorMessage ?? 'Gagal memuat data medis.');
    }
    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return MedicalsResult.error('Respons server tidak valid.');
    }
    final medicals = (userData['medicals'] as List<dynamic>?)
            ?.map((m) => UserMedical.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    return MedicalsResult.success(medicals);
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
    return ProfileResult.success(ProfileData.fromJson(userData));
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

// ══════════════════════════════════════════════════════════════════════════════
// RESULT WRAPPERS
// ══════════════════════════════════════════════════════════════════════════════

class ProfileResult {
  final bool success;
  final ProfileData? data;
  final String? errorMessage;

  ProfileResult._({required this.success, this.data, this.errorMessage});

  factory ProfileResult.success(ProfileData data) =>
      ProfileResult._(success: true, data: data);

  factory ProfileResult.error(String message) =>
      ProfileResult._(success: false, errorMessage: message);
}

class LicensesResult {
  final bool success;
  final List<UserLicense> licenses;
  final String? errorMessage;

  LicensesResult._({required this.success, this.licenses = const [], this.errorMessage});

  factory LicensesResult.success(List<UserLicense> licenses) =>
      LicensesResult._(success: true, licenses: licenses);

  factory LicensesResult.error(String message) =>
      LicensesResult._(success: false, errorMessage: message);
}

class CertificationsResult {
  final bool success;
  final List<UserCertification> certifications;
  final String? errorMessage;

  CertificationsResult._({required this.success, this.certifications = const [], this.errorMessage});

  factory CertificationsResult.success(List<UserCertification> certifications) =>
      CertificationsResult._(success: true, certifications: certifications);

  factory CertificationsResult.error(String message) =>
      CertificationsResult._(success: false, errorMessage: message);
}

class MedicalsResult {
  final bool success;
  final List<UserMedical> medicals;
  final String? errorMessage;

  MedicalsResult._({required this.success, this.medicals = const [], this.errorMessage});

  factory MedicalsResult.success(List<UserMedical> medicals) =>
      MedicalsResult._(success: true, medicals: medicals);

  factory MedicalsResult.error(String message) =>
      MedicalsResult._(success: false, errorMessage: message);
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
