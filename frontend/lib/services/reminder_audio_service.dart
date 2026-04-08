import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/medication_reminder.dart';

class ReminderAudioService {
  ReminderAudioService._();

  static final ReminderAudioService instance = ReminderAudioService._();

  final AudioPlayer _player = AudioPlayer();
  Timer? _clipStopTimer;
  Timer? _loopRestartTimer;
  DateTime? _loopEndsAt;
  String? _currentFilePath;

  Future<bool> startAlertForReminder(
    MedicationReminder reminder, {
    int maxMinutes = AppConfig.reminderAlertLoopMinutes,
  }) async {
    if (!reminder.hasCustomAlertAudio) {
      return false;
    }

    if (reminder.alertAudioPath == null ||
      reminder.alertAudioPath!.trim().isEmpty) {
      print("❌ Audio path is NULL or EMPTY");
      return false;
    }

    return startLoopingFile(
      reminder.alertAudioPath!,
      maxMinutes: maxMinutes,
    );
  }

  Future<bool> previewReminderAudio(MedicationReminder reminder) async {
    if (!reminder.hasCustomAlertAudio) {
      return false;
    }

    return startLoopingFile(
      reminder.alertAudioPath!,
      maxMinutes: 1,
      clipSeconds: AppConfig.reminderAudioPreviewSeconds,
    );
  }

  Future<bool> startLoopingFile(
    String filePath, {
    int maxMinutes = AppConfig.reminderAlertLoopMinutes,
    int clipSeconds = AppConfig.reminderAudioPreviewSeconds,
  }) async {
    if (filePath.trim().isEmpty) {
      return false;
    }

    await stop();

    _currentFilePath = filePath;
    _loopEndsAt = DateTime.now().add(Duration(minutes: maxMinutes));

    return _playNextClip(clipSeconds: clipSeconds);
  }

  Future<bool> _playNextClip({
    required int clipSeconds,
  }) async {
    final filePath = _currentFilePath;
    final loopEndsAt = _loopEndsAt;
    if (filePath == null || loopEndsAt == null) {
      return false;
    }

    if (!DateTime.now().isBefore(loopEndsAt)) {
      await stop();
      return false;
    }

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      if (kIsWeb) {
        await _player.play(UrlSource(filePath));
      } else {
        await _player.play(DeviceFileSource(filePath));
      }

      _clipStopTimer?.cancel();
      _clipStopTimer = Timer(Duration(seconds: clipSeconds), () async {
        try {
          await _player.stop();
        } catch (_) {
          // Ignore stop failures for local clip playback.
        }
      });

      _loopRestartTimer?.cancel();
      _loopRestartTimer = Timer(Duration(seconds: clipSeconds), () async {
        await _playNextClip(clipSeconds: clipSeconds);
      });

      return true;
    } catch (_) {
      await stop();
      return false;
    }
  }

  Future<void> stop() async {
    _clipStopTimer?.cancel();
    _clipStopTimer = null;
    _loopRestartTimer?.cancel();
    _loopRestartTimer = null;
    _loopEndsAt = null;
    _currentFilePath = null;

    try {
      await _player.stop();
    } catch (_) {
      // Ignore stop failures.
    }
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
