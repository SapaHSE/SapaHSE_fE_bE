import 'api_service.dart';
import 'storage_service.dart';
import '../models/user_model.dart';

class AuthService {
  // ── Login ─────────────────────────────────────────────────────────────────
  /// [login] can be NIK, employee_id, or email — matches Laravel's AuthController
  static Future<AuthResult> login({
    required String login,
    required String password,
  }) async {
    final response = await ApiService.post(
      '/login',
      {'login': login, 'password': password},
      auth: false,
    );
    
    print(response.data);

    if (!response.success) {
      return AuthResult.error(response.errorMessage ?? 'Login gagal.');
    }

    final token    = response.data['token'] as String?;
    final userData = response.data['data'] as Map<String, dynamic>?;

    if (token == null || userData == null) {
      return AuthResult.error('Respons server tidak valid.');
    }

    // Save token and user in parallel with a timeout
    // If storage is slow/fails, we still let the user in
    try {
      await Future.wait([
        StorageService.saveToken(token),
        StorageService.saveUser(userData),
      ]).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Storage failed or timed out — navigation still proceeds
    }

    return AuthResult.success(UserModel.fromJson(userData));
  }

  // ── Register ──────────────────────────────────────────────────────────────
  static Future<AuthResult> register({
    required String nik,
    required String employeeId,
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
    String? position,
    String? department,
  }) async {
    final response = await ApiService.post(
      '/register',
      {
        'nik':         nik,
        'employee_id': employeeId,
        'full_name':   fullName,
        'email':       email,
        'password':    password,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (position    != null) 'position':     position,
        if (department  != null) 'department':   department,
      },
      auth: false,
    );

    if (!response.success) {
      return AuthResult.error(response.errorMessage ?? 'Registrasi gagal.');
    }

    final token    = response.data['token'] as String?;
    final userData = response.data['data'] as Map<String, dynamic>?;

    if (token == null || userData == null) {
      return AuthResult.error('Respons server tidak valid.');
    }

    try {
      await Future.wait([
        StorageService.saveToken(token),
        StorageService.saveUser(userData),
      ]).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Storage failed or timed out — navigation still proceeds
    }

    return AuthResult.success(UserModel.fromJson(userData));
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