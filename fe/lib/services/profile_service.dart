import 'api_service.dart';
import 'storage_service.dart';

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
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class ProfileData {
  final String id;
  final String employeeId;
  final String fullName;
  final String personalEmail;
  final String? workEmail;
  final String? phoneNumber;
  final String? position;
  final String? department;
  final String? company;
  final String? profilePhoto;
  final String role;
  final bool isActive;
  final List<UserLicense> licenses;
  final List<UserCertification> certifications;
  final List<UserMedical> medicals;

  ProfileData({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.personalEmail,
    this.workEmail,
    this.phoneNumber,
    this.position,
    this.department,
    this.company,
    this.profilePhoto,
    required this.role,
    required this.isActive,
    this.licenses = const [],
    this.certifications = const [],
    this.medicals = const [],
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      personalEmail: json['personal_email']?.toString() ?? '',
      workEmail: json['work_email']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      position: json['position']?.toString(),
      department: json['department']?.toString(),
      company: json['company']?.toString(),
      profilePhoto: json['profile_photo']?.toString(),
      role: json['role']?.toString() ?? 'user',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      licenses: (json['licenses'] as List<dynamic>?)
              ?.map((l) => UserLicense.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((c) => UserCertification.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      medicals: (json['medicals'] as List<dynamic>?)
              ?.map((m) => UserMedical.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get email => workEmail ?? personalEmail;
}

class UserLicense {
  final String id;
  final String name;
  final String licenseNumber;
  final String? expiredAt;
  final String status;

  UserLicense({
    required this.id,
    required this.name,
    required this.licenseNumber,
    this.expiredAt,
    required this.status,
  });

  factory UserLicense.fromJson(Map<String, dynamic> json) {
    return UserLicense(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      licenseNumber: json['license_number']?.toString() ?? '',
      expiredAt: json['expired_at']?.toString(),
      status: json['status']?.toString() ?? 'active',
    );
  }

  bool get isActive => status == 'active';
}

class UserCertification {
  final String id;
  final String name;
  final String issuer;
  final int? year;
  final String status;

  UserCertification({
    required this.id,
    required this.name,
    required this.issuer,
    this.year,
    required this.status,
  });

  factory UserCertification.fromJson(Map<String, dynamic> json) {
    return UserCertification(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      issuer: json['issuer']?.toString() ?? '',
      year: json['year'] as int?,
      status: json['status']?.toString() ?? 'active',
    );
  }

  bool get isActive => status == 'active';
}

class UserMedical {
  final String id;
  final String? checkupDate;
  final String? bloodType;
  final String? height;
  final String? weight;
  final String? bloodPressure;
  final String? allergies;
  final String? result;
  final String? nextCheckupDate;

  UserMedical({
    required this.id,
    this.checkupDate,
    this.bloodType,
    this.height,
    this.weight,
    this.bloodPressure,
    this.allergies,
    this.result,
    this.nextCheckupDate,
  });

  factory UserMedical.fromJson(Map<String, dynamic> json) {
    return UserMedical(
      id: json['id']?.toString() ?? '',
      checkupDate: json['checkup_date']?.toString(),
      bloodType: json['blood_type']?.toString(),
      height: json['height']?.toString(),
      weight: json['weight']?.toString(),
      bloodPressure: json['blood_pressure']?.toString(),
      allergies: json['allergies']?.toString(),
      result: json['result']?.toString(),
      nextCheckupDate: json['next_checkup_date']?.toString(),
    );
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
