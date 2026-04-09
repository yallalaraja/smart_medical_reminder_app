import 'package:flutter/material.dart';

enum ReminderStatus { pending, triggered, done, dismissed, snoozed, missed }

class MedicationReminder {
  MedicationReminder({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.time,
    this.repeatType = 'once',
    this.selectedDays = const [],
    this.status = ReminderStatus.pending,
    this.voiceMessage,
    this.alertAudioPath,
    this.alertAudioName,
    this.isActive = true,
    this.scheduledDate,
    this.snoozedUntil,
    this.lastTriggeredAt,
    this.lastCompletedAt,
    this.latestActionAt,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final TimeOfDay time;
  final String repeatType;
  final List<String> selectedDays;
  final ReminderStatus status;
  final String? voiceMessage;
  final String? alertAudioPath;
  final String? alertAudioName;
  final bool isActive;
  final DateTime? scheduledDate;
  final DateTime? snoozedUntil;
  final DateTime? lastTriggeredAt;
  final DateTime? lastCompletedAt;
  final DateTime? latestActionAt;

  MedicationReminder copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    TimeOfDay? time,
    String? repeatType,
    List<String>? selectedDays,
    ReminderStatus? status,
    String? voiceMessage,
    String? alertAudioPath,
    String? alertAudioName,
    bool? isActive,
    DateTime? scheduledDate,
    DateTime? snoozedUntil,
    DateTime? lastTriggeredAt,
    DateTime? lastCompletedAt,
    DateTime? latestActionAt,
    bool clearSnoozedUntil = false,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      time: time ?? this.time,
      repeatType: repeatType ?? this.repeatType,
      selectedDays: selectedDays ?? this.selectedDays,
      status: status ?? this.status,
      voiceMessage: voiceMessage ?? this.voiceMessage,
      alertAudioPath: alertAudioPath ?? this.alertAudioPath,
      alertAudioName: alertAudioName ?? this.alertAudioName,
      isActive: isActive ?? this.isActive,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      snoozedUntil: clearSnoozedUntil ? null : snoozedUntil ?? this.snoozedUntil,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      latestActionAt: latestActionAt ?? this.latestActionAt,
    );
  }

  String formattedTime() {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String statusLabel() {
    switch (status) {
      case ReminderStatus.done:
        return 'Completed';
      case ReminderStatus.dismissed:
        return 'Dismissed';
      case ReminderStatus.snoozed:
        return 'Snoozed';
      case ReminderStatus.missed:
        return 'Missed';
      case ReminderStatus.triggered:
        return 'Triggered';
      case ReminderStatus.pending:
        return 'Scheduled';
    }
  }

  static MedicationReminder fromJson(Map<String, dynamic> reminderJson) {
    final timeParts = (reminderJson['time_of_day'] as String? ?? '08:00').split(':');
    final selectedDaysRaw = reminderJson['selected_days'];
    final selectedDays = selectedDaysRaw == null
        ? <String>[]
        : selectedDaysRaw
            .toString()
            .split(',')
            .map((day) => day.trim())
            .where((day) => day.isNotEmpty)
            .toList();

    return MedicationReminder(
      id: reminderJson['id'].toString(),
      title: (reminderJson['title'] ?? 'Reminder').toString(),
      description: (reminderJson['description'] ?? '').toString(),
      category: (reminderJson['category'] ?? 'personal').toString(),
      scheduledDate: reminderJson['scheduled_date'] != null
          ? DateTime.tryParse(reminderJson['scheduled_date'].toString())
          : null,
      time: TimeOfDay(
        hour: int.tryParse(timeParts.first) ?? 8,
        minute: int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0,
      ),
      repeatType: (reminderJson['repeat_type'] ?? 'once').toString(),
      selectedDays: selectedDays,
      voiceMessage: reminderJson['voice_message']?.toString(),
      alertAudioPath: reminderJson['alert_audio_path']?.toString(),
      alertAudioName: reminderJson['alert_audio_name']?.toString(),
      isActive: reminderJson['is_active'] as bool? ?? true,
      snoozedUntil: reminderJson['snoozed_until'] != null
          ? DateTime.tryParse(reminderJson['snoozed_until'].toString())
          : null,
      lastTriggeredAt: reminderJson['last_triggered_at'] != null
          ? DateTime.tryParse(reminderJson['last_triggered_at'].toString())
          : null,
      lastCompletedAt: reminderJson['last_completed_at'] != null
          ? DateTime.tryParse(reminderJson['last_completed_at'].toString())
          : null,
      latestActionAt: reminderJson['latest_action_time'] != null
          ? DateTime.tryParse(reminderJson['latest_action_time'].toString())
          : null,
      status: _statusFromApi(
        reminderJson['lifecycle_status']?.toString() ??
            reminderJson['latest_status']?.toString(),
      ),
    );
  }

  String repeatLabel() {
    switch (repeatType) {
      case 'daily':
        return 'Daily';
      case 'weekdays':
        return 'Weekdays';
      case 'weekends':
        return 'Weekends';
      case 'custom':
        return selectedDays.isEmpty ? 'Custom' : selectedDays.join(', ');
      default:
        return 'One-time';
    }
  }

  String categoryLabel() {
    final normalized = category.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'Personal';
    }
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  bool get isRecurring => repeatType != 'once';

  bool get canUndo => status == ReminderStatus.done;

  bool get hasCustomAlertAudio =>
      (alertAudioPath?.trim().isNotEmpty == true) ||
      (alertAudioName?.trim().isNotEmpty == true);

  String notificationTitle() => title;

  String notificationBody() {
    if (voiceMessage?.trim().isNotEmpty == true) {
      return voiceMessage!.trim();
    }
    if (description.trim().isNotEmpty) {
      return description.trim();
    }
    return 'Scheduled for ${formattedTime()}';
  }

  String scheduleLabel({DateTime? now}) {
    final current = now ?? DateTime.now();
    final next = nextTriggerAt(from: current);
    if (next == null) {
      return 'No future alert';
    }

    final today = DateTime(current.year, current.month, current.day);
    final target = DateTime(next.year, next.month, next.day);
    final diffDays = target.difference(today).inDays;

    final dayLabel = switch (diffDays) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}',
    };

    return '$dayLabel at ${_formatDateTime(next)}';
  }

  MedicationReminder normalizedForDisplay({DateTime? now}) {
    final current = now ?? DateTime.now();

    if (status == ReminderStatus.snoozed &&
        snoozedUntil != null &&
        !snoozedUntil!.isAfter(current)) {
      return copyWith(
        status: ReminderStatus.pending,
        clearSnoozedUntil: true,
      );
    }

    if ((status == ReminderStatus.done ||
            status == ReminderStatus.dismissed ||
            status == ReminderStatus.missed) &&
        isRecurring) {
      final markerTime = status == ReminderStatus.done
          ? lastCompletedAt
          : latestActionAt ?? lastTriggeredAt;
      if (markerTime == null) {
        return this;
      }

      final nextCycleAt = nextTriggerAt(from: markerTime);
      if (nextCycleAt != null && current.isBefore(nextCycleAt)) {
        return this;
      }

      return copyWith(status: ReminderStatus.pending);
    }

    return this;
  }

  DateTime? nextTriggerAt({DateTime? from}) {
    final baseline = from ?? DateTime.now();

    if (!isActive) {
      return null;
    }

    if (snoozedUntil != null && snoozedUntil!.isAfter(baseline)) {
      return snoozedUntil;
    }

    if (repeatType == 'once' && lastCompletedAt != null) {
      return null;
    }

    if (repeatType == 'once') {
      if (scheduledDate == null) {
        return null;
      }

      final target = DateTime(
        scheduledDate!.year,
        scheduledDate!.month,
        scheduledDate!.day,
        time.hour,
        time.minute,
      );
      return target.isAfter(baseline) ? target : null;
    }

    for (var offset = 0; offset <= 14; offset++) {
      final sourceDate = scheduledDate != null && scheduledDate!.isAfter(baseline)
          ? scheduledDate!
          : baseline;
      final day = DateTime(
        sourceDate.year,
        sourceDate.month,
        sourceDate.day + offset,
        time.hour,
        time.minute,
      );

      final isToday = offset == 0;
      if (isToday && !day.isAfter(baseline)) {
        continue;
      }

      if (_matchesDate(day)) {
        return day;
      }
    }

    return null;
  }

  List<DateTime> alertMoments({
    DateTime? from,
    int loopMinutes = 10,
  }) {
    final firstTrigger = nextTriggerAt(from: from);
    if (firstTrigger == null) {
      return const [];
    }

    final alerts = <DateTime>[];
    for (var minute = 0; minute < loopMinutes; minute++) {
      alerts.add(firstTrigger.add(Duration(minutes: minute)));
    }
    return alerts;
  }

  DateTime? activeAlertWindowStart({
    DateTime? now,
    int loopMinutes = 10,
  }) {
    final current = now ?? DateTime.now();
    if (!isActive) {
      return null;
    }

    if (snoozedUntil != null) {
      final snoozeEnd = snoozedUntil!.add(Duration(minutes: loopMinutes));
      if (!current.isBefore(snoozedUntil!) && current.isBefore(snoozeEnd)) {
        return snoozedUntil;
      }
    }

    final occurrence = _currentOccurrenceStart(current: current, loopMinutes: loopMinutes);
    if (occurrence == null) {
      return null;
    }

    if (lastCompletedAt != null && !lastCompletedAt!.isBefore(occurrence)) {
      return null;
    }
    if ((status == ReminderStatus.dismissed || status == ReminderStatus.missed) &&
        latestActionAt != null &&
        !latestActionAt!.isBefore(occurrence)) {
      return null;
    }

    return occurrence;
  }

  bool shouldMarkTriggered({
    DateTime? now,
    int loopMinutes = 10,
  }) {
    final activeWindowStart =
        activeAlertWindowStart(now: now, loopMinutes: loopMinutes);
    if (activeWindowStart == null) {
      return false;
    }

    if (lastTriggeredAt == null) {
      return true;
    }

    return lastTriggeredAt!.isBefore(activeWindowStart);
  }

  DateTime? _currentOccurrenceStart({
    required DateTime current,
    required int loopMinutes,
  }) {
    if (repeatType == 'once') {
      if (scheduledDate == null) {
        return null;
      }

      final target = DateTime(
        scheduledDate!.year,
        scheduledDate!.month,
        scheduledDate!.day,
        time.hour,
        time.minute,
      );
      final windowEnd = target.add(Duration(minutes: loopMinutes));
      if (!current.isBefore(target) && current.isBefore(windowEnd)) {
        return target;
      }
      return null;
    }

    for (final offset in const [-1, 0]) {
      final source = DateTime(
        current.year,
        current.month,
        current.day + offset,
        time.hour,
        time.minute,
      );

      if (scheduledDate != null) {
        final startDate = DateTime(
          scheduledDate!.year,
          scheduledDate!.month,
          scheduledDate!.day,
          time.hour,
          time.minute,
        );
        if (source.isBefore(startDate)) {
          continue;
        }
      }

      if (!_matchesDate(source)) {
        continue;
      }

      final windowEnd = source.add(Duration(minutes: loopMinutes));
      if (!current.isBefore(source) && current.isBefore(windowEnd)) {
        return source;
      }
    }

    return null;
  }

  bool _matchesDate(DateTime dateTime) {
    switch (repeatType) {
      case 'daily':
        return true;
      case 'weekdays':
        return dateTime.weekday >= DateTime.monday &&
            dateTime.weekday <= DateTime.friday;
      case 'weekends':
        return dateTime.weekday == DateTime.saturday ||
            dateTime.weekday == DateTime.sunday;
      case 'custom':
        final selectedWeekdays = selectedDays.map(_weekdayFromLabel).whereType<int>();
        return selectedWeekdays.contains(dateTime.weekday);
      default:
        return true;
    }
  }

  int? _weekdayFromLabel(String label) {
    switch (label) {
      case 'Mon':
        return DateTime.monday;
      case 'Tue':
        return DateTime.tuesday;
      case 'Wed':
        return DateTime.wednesday;
      case 'Thu':
        return DateTime.thursday;
      case 'Fri':
        return DateTime.friday;
      case 'Sat':
        return DateTime.saturday;
      case 'Sun':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static ReminderStatus _statusFromApi(String? value) {
    switch (value) {
      case 'completed':
      case 'done':
        return ReminderStatus.done;
      case 'dismissed':
        return ReminderStatus.dismissed;
      case 'snoozed':
        return ReminderStatus.snoozed;
      case 'missed':
        return ReminderStatus.missed;
      case 'triggered':
        return ReminderStatus.triggered;
      default:
        return ReminderStatus.pending;
    }
  }
}
