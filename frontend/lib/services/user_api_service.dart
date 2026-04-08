import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';
import 'reminder_api_service.dart';

class UserApiService {
  UserApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<void> updateTimezone({
    required String userId,
    required String timezone,
  }) async {
    final response = await _client.put(
      _uri('/api/users/$userId/timezone'),
      headers: buildJsonHeaders(),
      body: jsonEncode({'timezone': timezone}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['error']?.toString();
      } catch (_) {
        errorMessage = null;
      }
      throw ReminderApiException(errorMessage ?? 'Unable to update timezone');
    }
  }

  void dispose() {
    _client.close();
  }
}
