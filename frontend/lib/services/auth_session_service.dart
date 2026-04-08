import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionService {
  AuthSessionService._();

  static const _tokenKey = 'access_token';
  static const _phoneNumberKey = 'last_phone_number';
  static final AuthSessionService instance = AuthSessionService._();

  String? _accessToken;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
  }

  String? get accessToken => _accessToken;

  Future<void> saveSession({
    required String accessToken,
    String? phoneNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      await prefs.setString(_phoneNumberKey, phoneNumber);
    }
    _accessToken = accessToken;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _accessToken = null;
  }
}
