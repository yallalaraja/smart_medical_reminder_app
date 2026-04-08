import 'package:flutter/material.dart';

import '../models/caregiver.dart';

class AddCaregiverScreen extends StatefulWidget {
  const AddCaregiverScreen({super.key});

  @override
  State<AddCaregiverScreen> createState() => _AddCaregiverScreenState();
}

class _AddCaregiverScreenState extends State<AddCaregiverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _relationshipController = TextEditingController();
  String _notificationChannel = 'sms';

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final caregiver = Caregiver(
      id: '',
      userId: '',
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
      relationship: _relationshipController.text.trim(),
      notificationChannel: _notificationChannel,
    );

    Navigator.of(context).pop(caregiver);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Caregiver')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Add someone who should be notified if a reminder is missed.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter caregiver name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+919876543210',
                ),
                validator: (value) {
                  final normalized = value?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
                  final digits = normalized.replaceAll('+', '');
                  if (digits.length < 10 || digits.length > 15) {
                    return 'Enter a valid mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'Daughter, Son, Spouse',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _notificationChannel,
                decoration: const InputDecoration(labelText: 'Notification channel'),
                items: const [
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                  DropdownMenuItem(value: 'both', child: Text('SMS + WhatsApp')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _notificationChannel = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Save Caregiver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
