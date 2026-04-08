import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/caregiver.dart';
import 'reminder_api_service.dart';

class CaregiverApiService {
  CaregiverApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<List<Caregiver>> fetchCaregivers({required int userId}) async {
    final response = await _client.get(_uri('/api/users/$userId/caregivers'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReminderApiException('Unable to load caregivers');
    }

    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) => Caregiver.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Caregiver> createCaregiver({
    required int userId,
    required Caregiver caregiver,
  }) async {
    final response = await _client.post(
      _uri('/api/caregivers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(caregiver.toCreateJson(userId: userId)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['error']?.toString();
      } catch (_) {
        errorMessage = null;
      }
      throw ReminderApiException(errorMessage ?? 'Unable to add caregiver');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Caregiver.fromJson(body['caregiver'] as Map<String, dynamic>);
  }

  Future<Caregiver> resendInvitation({
    required String caregiverId,
  }) async {
    final response = await _client.post(
      _uri('/api/caregivers/$caregiverId/resend-invitation'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['error']?.toString();
      } catch (_) {
        errorMessage = null;
      }
      throw ReminderApiException(errorMessage ?? 'Unable to resend invitation');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Caregiver.fromJson(body['caregiver'] as Map<String, dynamic>);
  }

  Future<Caregiver> verifyOtp({
    required String caregiverId,
    required String otpCode,
  }) async {
    final response = await _client.post(
      _uri('/api/caregivers/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {
          'caregiver_id': int.parse(caregiverId),
          'otp_code': otpCode,
        },
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['error']?.toString();
      } catch (_) {
        errorMessage = null;
      }
      throw ReminderApiException(errorMessage ?? 'Unable to verify OTP');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Caregiver.fromJson(body['caregiver'] as Map<String, dynamic>);
  }

  Future<Caregiver> rejectInvitation({
    required String caregiverId,
  }) async {
    final response = await _client.post(
      _uri('/api/caregivers/$caregiverId/reject'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['error']?.toString();
      } catch (_) {
        errorMessage = null;
      }
      throw ReminderApiException(errorMessage ?? 'Unable to reject invitation');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Caregiver.fromJson(body['caregiver'] as Map<String, dynamic>);
  }

  void dispose() {
    _client.close();
  }
}
