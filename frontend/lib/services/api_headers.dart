import 'auth_session_service.dart';

Map<String, String> buildAuthHeaders() {
  final headers = <String, String>{};

  final token = AuthSessionService.instance.accessToken;
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }

  return headers;
}

Map<String, String> buildJsonHeaders() {
  return <String, String>{
    ...buildAuthHeaders(),
    'Content-Type': 'application/json',
  };
}
