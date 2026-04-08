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

  Future<void> initialize({
    Future<void> Function(NotificationReminderPayload payload)? onReminderTap,
  }) async {
    if (_initialized || kIsWeb) {
      return;
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(AppConfig.currentDeviceTimeZone));

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
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

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
      await _plugin.zonedSchedule(
        _notificationId(reminder.id, slot: index),
        reminder.notificationTitle(),
        reminder.notificationBody(),
        tz.TZDateTime.from(alertMoments[index], tz.local),
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
        payload: jsonEncode(
          NotificationReminderPayload(
            reminderId: reminder.id,
            title: reminder.title,
            message: reminder.voiceMessage ?? reminder.notificationBody(),
          ).toJson(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
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
    return ((reminderId.hashCode & 0x7fffffff) * 100) + slot;
  }
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
