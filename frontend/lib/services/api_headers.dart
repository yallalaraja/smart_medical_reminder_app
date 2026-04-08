import 'auth_session_service.dart';

Map<String, String> buildJsonHeaders() {
  final headers = <String, String>{
    'Content-Type': 'application/json',
  };

  final token = AuthSessionService.instance.accessToken;
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }

  return headers;
}
