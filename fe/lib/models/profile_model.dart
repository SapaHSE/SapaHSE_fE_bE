import 'dart:convert';

/// Profile data model - matches /api/profile response from Laravel
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
  final String? title;
  final String? patientName;
  final String? checkupDate;
  final String? nextCheckupDate;
  final String? bloodType;
  final String? height;
  final String? weight;
  final String? bloodPressure;
  final String? allergies;
  final String? result;
  final String? doctorName;
  final String? doctorContact;
  final String? facilityName;
  final String? facilityContact;
  final String? doctorNotes;
  final List<MedicalChecklistItem> checklistItems;

  UserMedical({
    required this.id,
    this.title,
    this.patientName,
    this.checkupDate,
    this.nextCheckupDate,
    this.bloodType,
    this.height,
    this.weight,
    this.bloodPressure,
    this.allergies,
    this.result,
    this.doctorName,
    this.doctorContact,
    this.facilityName,
    this.facilityContact,
    this.doctorNotes,
    this.checklistItems = const [],
  });

  factory UserMedical.fromJson(Map<String, dynamic> json) {
    return UserMedical(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      patientName: json['patient_name']?.toString(),
      checkupDate: json['checkup_date']?.toString(),
      nextCheckupDate: json['next_checkup_date']?.toString(),
      bloodType: json['blood_type']?.toString(),
      height: json['height']?.toString(),
      weight: json['weight']?.toString(),
      bloodPressure: json['blood_pressure']?.toString(),
      allergies: json['allergies']?.toString(),
      result: json['result']?.toString(),
      doctorName: json['doctor_name']?.toString(),
      doctorContact: json['doctor_contact']?.toString(),
      facilityName: json['facility_name']?.toString(),
      facilityContact: json['facility_contact']?.toString(),
      doctorNotes: json['doctor_notes']?.toString(),
      checklistItems: _parseChecklistItems(json['checklist_items']),
    );
  }

  static List<MedicalChecklistItem> _parseChecklistItems(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((i) => MedicalChecklistItem.fromJson(i as Map<String, dynamic>)).toList();
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = _jsonDecode(data);
        if (decoded is List) {
          return decoded.map((i) => MedicalChecklistItem.fromJson(i as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static dynamic _jsonDecode(String source) {
    return source.isEmpty ? [] : jsonDecode(source);
  }
}

class MedicalChecklistItem {
  final String label;
  final bool done;

  MedicalChecklistItem({
    required this.label,
    required this.done,
  });

  factory MedicalChecklistItem.fromJson(Map<String, dynamic> json) {
    return MedicalChecklistItem(
      label: json['label']?.toString() ?? '',
      done: json['done'] == true || json['done'] == 1,
    );
  }
}