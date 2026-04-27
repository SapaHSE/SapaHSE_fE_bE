import '../utils/url_helper.dart';

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
  final String? department;
  final String? company;
  final String? profilePhoto;
  final String role;
  final bool isActive;

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
    this.department,
    this.company,
    this.profilePhoto,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      nik: json['nik']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      personalEmail: json['personal_email']?.toString() ?? json['email']?.toString(),
      workEmail: json['work_email']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      position: json['position']?.toString(),
      department: json['department']?.toString(),
      company: json['company']?.toString(),
      profilePhoto: normalizeStorageUrl(json['profile_photo']?.toString()),
      role: json['role']?.toString() ?? 'user',
      isActive: json['is_active'] == true || json['is_active'] == 1,
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
        'department': department,
        'company': company,
        'profile_photo': profilePhoto,
        'role': role,
        'is_active': isActive,
      };

  bool get isAdmin      => role == 'admin';
  bool get isSupervisor => role == 'supervisor';
  bool get isUser       => role == 'user';
}
