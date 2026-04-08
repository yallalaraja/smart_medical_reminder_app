import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:html' as html;

import '../config/app_config.dart';
import '../models/medication_reminder.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({
    super.key,
    this.initialReminder,
  });

  final MedicationReminder? initialReminder;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  static const List<String> _categories = [
    'medicine',
    'health',
    'study',
    'personal',
    'custom',
  ];
  static const List<String> _repeatOptions = [
    'once',
    'daily',
    'weekdays',
    'weekends',
    'custom',
  ];
  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _voiceMessageController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  DateTime? _selectedDate;
  String _category = 'personal';
  String _repeatType = 'once';
  String? _selectedAudioPath;
  String? _selectedAudioName;
  final Set<String> _selectedDays = <String>{};
  bool _isSaving = false;

  bool get _isEditMode => widget.initialReminder != null;

  @override
  void initState() {
    super.initState();
    final reminder = widget.initialReminder;
    if (reminder == null) {
      return;
    }

    _titleController.text = reminder.title;
    _descriptionController.text = reminder.description;
    _voiceMessageController.text = reminder.voiceMessage ?? '';
    _selectedTime = reminder.time;
    _selectedDate = reminder.scheduledDate;
    _category = reminder.category;
    _repeatType = reminder.repeatType;
    _selectedAudioPath = reminder.alertAudioPath;
    _selectedAudioName = reminder.alertAudioName;
    _selectedDays
      ..clear()
      ..addAll(reminder.selectedDays);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _voiceMessageController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

    Future<void> _pickAudioFile() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true, // ✅ important for web
      );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;

    if (kIsWeb) {
        if (file.bytes == null) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read audio file. Try another file.'),
            ),
          );
          return;
        }

        final blob = html.Blob([file.bytes!]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        setState(() {
          _selectedAudioPath = url;   // ✅ THIS IS THE FIX
          _selectedAudioName = file.name;
        });
      } else {
      // 📱 MOBILE
      if (file.path == null || file.path!.trim().isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read that audio file path.'),
          ),
        );
        return;
      }

      setState(() {
        _selectedAudioPath = file.path;
        _selectedAudioName = file.name;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_repeatType == 'custom' && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one day for a custom reminder.')),
      );
      return;
    }

    if (_repeatType == 'once' && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a date for a one-time reminder.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final reminder = MedicationReminder(
      id: widget.initialReminder?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      scheduledDate: _repeatType == 'once' ? _selectedDate : _selectedDate,
      time: _selectedTime,
      repeatType: _repeatType,
      selectedDays: _selectedDays.toList(),
      isActive: widget.initialReminder?.isActive ?? true,
      voiceMessage: _voiceMessageController.text.trim().isEmpty
          ? 'It is time for ${_titleController.text.trim()}'
          : _voiceMessageController.text.trim(),
      alertAudioPath: _selectedAudioPath,
      alertAudioName: _selectedAudioName,
      snoozedUntil: widget.initialReminder?.snoozedUntil,
      lastCompletedAt: widget.initialReminder?.lastCompletedAt,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(reminder);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Reminder' : 'Add Reminder'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFDFF4F3),
                        Color(0xFFF2EFD9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(180),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _isEditMode ? 'Reminder Editor' : 'New Reminder',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E7490),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isEditMode
                            ? 'Fine-tune this reminder'
                            : 'Plan one important moment',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Create reminders for medicine, study, workouts, meals, breaks, or anything else you do on purpose.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Reminder details',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Evening walk',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a reminder title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            category[0].toUpperCase() + category.substring(1),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _category = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Walk for 20 minutes after dinner',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Voice alert',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _voiceMessageController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Voice message',
                    hintText: 'It is time for your evening walk',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This text will be used for spoken reminders and notification wording.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    color: const Color(0xFF486581),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Alarm audio',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedAudioName ?? 'No custom audio selected',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedAudioName == null
                              ? 'Choose any local audio file. The reminder will only play the first 30 seconds.'
                              : 'Selected file will be used as the alarm sound for up to 30 seconds at a time.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                            color: const Color(0xFF486581),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _pickAudioFile,
                              icon: const Icon(Icons.library_music_outlined),
                              label: Text(
                                _selectedAudioName == null
                                    ? 'Choose Audio'
                                    : 'Change Audio',
                              ),
                            ),
                            if (_selectedAudioName != null)
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedAudioPath = null;
                                    _selectedAudioName = null;
                                  });
                                },
                                icon: const Icon(Icons.close),
                                label: const Text('Remove Audio'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Schedule',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _repeatType,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                  ),
                  items: _repeatOptions
                      .map(
                        (repeatType) => DropdownMenuItem(
                          value: repeatType,
                          child: Text(_repeatLabel(repeatType)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _repeatType = value;
                      if (_repeatType != 'custom') {
                        _selectedDays.clear();
                      }
                      if (_repeatType != 'once') {
                        _selectedDate ??= DateTime.now();
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _repeatType == 'once' ? 'Reminder date' : 'Start date',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedDate == null
                                    ? (_repeatType == 'once'
                                        ? 'Choose date'
                                        : 'Starts today')
                                    : _formatDate(_selectedDate!),
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_selectedDate == null ? 'Choose Date' : 'Change Date'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_repeatType == 'custom') ...[
                  const SizedBox(height: 20),
                  Text(
                    'Custom days',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _days
                        .map(
                          (day) => FilterChip(
                            label: Text(day),
                            selected: _selectedDays.contains(day),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDays.add(day);
                                } else {
                                  _selectedDays.remove(day);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reminder time',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTime(_selectedTime),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontSize: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.access_time),
                              label: const Text('Choose Time'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Timezone: ${_timezoneLabel()}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                            color: const Color(0xFF486581),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveReminder,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isEditMode ? 'Update Reminder' : 'Save Reminder',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _repeatLabel(String repeatType) {
    switch (repeatType) {
      case 'daily':
        return 'Daily';
      case 'weekdays':
        return 'Weekdays';
      case 'weekends':
        return 'Weekends';
      case 'custom':
        return 'Custom days';
      default:
        return 'One-time';
    }
  }

  String _timezoneLabel() {
    return AppConfig.currentDeviceTimeZone;
  }

  String _formatDate(DateTime value) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${monthNames[value.month - 1]} ${value.year}';
  }
}
