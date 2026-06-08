class DepartmentData {
  final int id;
  final String name;
  final bool isHrd;

  DepartmentData({
    required this.id,
    required this.name,
    this.isHrd = false,
  });

  factory DepartmentData.fromJson(Map<String, dynamic> json) {
    return DepartmentData(
      id: json['id'],
      name: json['name'] ?? '',
      isHrd: json['is_hrd'] == true ||
          json['is_hrd'] == 1 ||
          json['is_hrd']?.toString() == '1',
    );
  }
}
