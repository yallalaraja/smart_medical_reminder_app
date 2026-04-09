import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';
import '../models/medication_reminder.dart';

class ReminderNotificationService {
  ReminderNotificationService._();

  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _canScheduleExactAlarms = false;

  Future<void> initialize({
    Future<void> Function(NotificationReminderPayload payload)? onReminderTap,
  }) async {
    if (_initialized || kIsWeb) {
      return;
    }

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(AppConfig.currentDeviceTimeZone));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation(AppConfig.defaultReminderTimeZone));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (onReminderTap == null || response.payload == null) {
          return;
        }

        final payloadJson =
            jsonDecode(response.payload!) as Map<String, dynamic>;
        await onReminderTap(NotificationReminderPayload.fromJson(payloadJson));
      },
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _canScheduleExactAlarms =
        await androidPlugin?.requestExactAlarmsPermission() ?? false;

    _initialized = true;
  }

  Future<void> syncReminders(List<MedicationReminder> reminders) async {
    if (kIsWeb) {
      return;
    }

    await initialize();

    for (final reminder in reminders) {
      await scheduleReminder(reminder);
    }
  }

  Future<void> scheduleReminder(MedicationReminder reminder) async {
    if (kIsWeb) {
      return;
    }

    await initialize();
    await cancelReminder(reminder.id);

    final alertMoments = reminder.alertMoments(
      loopMinutes: AppConfig.reminderAlertLoopMinutes,
    );
    if (alertMoments.isEmpty) {
      return;
    }

    for (var index = 0; index < alertMoments.length; index++) {
      final scheduledTime = tz.TZDateTime.from(alertMoments[index], tz.local);
      final payload = jsonEncode(
        NotificationReminderPayload(
          reminderId: reminder.id,
          title: reminder.title,
          message: reminder.voiceMessage ?? reminder.notificationBody(),
        ).toJson(),
      );

      try {
        await _plugin.zonedSchedule(
          _notificationId(reminder.id, slot: index),
          reminder.notificationTitle(),
          reminder.notificationBody(),
          scheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'smart_reminder_channel',
              'Smart Reminder Alerts',
              channelDescription: 'Reminder notifications for important tasks',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              visibility: NotificationVisibility.public,
              category: AndroidNotificationCategory.alarm,
              fullScreenIntent: true,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              ticker: 'Smart Reminder Alert',
            ),
          ),
          payload: payload,
          androidScheduleMode: _canScheduleExactAlarms
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (error) {
        try {
          await _plugin.zonedSchedule(
            _notificationId(reminder.id, slot: index),
            reminder.notificationTitle(),
            reminder.notificationBody(),
            scheduledTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'smart_reminder_channel',
                'Smart Reminder Alerts',
                channelDescription: 'Reminder notifications for important tasks',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
                visibility: NotificationVisibility.public,
                category: AndroidNotificationCategory.reminder,
                ticker: 'Smart Reminder Alert',
              ),
            ),
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (fallbackError) {
          throw ReminderSchedulingException(
            'Could not schedule alarm on this device. Exact alarm error: $error. Fallback error: $fallbackError',
          );
        }
      }
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    if (kIsWeb) {
      return;
    }

    await initialize();
    for (var slot = 0; slot < AppConfig.reminderAlertLoopMinutes; slot++) {
      await _plugin.cancel(_notificationId(reminderId, slot: slot));
    }
  }

  int _notificationId(String reminderId, {int slot = 0}) {
    final parsed = int.tryParse(reminderId);
    if (parsed != null) {
      return (parsed * 100) + slot;
    }
    final stableHash = reminderId.hashCode & 0x0fffffff;
    return (stableHash * 100) + slot;
  }
}

class ReminderSchedulingException implements Exception {
  ReminderSchedulingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationReminderPayload {
  NotificationReminderPayload({
    required this.reminderId,
    required this.title,
    required this.message,
  });

  final String reminderId;
  final String title;
  final String message;

  Map<String, dynamic> toJson() => {
        'reminder_id': reminderId,
        'title': title,
        'message': message,
      };

  factory NotificationReminderPayload.fromJson(Map<String, dynamic> json) {
    return NotificationReminderPayload(
      reminderId: json['reminder_id'].toString(),
      title: json['title']?.toString() ?? 'Reminder',
      message: json['message']?.toString() ?? '',
    );
  }
}
