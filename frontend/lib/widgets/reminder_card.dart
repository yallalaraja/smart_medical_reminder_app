import 'package:flutter/material.dart';

import '../models/medication_reminder.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onDone,
    required this.onSnooze,
    required this.onMissed,
    required this.onEdit,
    required this.onDelete,
    required this.onUndo,
    required this.onSpeak,
    required this.onTurnOffAlarm,
    this.isAlarmActive = false,
  });

  final MedicationReminder reminder;
  final VoidCallback onDone;
  final VoidCallback onSnooze;
  final VoidCallback onMissed;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUndo;
  final VoidCallback onSpeak;
  final VoidCallback onTurnOffAlarm;
  final bool isAlarmActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = reminder.status == ReminderStatus.done;
    final isDismissed = reminder.status == ReminderStatus.dismissed;
    final isSnoozed = reminder.status == ReminderStatus.snoozed;
    final isMissed = reminder.status == ReminderStatus.missed;
    final isTriggered = reminder.status == ReminderStatus.triggered;
    final categoryColor = _categoryColor(reminder.category);

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.formattedTime(),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withAlpha(24),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          reminder.categoryLabel(),
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: reminder.statusLabel(),
                  color: isDone
                      ? const Color(0xFF2F855A)
                      : isDismissed
                          ? const Color(0xFF6B7280)
                      : isSnoozed
                          ? const Color(0xFFB7791F)
                          : isMissed
                              ? const Color(0xFFC2410C)
                          : isTriggered
                              ? const Color(0xFF7C3AED)
                          : const Color(0xFF486581),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reminder.title,
              style: theme.textTheme.headlineMedium,
            ),
            if (reminder.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reminder.description,
                style: theme.textTheme.bodyLarge,
              ),
            ],
            if (reminder.hasCustomAlertAudio) ...[
              const SizedBox(height: 10),
              Text(
                'Alarm audio: ${reminder.alertAudioName ?? 'Custom audio'}',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF486581),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Repeats: ${reminder.repeatLabel()}',
              style: TextStyle(
                fontSize: 15,
                color: const Color(0xFF486581),
                fontWeight: reminder.repeatType == 'once'
                    ? FontWeight.w500
                    : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Next alert: ${reminder.scheduleLabel()}',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF486581),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (reminder.snoozedUntil != null) ...[
              const SizedBox(height: 8),
              Text(
                'Snoozed until ${_formatDateTime(reminder.snoozedUntil!)}',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF7C5E10),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Speak'),
                ),
                if (isAlarmActive)
                  TextButton.icon(
                    onPressed: onTurnOffAlarm,
                    icon: const Icon(Icons.alarm_off_outlined),
                    label: const Text('Off Alarm'),
                  ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
                if (!isDone && !isDismissed && !isMissed)
                  TextButton.icon(
                    onPressed: onMissed,
                    icon: const Icon(Icons.sms_failed_outlined),
                    label: const Text('Missed'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isDone ? onUndo : onDone,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: Text(
                      isDone ? 'Undo' : 'Done',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isDone ? null : onSnooze,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text(
                      'Snooze',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'medicine':
        return const Color(0xFFB45309);
      case 'health':
        return const Color(0xFF2F855A);
      case 'study':
        return const Color(0xFF1D4ED8);
      case 'custom':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0F766E);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
