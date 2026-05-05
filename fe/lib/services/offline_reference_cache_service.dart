import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/company_model.dart';
import 'company_service.dart';
import 'report_service.dart';

class OfflineReferenceBundle {
  final List<HazardCategoryData> categories;
  final List<String> departments;
  final List<UserEntry> users;
  final List<CompanyData> companies;

  const OfflineReferenceBundle({
    this.categories = const [],
    this.departments = const [],
    this.users = const [],
    this.companies = const [],
  });

  bool get hasData =>
      categories.isNotEmpty ||
      departments.isNotEmpty ||
      users.isNotEmpty ||
      companies.isNotEmpty;
}

class OfflineReferenceCacheService {
  OfflineReferenceCacheService._();

  static const _refsKey = 'offline_refs_hazard_create_v1';
  static const _areasPrefix = 'offline_refs_company_areas_v1_';

  static Future<void> saveHazardCreateRefs({
    required List<HazardCategoryData> categories,
    required List<String> departments,
    required List<UserEntry> users,
    required List<CompanyData> companies,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'categories': categories.map(_categoryToJson).toList(),
      'departments': departments,
      'users': users.map(_userToJson).toList(),
      'companies': companies.map(_companyToJson).toList(),
      'saved_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_refsKey, jsonEncode(payload));
  }

  static Future<OfflineReferenceBundle> loadHazardCreateRefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_refsKey);
    if (raw == null || raw.isEmpty) {
      return const OfflineReferenceBundle();
    }

    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final categoriesRaw = (map['categories'] as List?) ?? const [];
      final departmentsRaw = (map['departments'] as List?) ?? const [];
      final usersRaw = (map['users'] as List?) ?? const [];
      final companiesRaw = (map['companies'] as List?) ?? const [];

      return OfflineReferenceBundle(
        categories: categoriesRaw
            .map((e) => _categoryFromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        departments: departmentsRaw
            .map((e) => e?.toString() ?? '')
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        users: usersRaw
            .map((e) => _userFromJson(Map<String, dynamic>.from(e as Map)))
            .where((u) => u.id.isNotEmpty && u.fullName.trim().isNotEmpty)
            .toList(),
        companies: companiesRaw
            .map((e) => CompanyData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    } catch (_) {
      return const OfflineReferenceBundle();
    }
  }

  static Future<void> saveAreasForCompany({
    required int companyId,
    required List<AreaData> areas,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_areasPrefix$companyId',
      jsonEncode({
        'areas': areas.map(_areaToJson).toList(),
        'saved_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<List<AreaData>> loadAreasForCompany(int companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_areasPrefix$companyId');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final list = (map['areas'] as List?) ?? const [];
      return list
          .map((e) => AreaData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _categoryToJson(HazardCategoryData c) => {
        'id': c.id,
        'name': c.name,
        'code': c.code,
        'subcategories': c.subcategories.map(_subCategoryToJson).toList(),
      };

  static HazardCategoryData _categoryFromJson(Map<String, dynamic> m) {
    final subRaw = (m['subcategories'] as List?) ?? const [];
    return HazardCategoryData(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      code: m['code']?.toString() ?? '',
      subcategories: subRaw
          .map((e) =>
              _subCategoryFromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static Map<String, dynamic> _subCategoryToJson(HazardSubcategoryData s) => {
        'id': s.id,
        'name': s.name,
        'abbreviation': s.abbreviation,
        'description': s.description,
        'is_active': s.isActive,
        'status': s.status,
        'category_id': s.categoryId,
        'category_name': s.categoryName,
        'proposed_by_name': s.proposedByName,
      };

  static HazardSubcategoryData _subCategoryFromJson(Map<String, dynamic> m) =>
      HazardSubcategoryData(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        abbreviation: m['abbreviation']?.toString(),
        description: m['description']?.toString(),
        isActive: m['is_active'] == true || m['is_active'] == 1,
        status: m['status']?.toString() ?? 'approved',
        categoryId: m['category_id']?.toString(),
        categoryName: m['category_name']?.toString(),
        proposedByName: m['proposed_by_name']?.toString(),
      );

  static Map<String, dynamic> _userToJson(UserEntry u) => {
        'id': u.id,
        'full_name': u.fullName,
        'department': u.department,
        'photo_url': u.photoUrl,
      };

  static UserEntry _userFromJson(Map<String, dynamic> m) => UserEntry(
        id: m['id']?.toString() ?? '',
        fullName: m['full_name']?.toString() ?? '',
        department: m['department']?.toString(),
        photoUrl: m['photo_url']?.toString(),
      );

  static Map<String, dynamic> _companyToJson(CompanyData c) => {
        'id': c.id,
        'name': c.name,
        'code': c.code,
        'category': c.category,
        'is_active': c.isActive,
      };

  static Map<String, dynamic> _areaToJson(AreaData a) => {
        'id': a.id,
        'company_id': a.companyId,
        'company_name': a.companyName,
        'name': a.name,
        'code': a.code,
        'is_active': a.isActive,
      };

  static Future<void> prefetchHazardCreateReferences() async {
    try {
      final results = await Future.wait([
        ReportService.getHazardCategories(),
        ReportService.getDepartments(),
        ReportService.getUsers(),
        CompanyService.getCompanies(category: 'owner', active: true),
      ]);

      final categories = results[0] as List<HazardCategoryData>;
      final departments = results[1] as List<String>;
      final users = results[2] as List<UserEntry>;
      final companies = results[3] as List<CompanyData>;

      await saveHazardCreateRefs(
        categories: categories,
        departments: departments,
        users: users,
        companies: companies,
      );

      final allAreas = await CompanyService.getAreas(active: true);
      final byCompany = <int, List<AreaData>>{};
      for (final area in allAreas) {
        byCompany.putIfAbsent(area.companyId, () => <AreaData>[]).add(area);
      }

      for (final entry in byCompany.entries) {
        await saveAreasForCompany(companyId: entry.key, areas: entry.value);
      }
    } catch (_) {
      // Best effort prefetch only; app should continue using existing cache.
    }
  }
}
