/// Matches the formatUser() response from Laravel's AuthController
class UserModel {
  final String id;
  final String nik;
  final String employeeId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? position;
  final String? department;
  final String? profilePhoto;
  final String role;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.nik,
    required this.employeeId,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.position,
    this.department,
    this.profilePhoto,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:           json['id'] as String,
      nik:          json['nik'] as String,
      employeeId:   json['employee_id'] as String,
      fullName:     json['full_name'] as String,
      email:        json['email'] as String,
      phoneNumber:  json['phone_number'] as String?,
      position:     json['position'] as String?,
      department:   json['department'] as String?,
      profilePhoto: json['profile_photo'] as String?,
      role:         json['role'] as String,
      isActive:     json['is_active'] == true || json['is_active'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':            id,
    'nik':           nik,
    'employee_id':   employeeId,
    'full_name':     fullName,
    'email':         email,
    'phone_number':  phoneNumber,
    'position':      position,
    'department':    department,
    'profile_photo': profilePhoto,
    'role':          role,
    'is_active':     isActive,
  };

  bool get isAdmin      => role == 'admin';
  bool get isSupervisor => role == 'supervisor';
  bool get isUser       => role == 'user';
}