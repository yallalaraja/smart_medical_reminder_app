import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../config/app_config.dart';
import '../models/medication_reminder.dart';

class ReminderTtsService {
  ReminderTtsService._();

  static final ReminderTtsService instance = ReminderTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _ttsReady = false;
  bool _speaking = false;
  Timer? _loopTimer;
  DateTime? _loopEndsAt;
  String? _currentLoopText;
  Future<void>? _initializationFuture;

  Future<void> initialize() async {
    if (_initialized && _ttsReady) {
      return;
    }

    final existing = _initializationFuture;
    if (existing != null) {
      await existing;
      return;
    }

    _initializationFuture = _initializeInternal();
    try {
      await _initializationFuture;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    _ttsReady = false;

    try {
      _tts.setStartHandler(() {
        _speaking = true;
        _ttsReady = true;
      });
      _tts.setCompletionHandler(() {
        _speaking = false;
      });
      _tts.setCancelHandler(() {
        _speaking = false;
      });
      _tts.setErrorHandler((_) {
        _speaking = false;
        _ttsReady = false;
      });

      if (!kIsWeb) {
        await _tts.awaitSpeakCompletion(true);
      }
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      if (defaultTargetPlatform == TargetPlatform.android) {
        await _tts.setQueueMode(1);
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      _ttsReady = true;
    } catch (_) {
      // Keep initialization best-effort so the UI can surface a clear error later.
      _ttsReady = false;
    }

    _initialized = true;
  }

  Future<bool> speakReminder(MedicationReminder reminder) async {
    await initialize();
    final message = reminder.voiceMessage?.trim().isNotEmpty == true
        ? reminder.voiceMessage!.trim()
        : 'It is time for ${reminder.title}';

    return speakText(message);
  }

  Future<bool> startLoopingText(
    String text, {
    int maxMinutes = 10,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return false;
    }

    await stopLoop();

    _currentLoopText = normalized;
    _loopEndsAt = DateTime.now().add(Duration(minutes: maxMinutes));

    final didSpeak = await speakText(normalized);
    if (!didSpeak) {
      _currentLoopText = null;
      _loopEndsAt = null;
      return false;
    }

    _loopTimer = Timer.periodic(
      const Duration(seconds: AppConfig.reminderVoiceRepeatSeconds),
      (timer) async {
        if (_currentLoopText == null || _loopEndsAt == null) {
          await stopLoop();
          return;
        }

        if (!DateTime.now().isBefore(_loopEndsAt!)) {
          await stopLoop();
          return;
        }

        if (_speaking) {
          return;
        }

        await speakText(_currentLoopText!);
      },
    );

    return true;
  }

  Future<bool> speakText(String text) async {
    if (text.trim().isEmpty) {
      return false;
    }

    return _speakWithRetry(text.trim());
  }

  Future<bool> _speakWithRetry(String text, {bool allowRetry = true}) async {
    await initialize();
    if (!_ttsReady && defaultTargetPlatform == TargetPlatform.android) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    try {
      if (_speaking) {
        await _tts.stop();
        _speaking = false;
      }

      final result = await _tts.speak(text);
      final didStart = result is int
          ? result == 1
          : result is bool
              ? result
              : true;

      if (didStart) {
        _ttsReady = true;
        return true;
      }

      if (!allowRetry) {
        return false;
      }
    } catch (_) {
      _speaking = false;
      _ttsReady = false;
      if (!allowRetry) {
        return false;
      }
    }

    _initialized = false;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _speakWithRetry(text, allowRetry: false);
  }

  Future<void> stop() async {
    try {
      if (_ttsReady || _speaking) {
        await _tts.stop();
      }
    } catch (_) {
      // Ignore stop failures.
    } finally {
      _speaking = false;
    }
  }

  Future<void> stopLoop() async {
    _loopTimer?.cancel();
    _loopTimer = null;
    _loopEndsAt = null;
    _currentLoopText = null;
    await stop();
  }
}
