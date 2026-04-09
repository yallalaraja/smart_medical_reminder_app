class AppConfig {
  static const String defaultUserId = String.fromEnvironment(
    'DEFAULT_USER_ID',
    defaultValue: 'a4f9c2d1-7b6e-4c3a-9f21-8d5e7b1c2a34',
  );
  static const String defaultReminderTimeZone = 'Asia/Kolkata';
  static String currentDeviceTimeZone = defaultReminderTimeZone;
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smart-reminder-app-ey9l.onrender.com',
    // defaultValue: 'http://127.0.0.1:5000',
  );
  static const int reminderAlertLoopMinutes = 10;
  static const int reminderDuePollSeconds = 15;
  static const int reminderVoiceRepeatSeconds = 8;
  static const int reminderAudioPreviewSeconds = 30;
  static const int apiRequestTimeoutSeconds = 15;
}
