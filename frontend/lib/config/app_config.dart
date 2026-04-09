import 'package:flutter/foundation.dart';

class AppConfig {
  static const String defaultUserId = String.fromEnvironment(
    'DEFAULT_USER_ID',
    defaultValue: 'a4f9c2d1-7b6e-4c3a-9f21-8d5e7b1c2a34',
  );
  static const String defaultReminderTimeZone = 'Asia/Kolkata';
  static String currentDeviceTimeZone = defaultReminderTimeZone;
  static const String productionApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smart-reminder-app-ey9l.onrender.com',
  );
  static const bool useLocalApi = bool.fromEnvironment(
    'USE_LOCAL_API',
    defaultValue: false,
  );
  static const String localApiBaseUrl = String.fromEnvironment(
    'LOCAL_API_BASE_URL',
    defaultValue: '',
  );
  static const int reminderAlertLoopMinutes = 10;
  static const int reminderDuePollSeconds = 15;
  static const int reminderVoiceRepeatSeconds = 8;
  static const int reminderAudioPreviewSeconds = 30;

  static String get apiBaseUrl {
    if (useLocalApi) {
      if (localApiBaseUrl.isNotEmpty) {
        return localApiBaseUrl;
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

    return productionApiBaseUrl;
  }
}
