import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_session_service.dart';
import 'reminder_api_service.dart';

class AuthApiService {
  AuthApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<AuthResult> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {
          'phone_number': phoneNumber,
          'password': password,
        },
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _authError(response, 'Unable to login');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token']?.toString() ?? '';
    if (accessToken.isEmpty) {
      throw ReminderApiException('Login succeeded but no access token was returned');
    }

    await AuthSessionService.instance.saveSession(
      accessToken: accessToken,
      phoneNumber: phoneNumber,
    );

    return AuthResult(
      accessToken: accessToken,
      userId: body['user']?['id']?.toString(),
    );
  }

  ReminderApiException _authError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ReminderApiException(body['error']?.toString() ?? fallback);
    } catch (_) {
      return ReminderApiException(fallback);
    }
  }

  void dispose() {
    _client.close();
  }
}

class AuthResult {
  AuthResult({
    required this.accessToken,
    this.userId,
  });

  final String accessToken;
  final String? userId;
}
