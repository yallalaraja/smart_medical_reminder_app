import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/caregiver.dart';
import 'api_headers.dart';
import 'reminder_api_service.dart';

class CaregiverApiService {
  CaregiverApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<List<Caregiver>> fetchCaregivers({required String userId}) async {
    final response = await _send(_client.get(
      _uri('/api/users/$userId/caregivers'),
      headers: buildAuthHeaders(),
    ));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReminderApiException('Unable to load caregivers');
    }

    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) => Caregiver.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Caregiver> createCaregiver({
    required String userId,
    required Caregiver caregiver,
  }) async {
    final response = await _send(_client.post(
      _uri('/api/caregivers'),
      headers: buildJsonHeaders(),
      body: jsonEncode(caregiver.toCreateJson(userId: userId)),
    ));
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
    final response = await _send(_client.post(
      _uri('/api/caregivers/$caregiverId/resend-invitation'),
      headers: buildAuthHeaders(),
    ));
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

  Future<Caregiver> updateCaregiver({
    required Caregiver caregiver,
  }) async {
    final response = await _send(_client.put(
      _uri('/api/caregivers/${caregiver.id}'),
      headers: buildJsonHeaders(),
      body: jsonEncode(caregiver.toUpdateJson()),
    ));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['error']?.toString();
      } catch (_) {
        errorMessage = null;
      }
      throw ReminderApiException(errorMessage ?? 'Unable to update caregiver');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Caregiver.fromJson(body['caregiver'] as Map<String, dynamic>);
  }

  Future<Caregiver> verifyOtp({
    required String caregiverId,
    required String otpCode,
  }) async {
    final response = await _send(_client.post(
      _uri('/api/caregivers/verify-otp'),
      headers: buildJsonHeaders(),
      body: jsonEncode(
        {
          'caregiver_id': caregiverId,
          'otp_code': otpCode,
        },
      ),
    ));
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
    final response = await _send(_client.post(
      _uri('/api/caregivers/$caregiverId/reject'),
      headers: buildAuthHeaders(),
    ));
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

  Future<String> deleteCaregiver({
    required String caregiverId,
  }) async {
    final response = await _send(_client.delete(
      _uri('/api/caregivers/$caregiverId'),
      headers: buildAuthHeaders(),
    ));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['error']?.toString();
      } catch (_) {
        errorMessage = null;
      }
      throw ReminderApiException(errorMessage ?? 'Unable to delete caregiver');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['message'] ?? 'Caregiver deleted').toString();
  }

  void dispose() {
    _client.close();
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(
        const Duration(seconds: AppConfig.apiRequestTimeoutSeconds),
      );
    } on TimeoutException {
      throw ReminderApiException(
        'The server is taking too long to respond. Please try again.',
      );
    }
  }
}
