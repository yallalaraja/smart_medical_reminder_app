import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../config/app_config.dart';
import 'user_api_service.dart';

class TimezoneSyncService {
  TimezoneSyncService._();

  static final TimezoneSyncService instance = TimezoneSyncService._();

  final UserApiService _userApiService = UserApiService();

  Future<String> detectAndSyncTimezone() async {
    final timezoneName = kIsWeb
        ? AppConfig.currentDeviceTimeZone
        : await FlutterTimezone.getLocalTimezone();
    AppConfig.currentDeviceTimeZone = timezoneName;

    await _userApiService.updateTimezone(
      userId: AppConfig.defaultUserId,
      timezone: timezoneName,
    );

    return timezoneName;
  }

  void dispose() {
    _userApiService.dispose();
  }
}
