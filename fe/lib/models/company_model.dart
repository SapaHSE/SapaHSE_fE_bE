class CompanyData {
  final int id;
  final String name;
  final String? code;
  final String category;
  final bool isActive;

  CompanyData({
    required this.id,
    required this.name,
    this.code,
    required this.category,
    required this.isActive,
  });

  factory CompanyData.fromJson(Map<String, dynamic> json) {
    return CompanyData(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'],
      category: json['category'] ?? 'owner',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}

class AreaData {
  final int id;
  final int companyId;
  final String? companyName;
  final int? picUserId;
  final String? picUserName;
  final List<int> picUserIds;
  final List<AreaPicUserData> picUsers;
  final String name;
  final String? code;
  final bool isActive;

  AreaData({
    required this.id,
    required this.companyId,
    this.companyName,
    this.picUserId,
    this.picUserName,
    this.picUserIds = const [],
    this.picUsers = const [],
    required this.name,
    this.code,
    required this.isActive,
  });

  factory AreaData.fromJson(Map<String, dynamic> json) {
    final picUsersRaw = json['pic_users'];
    final parsedPicUsers = <AreaPicUserData>[];
    if (picUsersRaw is List) {
      for (final raw in picUsersRaw) {
        if (raw is Map) {
          parsedPicUsers.add(AreaPicUserData.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }

    final picUserIdsRaw = json['pic_user_ids'];
    final parsedPicUserIds = <int>[];
    if (picUserIdsRaw is List) {
      for (final raw in picUserIdsRaw) {
        final id = int.tryParse(raw?.toString() ?? '');
        if (id != null && id > 0) parsedPicUserIds.add(id);
      }
    }

    final picUserId = json['pic_user_id'] is int
        ? json['pic_user_id'] as int
        : int.tryParse(json['pic_user_id']?.toString() ?? '');

    if (parsedPicUserIds.isEmpty && parsedPicUsers.isNotEmpty) {
      parsedPicUserIds.addAll(parsedPicUsers.map((u) => u.id));
    }

    if (parsedPicUsers.isEmpty && picUserId != null) {
      parsedPicUsers.add(AreaPicUserData(
        id: picUserId,
        fullName: json['pic_user_name']?.toString() ?? '',
        employeeId: '',
      ));
    }
    if (parsedPicUserIds.isEmpty && picUserId != null) {
      parsedPicUserIds.add(picUserId);
    }

    return AreaData(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      companyId: json['company_id'] is int
          ? json['company_id'] as int
          : int.tryParse(json['company_id']?.toString() ?? '') ?? 0,
      companyName: json['company_name']?.toString(),
      picUserId: picUserId,
      picUserName: parsedPicUsers.isNotEmpty
          ? parsedPicUsers.map((u) => u.displayLabel).join(', ')
          : json['pic_user_name']?.toString(),
      picUserIds: parsedPicUserIds,
      picUsers: parsedPicUsers,
      name: json['name'] ?? '',
      code: json['code'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}

class AreaPicUserData {
  final int id;
  final String fullName;
  final String? employeeId;
  final String? department;
  final String? position;
  final String? jabatan;

  const AreaPicUserData({
    required this.id,
    required this.fullName,
    this.employeeId,
    this.department,
    this.position,
    this.jabatan,
  });

  factory AreaPicUserData.fromJson(Map<String, dynamic> json) {
    return AreaPicUserData(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      fullName: json['full_name']?.toString() ?? '',
      employeeId: json['employee_id']?.toString(),
      department: json['department']?.toString(),
      position: json['position']?.toString(),
      jabatan: json['jabatan']?.toString(),
    );
  }

  String get displayLabel {
    final name = fullName.trim().isEmpty ? 'Tanpa nama' : fullName.trim();
    final nik = employeeId?.trim() ?? '';
    return nik.isEmpty ? name : '$name - $nik';
  }
}
