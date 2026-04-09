import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/medication_reminder.dart';
import '../services/reminder_api_service.dart';
import '../services/reminder_audio_service.dart';
import '../services/reminder_notification_service.dart';
import '../services/reminder_tts_service.dart';
import '../services/timezone_sync_service.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/reminder_card.dart';
import 'add_reminder_screen.dart';
import 'caregivers_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.initialReminders,
  });

  final List<MedicationReminder> initialReminders;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Duration _backgroundSyncInterval = Duration(minutes: 1);

  late final ReminderApiService _apiService;
  final ReminderNotificationService _notificationService =
      ReminderNotificationService.instance;
  final ReminderAudioService _audioService = ReminderAudioService.instance;
  final ReminderTtsService _ttsService = ReminderTtsService.instance;
  final TimezoneSyncService _timezoneSyncService = TimezoneSyncService.instance;
  late final List<MedicationReminder> _reminders;
  Timer? _dueReminderTimer;
  Timer? _reminderSyncTimer;
  final Set<String> _suppressedDueReminderIds = <String>{};
  bool _isLoading = true;
  bool _isCheckingDueReminders = false;
  bool _isSyncingReminders = false;
  String? _errorMessage;
  String? _activeDueReminderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiService = ReminderApiService();
    _reminders = List<MedicationReminder>.from(widget.initialReminders);
    _sortReminders();
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dueReminderTimer?.cancel();
    _reminderSyncTimer?.cancel();
    _audioService.stop();
    _ttsService.stopLoop();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _timezoneSyncService.detectAndSyncTimezone();
    } catch (_) {
      // Keep the fallback timezone when backend sync is unavailable.
    }

    await _initializeNotifications();
    await _loadReminders();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncRemindersInBackground(forceVoice: true));
    }
  }

  Future<void> _initializeNotifications() async {
    await _ttsService.initialize();
    await _notificationService.initialize(
      onReminderTap: (payload) async {
        await _checkDueReminders(forceVoice: true);
      },
    );
    _startDueReminderWatcher();
    await _checkDueReminders();
  }

  void _startDueReminderWatcher() {
    _dueReminderTimer?.cancel();
    _dueReminderTimer = Timer.periodic(
      const Duration(seconds: AppConfig.reminderDuePollSeconds),
      (_) => _checkDueReminders(),
    );
    _reminderSyncTimer?.cancel();
    _reminderSyncTimer = Timer.periodic(
      _backgroundSyncInterval,
      (_) => unawaited(_syncRemindersInBackground()),
    );
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reminders = await _apiService.fetchDashboardReminders(
        userId: AppConfig.defaultUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reminders
          ..clear()
          ..addAll(reminders.map(_normalizeReminderForDisplay));
        _sortReminders();
        _isLoading = false;
      });

      _refreshSuppressedDueReminders();

      await _notificationService.syncReminders(_reminders);
      await _checkDueReminders(forceVoice: true);
    } on ReminderApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
      await _clearDueAlert(stopVoice: true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to connect to the backend right now.';
      });
      await _clearDueAlert(stopVoice: true);
    }
  }

  Future<void> _syncRemindersInBackground({bool forceVoice = false}) async {
    if (!mounted || _isLoading || _isSyncingReminders) {
      return;
    }

    _isSyncingReminders = true;
    try {
      final reminders = await _apiService.fetchDashboardReminders(
        userId: AppConfig.defaultUserId,
      );

      if (!mounted) {
        return;
      }

      final normalizedReminders =
          reminders.map(_normalizeReminderForDisplay).toList();
      normalizedReminders.sort((first, second) {
        final firstTime = first.nextTriggerAt() ??
            DateTime(9999, 12, 31, first.time.hour, first.time.minute);
        final secondTime = second.nextTriggerAt() ??
            DateTime(9999, 12, 31, second.time.hour, second.time.minute);
        return firstTime.compareTo(secondTime);
      });

      setState(() {
        _reminders
          ..clear()
          ..addAll(normalizedReminders);
        _errorMessage = null;
      });

      _refreshSuppressedDueReminders();
      await _notificationService.syncReminders(_reminders);
      await _checkDueReminders(forceVoice: forceVoice);
    } on ReminderApiException {
      // Keep the last successful local schedule when the backend is briefly unavailable.
    } catch (_) {
      // Ignore transient sync failures and preserve the current local reminder state.
    } finally {
      _isSyncingReminders = false;
    }
  }

  Future<void> _openAddReminder() async {
    final draftReminder = await Navigator.of(context).push<MedicationReminder>(
      MaterialPageRoute(
        builder: (_) => const AddReminderScreen(),
      ),
    );

    if (draftReminder == null) {
      return;
    }

    MedicationReminder? savedReminder;
    try {
      savedReminder = await _apiService.createReminder(
        userId: AppConfig.defaultUserId,
        reminder: draftReminder,
      );

      await _loadReminders();
    } on ReminderApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save reminder right now.'),
        ),
      );
      return;
    }

    try {
      final confirmedReminder = savedReminder!;
      await _notificationService.scheduleReminder(confirmedReminder);
      await _checkDueReminders(forceVoice: true);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${confirmedReminder.title} reminder saved'),
        ),
      );
    } on ReminderSchedulingException catch (error) {
      await _loadReminders();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (error) {
      await _loadReminders();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${savedReminder!.title} was saved, but local alarm scheduling failed on this device.',
          ),
        ),
      );
    }
  }

  Future<void> _editReminder(MedicationReminder reminder) async {
    final updatedDraft = await Navigator.of(context).push<MedicationReminder>(
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(initialReminder: reminder),
      ),
    );

    if (updatedDraft == null) {
      return;
    }

    try {
      final updatedReminder = await _apiService.updateReminder(reminder: updatedDraft);

      setState(() {
        _replaceReminder(_normalizeReminderForDisplay(updatedReminder));
      });

      await _notificationService.scheduleReminder(updatedReminder);
      await _checkDueReminders(forceVoice: true);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updatedReminder.title} updated')),
      );
    } on ReminderApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update reminder.')),
      );
    }
  }

  Future<void> _deleteReminder(MedicationReminder reminder) async {
    try {
      await _clearDueAlert(reminderId: reminder.id, stopVoice: true);
      await _apiService.deleteReminder(reminderId: reminder.id);
      await _notificationService.cancelReminder(reminder.id);

      setState(() {
        _reminders.removeWhere((item) => item.id == reminder.id);
      });

      await _checkDueReminders(forceVoice: true);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${reminder.title} deleted')),
      );
    } on ReminderApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete reminder.')),
      );
    }
  }

  Future<void> _markDone(String reminderId) async {
    final reminder = _reminders.firstWhere((item) => item.id == reminderId);
    final optimisticReminder = _normalizeReminderForDisplay(
      reminder.copyWith(
        status: ReminderStatus.done,
        lastCompletedAt: DateTime.now(),
        clearSnoozedUntil: true,
        lastTriggeredAt: null,
      ),
    );

    try {
      _suppressedDueReminderIds.add(reminderId);
      await _clearDueAlert(reminderId: reminderId, stopVoice: true);
      await _notificationService.cancelReminder(reminderId);

      setState(() {
        _replaceReminder(optimisticReminder);
      });
      _refreshSuppressedDueReminders();

      final updatedReminder = await _apiService.markReminderDone(
        reminderId: reminderId,
      );

      final displayReminder = _normalizeReminderForDisplay(
        updatedReminder.copyWith(
          status: ReminderStatus.done,
          lastCompletedAt: updatedReminder.lastCompletedAt ?? DateTime.now(),
          clearSnoozedUntil: true,
          lastTriggeredAt: null,
        ),
      );
      setState(() {
        _replaceReminder(displayReminder);
      });
      _refreshSuppressedDueReminders();

      await _notificationService.scheduleReminder(displayReminder);
      await _checkDueReminders(forceVoice: true);
    } on ReminderApiException catch (error) {
      _suppressedDueReminderIds.remove(reminderId);
      setState(() {
        _replaceReminder(reminder);
      });
      _refreshSuppressedDueReminders();
      await _notificationService.scheduleReminder(reminder);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    } catch (_) {
      _suppressedDueReminderIds.remove(reminderId);
      setState(() {
        _replaceReminder(reminder);
      });
      _refreshSuppressedDueReminders();
      await _notificationService.scheduleReminder(reminder);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update reminder. Please try again.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reminder.isRecurring
              ? '${reminder.title} logged. Next reminder scheduled.'
              : '${reminder.title} marked as done',
        ),
      ),
    );
  }

  Future<void> _markMissed(String reminderId) async {
    final reminder = _reminders.firstWhere((item) => item.id == reminderId);

    try {
      _suppressedDueReminderIds.add(reminderId);
      await _clearDueAlert(reminderId: reminderId, stopVoice: true);
      await _notificationService.cancelReminder(reminderId);

      final result = await _apiService.markReminderMissed(reminderId: reminderId);
      final updatedReminder = _normalizeReminderForDisplay(
        result.reminder.copyWith(
          status: ReminderStatus.missed,
          latestActionAt: DateTime.now(),
          clearSnoozedUntil: true,
          lastTriggeredAt: null,
        ),
      );

      setState(() {
        _replaceReminder(updatedReminder);
      });
      _refreshSuppressedDueReminders();

      await _notificationService.scheduleReminder(updatedReminder);
      await _checkDueReminders(forceVoice: true);

      if (!mounted) {
        return;
      }

      final feedback = result.successfulNotifications > 0
          ? 'Missed reminder saved and ${result.successfulNotifications} caregiver alert(s) sent.'
          : 'Missed reminder saved, but caregiver alerts were not delivered.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(feedback)),
      );
    } on ReminderApiException catch (error) {
      _suppressedDueReminderIds.remove(reminderId);
      await _notificationService.scheduleReminder(reminder);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      _suppressedDueReminderIds.remove(reminderId);
      await _notificationService.scheduleReminder(reminder);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark reminder as missed.')),
      );
    }
  }

  Future<void> _undoDone(String reminderId) async {
    final reminder = _reminders.firstWhere((item) => item.id == reminderId);

    try {
      _suppressedDueReminderIds.remove(reminderId);
      await _clearDueAlert(reminderId: reminderId, stopVoice: true);
      final updatedReminder = await _apiService.markReminderPending(
        reminderId: reminderId,
      );

      final displayReminder = _normalizeReminderForDisplay(
        updatedReminder.copyWith(status: ReminderStatus.pending),
      );

      setState(() {
        _replaceReminder(displayReminder);
      });
      _refreshSuppressedDueReminders();

      await _notificationService.scheduleReminder(displayReminder);
      await _checkDueReminders(forceVoice: true);
    } on ReminderApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not undo reminder completion.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${reminder.title} is pending again'),
      ),
    );
  }

  Future<void> _snoozeReminder(String reminderId) async {
    final reminder = _reminders.firstWhere((item) => item.id == reminderId);

    try {
      _suppressedDueReminderIds.add(reminderId);
      await _clearDueAlert(reminderId: reminderId, stopVoice: true);
      await _notificationService.cancelReminder(reminderId);
      final updatedReminder = await _apiService.snoozeReminder(
        reminderId: reminderId,
      );

      final displayReminder = _normalizeReminderForDisplay(updatedReminder);
      setState(() {
        _replaceReminder(displayReminder);
      });
      _refreshSuppressedDueReminders();

      await _notificationService.scheduleReminder(displayReminder);
      await _checkDueReminders(forceVoice: true);
    } on ReminderApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not snooze reminder.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${reminder.title} snoozed for 10 minutes'),
      ),
    );
  }

  Future<void> _dismissDueAlert(String reminderId) async {
    await _clearDueAlert(reminderId: reminderId, stopVoice: true);
  }

  Future<void> _turnOffAlarm(String reminderId) async {
    _suppressedDueReminderIds.add(reminderId);
    await _clearDueAlert(reminderId: reminderId, stopVoice: true);
    await _notificationService.cancelReminder(reminderId);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alarm turned off for now'),
      ),
    );
  }

  Future<void> _speakReminder(MedicationReminder reminder) async {
    final didSpeak = reminder.hasCustomAlertAudio
        ? await _audioService.previewReminderAudio(reminder)
        : await _ttsService.speakReminder(reminder);
    if (!mounted) {
      return;
    }

    if (!didSpeak) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminder.hasCustomAlertAudio
                ? 'Custom alarm audio could not start on this device.'
                : 'Voice playback could not start on this device or browser.',
          ),
        ),
      );
    }
  }

  Future<void> _clearDueAlert({
    String? reminderId,
    bool stopVoice = false,
  }) async {
    if (!mounted) {
      return;
    }

    if (reminderId != null && _activeDueReminderId != reminderId) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    if (_activeDueReminderId != null) {
      setState(() {
        _activeDueReminderId = null;
      });
    }

    if (stopVoice) {
      await _audioService.stop();
      await _ttsService.stopLoop();
    }
  }

  Future<void> _startReminderAlert(MedicationReminder reminder) async {
    final didPlayAudio = await _audioService.startAlertForReminder(
      reminder,
      maxMinutes: AppConfig.reminderAlertLoopMinutes,
    );

    if (didPlayAudio) {
      await _ttsService.stopLoop();
      return;
    }

    await _ttsService.startLoopingText(
      reminder.voiceMessage?.trim().isNotEmpty == true
          ? reminder.voiceMessage!.trim()
          : 'It is time for ${reminder.title}',
      maxMinutes: AppConfig.reminderAlertLoopMinutes,
    );
  }

  Future<void> _checkDueReminders({bool forceVoice = false}) async {
    if (!mounted || _isLoading || _isCheckingDueReminders) {
      return;
    }

    _isCheckingDueReminders = true;
    try {
      final now = DateTime.now();
      final dueReminder = _findDueReminder(now);

      if (dueReminder == null) {
        await _clearDueAlert(stopVoice: true);
        return;
      }

      var displayReminder = dueReminder;
      if (dueReminder.shouldMarkTriggered(
        now: now,
        loopMinutes: AppConfig.reminderAlertLoopMinutes,
      )) {
        try {
          final triggeredReminder = await _apiService.markReminderTriggered(
            reminderId: dueReminder.id,
          );
          displayReminder = _normalizeReminderForDisplay(triggeredReminder);

          if (mounted) {
            setState(() {
              _replaceReminder(displayReminder);
            });
          }
        } catch (_) {
          displayReminder = _normalizeReminderForDisplay(dueReminder);
        }
      }

      final shouldRestartVoice =
          forceVoice || _activeDueReminderId != displayReminder.id;
      _showDueBanner(displayReminder);

      if (shouldRestartVoice) {
        await _startReminderAlert(displayReminder);
      }
    } finally {
      _isCheckingDueReminders = false;
    }
  }

  MedicationReminder? _findDueReminder(DateTime now) {
    final dueReminders = _reminders
        .map(_normalizeReminderForDisplay)
        .where(
          (reminder) =>
              !_suppressedDueReminderIds.contains(reminder.id) &&
              reminder.activeAlertWindowStart(
                    now: now,
                    loopMinutes: AppConfig.reminderAlertLoopMinutes,
                  ) !=
                  null,
        )
        .toList();

    if (dueReminders.isEmpty) {
      return null;
    }

    MedicationReminder? activeReminder;
    if (_activeDueReminderId != null) {
      for (final reminder in dueReminders) {
        if (reminder.id == _activeDueReminderId) {
          activeReminder = reminder;
          break;
        }
      }
    }
    if (activeReminder != null) {
      return activeReminder;
    }

    dueReminders.sort((first, second) {
      final firstStart = first.activeAlertWindowStart(
            now: now,
            loopMinutes: AppConfig.reminderAlertLoopMinutes,
          ) ??
          now;
      final secondStart = second.activeAlertWindowStart(
            now: now,
            loopMinutes: AppConfig.reminderAlertLoopMinutes,
          ) ??
          now;
      return firstStart.compareTo(secondStart);
    });

    return dueReminders.first;
  }

  void _showDueBanner(MedicationReminder reminder) {
    if (!mounted) {
      return;
    }

    if (_activeDueReminderId == reminder.id) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    setState(() {
      _activeDueReminderId = reminder.id;
    });

    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFFF8E8D2),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${reminder.title} is due now',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reminder.notificationBody(),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        leading: const Icon(
          Icons.notifications_active,
          color: Color(0xFFB45309),
        ),
        actions: [
          TextButton(
            onPressed: () => _snoozeReminder(reminder.id),
            child: const Text('Snooze'),
          ),
          TextButton(
            onPressed: () => _turnOffAlarm(reminder.id),
            child: const Text('Off Alarm'),
          ),
          TextButton(
            onPressed: () => _dismissDueAlert(reminder.id),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _replaceReminder(MedicationReminder updatedReminder) {
    final index = _reminders.indexWhere((item) => item.id == updatedReminder.id);
    if (index == -1) {
      return;
    }

    _reminders[index] = updatedReminder;
    _refreshSuppressedDueReminders();
    _sortReminders();
  }

  void _refreshSuppressedDueReminders() {
    final now = DateTime.now();
    _suppressedDueReminderIds.removeWhere((reminderId) {
      final match = _reminders.where((item) => item.id == reminderId);
      if (match.isEmpty) {
        return true;
      }

      final reminder = _normalizeReminderForDisplay(match.first);
      return reminder.activeAlertWindowStart(
            now: now,
            loopMinutes: AppConfig.reminderAlertLoopMinutes,
          ) ==
          null;
    });
  }

  void _sortReminders() {
    _reminders.sort((first, second) {
      final firstTime = first.nextTriggerAt() ??
          DateTime(9999, 12, 31, first.time.hour, first.time.minute);
      final secondTime = second.nextTriggerAt() ??
          DateTime(9999, 12, 31, second.time.hour, second.time.minute);
      return firstTime.compareTo(secondTime);
    });
  }

  MedicationReminder _normalizeReminderForDisplay(MedicationReminder reminder) {
    return reminder.normalizedForDisplay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Reminder'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CaregiversScreen()),
              );
            },
            tooltip: 'Caregivers',
            icon: const Icon(Icons.people_alt_outlined),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadReminders,
            tooltip: 'Refresh reminders',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Reminders',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Use reminders for medicine, study, routines, food, or any task you want to remember.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? _ErrorStateCard(
                            message: _errorMessage!,
                            onRetry: _loadReminders,
                          )
                        : _reminders.isEmpty
                            ? const EmptyStateCard()
                            : RefreshIndicator(
                                onRefresh: _loadReminders,
                                child: ListView.separated(
                                    itemCount: _reminders.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 16),
                                    itemBuilder: (context, index) {
                                      final reminder = _reminders[index];
                                      return ReminderCard(
                                        reminder: reminder,
                                        isAlarmActive:
                                            _activeDueReminderId == reminder.id,
                                        onDone: () => _markDone(reminder.id),
                                        onSnooze: () => _snoozeReminder(reminder.id),
                                        onMissed: () => _markMissed(reminder.id),
                                        onEdit: () => _editReminder(reminder),
                                        onDelete: () => _deleteReminder(reminder),
                                        onUndo: () => _undoDone(reminder.id),
                                        onSpeak: () => _speakReminder(reminder),
                                        onTurnOffAlarm: () =>
                                            _turnOffAlarm(reminder.id),
                                      );
                                    },
                                  ),
                              ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddReminder,
        label: const Text('Add Reminder'),
        icon: const Icon(Icons.add_alarm),
      ),
    );
  }
}

class _ErrorStateCard extends StatelessWidget {
  const _ErrorStateCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 64,
                color: Color(0xFFB7791F),
              ),
              const SizedBox(height: 16),
              Text(
                'Backend unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
