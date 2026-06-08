import '../utils/url_helper.dart';
import '../utils/value_parser.dart';

/// Matches the formatUser() response from Laravel's AuthController
class UserModel {
  final String id;
  final String nik;
  final String employeeId;
  final String fullName;
  final String email;
  final String? personalEmail;
  final String? workEmail;
  final String? phoneNumber;
  final String? position;
  final String? jabatan;
  final String? department;
  final String? company;
  final String? profilePhoto;
  final String role;
  final bool isActive;
  final bool isHrdReviewer;

  const UserModel({
    required this.id,
    required this.nik,
    required this.employeeId,
    required this.fullName,
    required this.email,
    this.personalEmail,
    this.workEmail,
    this.phoneNumber,
    this.position,
    this.jabatan,
    this.department,
    this.company,
    this.profilePhoto,
    required this.role,
    required this.isActive,
    this.isHrdReviewer = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      nik: json['nik']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      personalEmail:
          json['personal_email']?.toString() ?? json['email']?.toString(),
      workEmail: json['work_email']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      position: json['position']?.toString(),
      jabatan: json['jabatan']?.toString(),
      department: json['department']?.toString(),
      company: json['company']?.toString(),
      profilePhoto: normalizeStorageUrl(json['profile_photo']?.toString()),
      role: json['role']?.toString() ?? 'user',
      isActive: parseFlexibleBool(json['is_active']),
      isHrdReviewer: parseFlexibleBool(json['is_hrd_reviewer']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nik': nik,
        'employee_id': employeeId,
        'full_name': fullName,
        'email': email,
        'personal_email': personalEmail,
        'work_email': workEmail,
        'phone_number': phoneNumber,
        'position': position,
        'jabatan': jabatan,
        'department': department,
        'company': company,
        'profile_photo': profilePhoto,
        'role': role,
        'is_active': isActive,
        'is_hrd_reviewer': isHrdReviewer,
      };

  bool get isAdmin => role == 'admin';
  bool get isSuperadmin => role == 'superadmin';
  bool get isSupervisor => role == 'supervisor';
  bool get isUser => role == 'user';
  bool get isHrd => isHrdReviewer;

  /// Roles that have full read access across all reports (admin + superadmin).
  /// Note: ability to *update* status is gated separately — only `isAdmin` can update,
  /// `isSuperadmin` is read-only.
  bool get hasFullReadAccess => isAdmin || isSuperadmin;
}
