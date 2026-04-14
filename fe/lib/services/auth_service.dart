import 'api_service.dart';
import 'storage_service.dart';
import '../models/user_model.dart';

class AuthService {
  // ── Login ─────────────────────────────────────────────────────────────────
  /// [login] With NIK
  static Future<AuthResult> login({
    required String login,
    required String password,
    bool rememberMe = false,
  }) async {
    final response = await ApiService.post(
      '/login',
      {'login': login, 'password': password},
      auth: false,
    );

    if (!response.success) {
      return AuthResult.error(response.errorMessage ?? 'Login gagal.');
    }

    final token = response.data['token'] as String?;
    final userData = response.data['data'] as Map<String, dynamic>?;

    if (token == null || userData == null) {
      return AuthResult.error('Respons server tidak valid.');
    }

    try {
      await Future.wait([
        StorageService.saveToken(token,
            rememberMe: rememberMe),
        StorageService.saveUser(userData),
      ]).timeout(const Duration(seconds: 3));
    } catch (_) {}

    return AuthResult.success(UserModel.fromJson(userData));
  }

// ── Register ──────────────────────────────────────────────────────────────
  static Future<AuthResult> register({
    required String nik,
    String? employeeId,
    required String fullName,
    required String personalEmail,
    String? workEmail,
    required String password,
    String? phoneNumber,
    String? position,
    String? department,
    String? company,
  }) async {
    final response = await ApiService.post(
      '/register',
      {
        'employee_id':   nik,
        'full_name':    fullName,
        'personal_email': personalEmail,
        if (workEmail != null && workEmail.isNotEmpty) 'work_email': workEmail,
        'password':     password,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (position    != null) 'position':    position,
        if (department  != null) 'department':  department,
        if (company     != null) 'company':     company,
      },
      auth: false,
    );


  if (!response.success) {
    return AuthResult.error(response.errorMessage ?? 'Registrasi gagal.');
  }

    return AuthResult.success(UserModel.fromJson(response.data['data']));
}

  // ── Logout ────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      await ApiService.post('/logout', {}).timeout(const Duration(seconds: 5));
    } catch (_) {}
    await StorageService.clear();
  }

  // ── Get current user from local storage ───────────────────────────────────
  static Future<UserModel?> getCurrentUser() async {
    final data = await StorageService.getUser();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }
}

// ── Result wrapper ────────────────────────────────────────────────────────────
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? errorMessage;

  AuthResult._({required this.success, this.user, this.errorMessage});

  factory AuthResult.success(UserModel user) =>
      AuthResult._(success: true, user: user);

  factory AuthResult.error(String message) =>
      AuthResult._(success: false, errorMessage: message);
}