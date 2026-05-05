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
  final String name;
  final String? code;
  final bool isActive;

  AreaData({
    required this.id,
    required this.companyId,
    this.companyName,
    required this.name,
    this.code,
    required this.isActive,
  });

  factory AreaData.fromJson(Map<String, dynamic> json) {
    return AreaData(
      id: json['id'],
      companyId: json['company_id'],
      companyName: json['company_name'],
      name: json['name'] ?? '',
      code: json['code'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}
