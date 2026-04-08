import 'package:flutter/foundation.dart';

class AppConfig {
  static const int defaultUserId = 1;
  static const String defaultReminderTimeZone = 'Asia/Kolkata';
  static String currentDeviceTimeZone = defaultReminderTimeZone;
  static const int reminderAlertLoopMinutes = 10;
  static const int reminderDuePollSeconds = 15;
  static const int reminderVoiceRepeatSeconds = 8;
  static const int reminderAudioPreviewSeconds = 30;

  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000';
      case TargetPlatform.iOS:
        return 'http://127.0.0.1:5000';
      default:
        return 'http://127.0.0.1:5000';
    }
  }
}
