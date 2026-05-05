class DepartmentData {
  final int id;
  final String name;

  DepartmentData({
    required this.id,
    required this.name,
  });

  factory DepartmentData.fromJson(Map<String, dynamic> json) {
    return DepartmentData(
      id: json['id'],
      name: json['name'] ?? '',
    );
  }
}
