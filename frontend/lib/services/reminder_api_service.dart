import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/medication_reminder.dart';
import 'api_headers.dart';

class ReminderApiService {
  ReminderApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<List<MedicationReminder>> fetchDashboardReminders({
    required String userId,
  }) async {
    final response = await _send(
      () => _client.get(_uri('/api/dashboard/$userId')),
    );
    _ensureSuccess(response, 'Unable to load reminders');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final reminders = (body['reminders'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    final mapped = reminders
        .map(MedicationReminder.fromJson)
        .toList();

    mapped.sort(_sortByTime);
    return mapped;
  }

  Future<MedicationReminder> createReminder({
    required String userId,
    required MedicationReminder reminder,
  }) async {
    final reminderResponse = await _send(
      () => _client.post(
        _uri('/api/reminders'),
        headers: buildJsonHeaders(),
        body: jsonEncode(
          {
            'user_id': userId,
            'title': reminder.title,
            'description': reminder.description,
            'category': reminder.category,
            'scheduled_date': reminder.scheduledDate?.toIso8601String().split('T').first,
            'time_of_day': _toApiTime(reminder.time),
            'repeat_type': reminder.repeatType,
            'selected_days': reminder.selectedDays,
            'voice_message': reminder.voiceMessage,
            'alert_audio_path': reminder.alertAudioPath,
            'alert_audio_name': reminder.alertAudioName,
          },
        ),
      ),
    );
    _ensureSuccess(reminderResponse, 'Unable to create reminder');

    final reminderBody = jsonDecode(reminderResponse.body) as Map<String, dynamic>;
    return MedicationReminder.fromJson(reminderBody);
  }

  Future<MedicationReminder> updateReminder({
    required MedicationReminder reminder,
  }) async {
    final response = await _send(
      () => _client.put(
        _uri('/api/reminders/${reminder.id}'),
        headers: buildJsonHeaders(),
        body: jsonEncode(
          {
            'title': reminder.title,
            'description': reminder.description,
            'category': reminder.category,
            'scheduled_date': reminder.scheduledDate?.toIso8601String().split('T').first,
            'time_of_day': _toApiTime(reminder.time),
            'repeat_type': reminder.repeatType,
            'selected_days': reminder.selectedDays,
            'voice_message':
                reminder.voiceMessage ?? 'It is time for ${reminder.title}',
            'alert_audio_path': reminder.alertAudioPath,
            'alert_audio_name': reminder.alertAudioName,
            'is_active': reminder.isActive,
          },
        ),
      ),
    );
    _ensureSuccess(response, 'Unable to update reminder');

    final reminderBody = jsonDecode(response.body) as Map<String, dynamic>;
    return MedicationReminder.fromJson(reminderBody);
  }

  Future<void> deleteReminder({
    required String reminderId,
  }) async {
    final response = await _send(
      () => _client.delete(_uri('/api/reminders/$reminderId')),
    );
    _ensureSuccess(response, 'Unable to delete reminder');
  }

  Future<MedicationReminder> markReminderDone({
    required String reminderId,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/logs'),
        headers: buildJsonHeaders(),
        body: jsonEncode(
          {
            'reminder_id': reminderId,
            'status': 'done',
            'notes': 'Completed from Flutter app',
          },
        ),
      ),
    );
    _ensureSuccess(response, 'Unable to save reminder status');

    return fetchReminder(reminderId: reminderId);
  }

  Future<MissedReminderResult> markReminderMissed({
    required String reminderId,
    String channel = 'sms',
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/reminders/$reminderId/missed'),
        headers: buildJsonHeaders(),
        body: jsonEncode(
          {
            'channel': channel,
            'notes': 'Marked as missed from Flutter app',
          },
        ),
      ),
    );
    _ensureSuccess(response, 'Unable to mark reminder as missed');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MissedReminderResult.fromJson(body);
  }

  Future<MedicationReminder> markReminderTriggered({
    required String reminderId,
  }) async {
    final response = await _send(
      () => _client.put(
        _uri('/api/reminders/$reminderId/trigger'),
        headers: buildJsonHeaders(),
      ),
    );
    _ensureSuccess(response, 'Unable to start reminder alert');

    final reminderBody = jsonDecode(response.body) as Map<String, dynamic>;
    return MedicationReminder.fromJson(reminderBody);
  }

  Future<MedicationReminder> markReminderPending({
    required String reminderId,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/logs'),
        headers: buildJsonHeaders(),
        body: jsonEncode(
          {
            'reminder_id': reminderId,
            'status': 'pending',
            'notes': 'Marked pending again from Flutter app',
          },
        ),
      ),
    );
    _ensureSuccess(response, 'Unable to undo reminder completion');

    return fetchReminder(reminderId: reminderId);
  }

  Future<MedicationReminder> markReminderDismissed({
    required String reminderId,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/logs'),
        headers: buildJsonHeaders(),
        body: jsonEncode(
          {
            'reminder_id': reminderId,
            'status': 'dismissed',
            'notes': 'Alarm turned off from Flutter app',
          },
        ),
      ),
    );
    _ensureSuccess(response, 'Unable to dismiss reminder');

    return fetchReminder(reminderId: reminderId);
  }

  Future<MedicationReminder> snoozeReminder({
    required String reminderId,
    int minutes = 10,
  }) async {
    final response = await _send(
      () => _client.put(
        _uri('/api/reminders/$reminderId/snooze'),
        headers: buildJsonHeaders(),
        body: jsonEncode({'minutes': minutes}),
      ),
    );
    _ensureSuccess(response, 'Unable to snooze reminder');

    return fetchReminder(reminderId: reminderId);
  }

  Future<MedicationReminder> fetchReminder({
    required String reminderId,
  }) async {
    final response = await _send(
      () => _client.get(_uri('/api/reminders/$reminderId')),
    );
    _ensureSuccess(response, 'Unable to load reminder');

    final reminderBody = jsonDecode(response.body) as Map<String, dynamic>;
    return MedicationReminder.fromJson(reminderBody);
  }

  void dispose() {
    _client.close();
  }

  Future<http.Response> _send(
    Future<http.Response> Function() requestFactory,
  ) async {
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await requestFactory().timeout(
          const Duration(seconds: AppConfig.apiRequestTimeoutSeconds),
        );
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }
    }

    throw ReminderApiException(
      lastError is TimeoutException
          ? 'The server is taking too long to respond. Please try again.'
          : 'Unable to connect to the backend right now.',
    );
  }

  void _ensureSuccess(http.Response response, String message) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['error']?.toString() ?? body['message']?.toString();
      } catch (_) {
        errorMessage = null;
      }
      throw ReminderApiException(errorMessage ?? message);
    }
  }

  int _sortByTime(MedicationReminder first, MedicationReminder second) {
    final firstMinutes = first.time.hour * 60 + first.time.minute;
    final secondMinutes = second.time.hour * 60 + second.time.minute;
    return firstMinutes.compareTo(secondMinutes);
  }

  String _toApiTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class ReminderApiException implements Exception {
  ReminderApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MissedReminderResult {
  MissedReminderResult({
    required this.message,
    required this.reminder,
    required this.successfulNotifications,
    required this.failedNotifications,
  });

  final String message;
  final MedicationReminder reminder;
  final int successfulNotifications;
  final int failedNotifications;

  factory MissedReminderResult.fromJson(Map<String, dynamic> json) {
    final reminderJson = (json['reminder'] as Map<String, dynamic>? ?? const {});
    final notificationPayload =
        json['notifications'] as Map<String, dynamic>? ?? const {};
    final notifications =
        notificationPayload['notifications'] as List<dynamic>? ?? const [];
    var successCount = 0;
    var failureCount = 0;

    for (final entry in notifications) {
      final results = (entry as Map<String, dynamic>)['results'] as List<dynamic>? ?? const [];
      for (final result in results) {
        final success = (result as Map<String, dynamic>)['success'] as bool? ?? false;
        if (success) {
          successCount++;
        } else {
          failureCount++;
        }
      }
    }

    return MissedReminderResult(
      message: (json['message'] ?? 'Reminder marked as missed').toString(),
      reminder: MedicationReminder.fromJson(reminderJson),
      successfulNotifications: successCount,
      failedNotifications: failureCount,
    );
  }
}
