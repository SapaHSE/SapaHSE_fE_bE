import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_globals.dart';
import '../screens/login_screen.dart';
import 'storage_service.dart';

class ApiService {
  // ── Base URL ─────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://sapahse.up.railway.app/api';

  // ── Headers ───────────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await StorageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── GET ───────────────────────────────────────────────────────────────────
  static Future<ApiResponse> get(String endpoint, {bool auth = true}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 30));
      return await _handleResponse(response);
    } on SocketException {
      return ApiResponse.error(
          'No internet connection. Check if Laravel server is running.');
    } on HttpException {
      return ApiResponse.error('Server error. Please try again.');
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  static Future<ApiResponse> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return await _handleResponse(response);
    } on SocketException {
      return ApiResponse.error(
          'No internet connection. Check if Laravel server is running.');
    } on HttpException {
      return ApiResponse.error('Server error. Please try again.');
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ── PATCH ─────────────────────────────────────────────────────────────────
  static Future<ApiResponse> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return await _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('No internet connection.');
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<ApiResponse> delete(String endpoint, {bool auth = true}) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 30));
      return await _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('No internet connection.');
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // ── Response Handler ──────────────────────────────────────────────────────
  static Future<ApiResponse> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['status'] == 'success') {
        return ApiResponse.success(body);
      } else {
        return ApiResponse.error(body['message'] ?? 'Unknown error');
      }
    } else if (response.statusCode == 401) {
      final hasToken = await StorageService.getToken() != null;
      if (hasToken) {
        StorageService.clear().then((_) {
          final ctx = navigatorKey.currentContext;
          if (ctx == null || !ctx.mounted) return;
          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_clock, color: Color(0xFF1A56C4)),
                  SizedBox(width: 8),
                  Text('Sesi Berakhir'),
                ],
              ),
              content: const Text(
                'Sesi kamu telah habis. Silakan login kembali untuk melanjutkan.',
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    navigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Login Kembali'),
                ),
              ],
            ),
          );
        });
      }
      return ApiResponse.error(
        body['message'] ??
            (hasToken
                ? 'Sesi berakhir. Silakan login kembali.'
                : 'Credensial tidak valid.'),
        statusCode: 401,
      );
    } else if (response.statusCode == 403) {
      return ApiResponse.error(
        body['message'] ?? 'Akses ditolak.',
        statusCode: 403,
      );
    } else if (response.statusCode == 422) {
      // Validation errors from Laravel
      final errors = body['errors'] as Map<String, dynamic>?;
      final firstError = errors?.values.first;
      final message = firstError is List ? firstError.first : body['message'];
      return ApiResponse.error(message ?? 'Validasi gagal.', statusCode: 422);
    } else {
      return ApiResponse.error(
        body['message'] ?? 'Terjadi kesalahan.',
        statusCode: response.statusCode,
      );
    }
  }
}

// ── API Response Wrapper ─────────────────────────────────────────────────────
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? errorMessage;
  final int? statusCode;

  ApiResponse._({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory ApiResponse.success(dynamic data) =>
      ApiResponse._(success: true, data: data);

  factory ApiResponse.error(String message, {int? statusCode}) => ApiResponse._(
      success: false, errorMessage: message, statusCode: statusCode);
}
