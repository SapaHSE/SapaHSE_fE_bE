import 'dart:convert';
import 'company_model.dart';
import '../utils/url_helper.dart';
import '../utils/value_parser.dart';

/// Profile data model - matches /api/profile response from Laravel
class ProfileData {
  final String id;
  final String employeeId;
  final String fullName;
  final String personalEmail;
  final String? workEmail;
  final String? qrCode;
  final String? phoneNumber;
  final String? position;
  final String? jabatan;
  final String? department;
  final String? company;
  final CompanyData? companyDetail;
  final CompanyData? ownerCompanyDetail;
  final String? tipeAfiliasi;
  final String? perusahaanKontraktor;
  final String? subKontraktor;
  final String? simper;
  final String? profilePhoto;
  final String? address;
  final String role;
  final bool isActive;
  final List<UserLicense> licenses;
  final List<UserCertification> certifications;
  final List<UserMedical> medicals;
  final List<UserViolation> violations;

  ProfileData({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.personalEmail,
    this.workEmail,
    this.qrCode,
    this.phoneNumber,
    this.position,
    this.jabatan,
    this.department,
    this.company,
    this.companyDetail,
    this.ownerCompanyDetail,
    this.tipeAfiliasi,
    this.perusahaanKontraktor,
    this.subKontraktor,
    this.simper,
    this.profilePhoto,
    this.address,
    required this.role,
    required this.isActive,
    this.licenses = const [],
    this.certifications = const [],
    this.medicals = const [],
    this.violations = const [],
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      personalEmail: json['personal_email']?.toString() ?? '',
      workEmail: json['work_email']?.toString(),
      qrCode: json['qr_code']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      position: json['position']?.toString(),
      jabatan: json['jabatan']?.toString(),
      department: json['department']?.toString(),
      company: json['company']?.toString(),
      companyDetail: json['company_detail'] is Map
          ? CompanyData.fromJson(
              Map<String, dynamic>.from(json['company_detail'] as Map))
          : null,
      ownerCompanyDetail: json['owner_company_detail'] is Map
          ? CompanyData.fromJson(
              Map<String, dynamic>.from(json['owner_company_detail'] as Map))
          : null,
      tipeAfiliasi: json['tipe_afiliasi']?.toString(),
      perusahaanKontraktor: json['perusahaan_kontraktor']?.toString(),
      subKontraktor: json['sub_kontraktor']?.toString(),
      simper: json['simper']?.toString(),
      profilePhoto: normalizeStorageUrl(json['profile_photo']?.toString()),
      address: json['alamat']?.toString() ?? json['address']?.toString(),
      role: json['role']?.toString() ?? 'user',
      isActive: parseFlexibleBool(json['is_active']),
      licenses: (json['licenses'] as List<dynamic>?)
              ?.map((l) => UserLicense.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map(
                  (c) => UserCertification.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      medicals: (json['medicals'] as List<dynamic>?)
              ?.map((m) => UserMedical.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      violations: (json['violations'] as List<dynamic>?)
              ?.map((v) => UserViolation.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get email => workEmail ?? personalEmail;
}

class CompanyDetailData {
  final int id;
  final String name;
  final String? code;
  final String? logoUrl;
  final String? kttSignatureUrl;
  final String? companyStampUrl;
  final String? kttUserId;
  final CompanyKttUserData? kttUser;
  final String? emergencyNumber;
  final String? radioLabel;
  final String? radioChannel;
  final String? radioFrequency;
  final String category;
  final bool isActive;

  const CompanyDetailData({
    required this.id,
    required this.name,
    this.code,
    this.logoUrl,
    this.kttSignatureUrl,
    this.companyStampUrl,
    this.kttUserId,
    this.kttUser,
    this.emergencyNumber,
    this.radioLabel,
    this.radioChannel,
    this.radioFrequency,
    required this.category,
    required this.isActive,
  });

  factory CompanyDetailData.fromJson(Map<String, dynamic> json) {
    final kttUserRaw = json['ktt_user'];
    return CompanyDetailData(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      logoUrl: normalizeStorageUrl(json['logo_url']?.toString()),
      kttSignatureUrl:
          normalizeStorageUrl(json['ktt_signature_url']?.toString()),
      companyStampUrl:
          normalizeStorageUrl(json['company_stamp_url']?.toString()),
      kttUserId: json['ktt_user_id']?.toString(),
      kttUser: kttUserRaw is Map
          ? CompanyKttUserData.fromJson(Map<String, dynamic>.from(kttUserRaw))
          : null,
      emergencyNumber: json['emergency_number']?.toString(),
      radioLabel: json['radio_label']?.toString(),
      radioChannel: json['radio_channel']?.toString(),
      radioFrequency: json['radio_frequency']?.toString(),
      category: json['category']?.toString() ?? 'owner',
      isActive: parseFlexibleBool(json['is_active']),
    );
  }
}

class UserLicense {
  final String id;
  final String name;
  final String licenseNumber;
  final String licenseType;
  final String? vehicleEquipment;
  final String? simType;
  final String? simIndonesiaType;
  final String? issuer;
  final String? obtainedAt;
  final String? expiredAt;
  final String status;
  final bool isVerified;
  final String approvalStatus;
  final String? rejectionReason;
  final String? submittedAt;
  final String? reviewedAt;
  final String? fileUrl;

  UserLicense({
    required this.id,
    required this.name,
    required this.licenseNumber,
    this.licenseType = 'general',
    this.vehicleEquipment,
    this.simType,
    this.simIndonesiaType,
    this.issuer,
    this.obtainedAt,
    this.expiredAt,
    required this.status,
    this.isVerified = false,
    this.approvalStatus = 'pending',
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.fileUrl,
  });

  factory UserLicense.fromJson(Map<String, dynamic> json) {
    return UserLicense(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      licenseNumber: json['license_number']?.toString() ?? '',
      licenseType: json['license_type']?.toString() ?? 'general',
      vehicleEquipment: json['vehicle_equipment']?.toString(),
      simType: json['sim_type']?.toString(),
      simIndonesiaType: json['sim_indonesia_type']?.toString(),
      issuer: json['issuer']?.toString(),
      obtainedAt: json['obtained_at']?.toString(),
      expiredAt: json['expired_at']?.toString(),
      status: json['status']?.toString() ?? 'active',
      isVerified: parseFlexibleBool(json['is_verified']),
      approvalStatus: json['approval_status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      submittedAt: json['submitted_at']?.toString(),
      reviewedAt: json['reviewed_at']?.toString(),
      fileUrl: normalizeStorageUrl(json['file_url']?.toString()),
    );
  }

  bool get isActive => status == 'active';

  bool canBeRenewedNow({DateTime? now}) {
    final expiry = DateTime.tryParse((expiredAt ?? '').trim());
    if (expiry == null) return true;
    final reference = now ?? DateTime.now();
    final renewalWindowStart =
        DateTime(expiry.year, expiry.month - 1, expiry.day);
    return !renewalWindowStart.isAfter(reference);
  }

  static const String renewalBlockedMessage =
      'Perpanjangan belum bisa dilakukan karena masih berlaku. '
      'Ajukan paling cepat 1 bulan sebelum habis masa berlaku';

  static UserLicense? findApprovedMinePermit(List<UserLicense> licenses) {
    final matches = licenses
        .where((l) =>
            (l.licenseType == 'mine_permit' ||
                l.name.toLowerCase().trim() == 'mine permit') &&
            l.approvalStatus.toLowerCase() == 'approved')
        .toList()
      ..sort((a, b) => (b.expiredAt ?? '').compareTo(a.expiredAt ?? ''));
    return matches.isEmpty ? null : matches.first;
  }
}

class UserCertification {
  final String id;
  final String name;
  final String? certificationNumber;
  final String issuer;
  final String? obtainedAt;
  final String? expiredAt;
  final String status;
  final bool isVerified;
  final String approvalStatus;
  final String? rejectionReason;
  final String? submittedAt;
  final String? reviewedAt;
  final String? fileUrl;

  UserCertification({
    required this.id,
    required this.name,
    this.certificationNumber,
    required this.issuer,
    this.obtainedAt,
    this.expiredAt,
    required this.status,
    this.isVerified = false,
    this.approvalStatus = 'pending',
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.fileUrl,
  });

  factory UserCertification.fromJson(Map<String, dynamic> json) {
    return UserCertification(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      certificationNumber: json['certification_number']?.toString(),
      issuer: json['issuer']?.toString() ?? '',
      obtainedAt: json['obtained_at']?.toString(),
      expiredAt: json['expired_at']?.toString(),
      status: json['status']?.toString() ?? 'active',
      isVerified: parseFlexibleBool(json['is_verified']),
      approvalStatus: json['approval_status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      submittedAt: json['submitted_at']?.toString(),
      reviewedAt: json['reviewed_at']?.toString(),
      fileUrl: normalizeStorageUrl(json['file_url']?.toString()),
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
  final String? lastMedication;
  final String? currentMedication;
  final String? currentIllness;
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
    this.lastMedication,
    this.currentMedication,
    this.currentIllness,
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
      lastMedication: json['last_medication']?.toString(),
      currentMedication: json['current_medication']?.toString(),
      currentIllness: json['current_illness']?.toString(),
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
      return data
          .map((i) => MedicalChecklistItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = _jsonDecode(data);
        if (decoded is List) {
          return decoded
              .map((i) =>
                  MedicalChecklistItem.fromJson(i as Map<String, dynamic>))
              .toList();
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
      done: parseFlexibleBool(json['done']),
    );
  }
}

class UserViolation {
  final String id;
  final String title;
  final String? violationCategory;
  final String? violationSubcategory;
  final String type;
  final int level;
  final String? description;
  final String? location;
  final String? dateOfViolation;
  final String? expiredAt;
  final String status;
  final String? sanction;
  final String? fileUrl;

  UserViolation({
    required this.id,
    required this.title,
    this.violationCategory,
    this.violationSubcategory,
    this.type = 'Violation',
    this.level = 1,
    this.description,
    this.location,
    this.dateOfViolation,
    this.expiredAt,
    required this.status,
    this.sanction,
    this.fileUrl,
  });

  factory UserViolation.fromJson(Map<String, dynamic> json) {
    return UserViolation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      violationCategory: json['violation_category']?.toString(),
      violationSubcategory: json['violation_subcategory']?.toString(),
      type: json['type']?.toString() ?? 'Violation',
      level: int.tryParse(json['level']?.toString() ?? '') ?? 1,
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      dateOfViolation: json['date_of_violation']?.toString(),
      expiredAt: json['expired_at']?.toString(),
      status: json['status']?.toString() ?? 'Aktif',
      sanction: json['sanction']?.toString(),
      fileUrl: json['file_url']?.toString(),
    );
  }
}
