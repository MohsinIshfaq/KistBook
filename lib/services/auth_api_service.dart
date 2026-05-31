import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_enums.dart';
import 'session_manager.dart';

class AuthApiService {
  AuthApiService({
    required SessionManager sessionManager,
    http.Client? httpClient,
  }) : _sessionManager = sessionManager,
       _httpClient = httpClient ?? http.Client();

  final SessionManager _sessionManager;
  final http.Client _httpClient;

  Future<AuthApiResult?> login({
    required String phone,
    required String password,
  }) {
    return _post('/auth/login', {'phone': phone, 'password': password});
  }

  Future<AuthApiResult?> registerOwner({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) {
    return _post('/auth/register', {
      'phone': phone,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'access_level': 'owner',
      'is_active': true,
    });
  }

  Future<AuthApiResult?> _post(String path, Map<String, Object?> body) async {
    try {
      final response = await _httpClient
          .post(
            _apiUri(path),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }
      final user = data['user'];
      final token = data['token']?.toString() ?? '';
      if (user is! Map<String, dynamic> || token.isEmpty) {
        return null;
      }

      return AuthApiResult(
        token: token,
        serverId: user['uuid']?.toString() ?? '',
        phone: user['phone']?.toString() ?? '',
        firstName: user['first_name']?.toString() ?? '',
        lastName: user['last_name']?.toString() ?? '',
        role: _roleFromApi(user['access_level']?.toString()),
        isActive: user['is_active'] != false,
      );
    } catch (_) {
      return null;
    }
  }

  Uri _apiUri(String path) {
    final baseUrl = _sessionManager.apiBaseUrl.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    return Uri.parse('$baseUrl$path');
  }

  UserRole _roleFromApi(String? value) {
    return switch (value) {
      'owner' => UserRole.owner,
      'admin' => UserRole.admin,
      _ => UserRole.salesMan,
    };
  }
}

class AuthApiResult {
  const AuthApiResult({
    required this.token,
    required this.serverId,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
  });

  final String token;
  final String serverId;
  final String phone;
  final String firstName;
  final String lastName;
  final UserRole role;
  final bool isActive;
}
