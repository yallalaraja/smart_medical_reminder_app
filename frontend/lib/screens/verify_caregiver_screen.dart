import 'package:flutter/material.dart';

import '../models/caregiver.dart';

class VerifyCaregiverScreen extends StatefulWidget {
  const VerifyCaregiverScreen({
    super.key,
    required this.caregiver,
  });

  final Caregiver caregiver;

  @override
  State<VerifyCaregiverScreen> createState() => _VerifyCaregiverScreenState();
}

class _VerifyCaregiverScreenState extends State<VerifyCaregiverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(CaregiverVerificationAction.verify(_otpController.text.trim()));
  }

  void _reject() {
    Navigator.of(context).pop(const CaregiverVerificationAction.reject());
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = widget.caregiver.otpExpiresAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Caregiver')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.caregiver.fullName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the OTP sent to ${widget.caregiver.phoneNumber}. Only verified caregivers will receive missed reminder alerts.',
                style: const TextStyle(fontSize: 17),
              ),
              if (expiresAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'OTP expires at ${_formatDateTimeIst(expiresAt)} IST',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C5E10),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'OTP code',
                  hintText: 'Enter 6 digit OTP',
                ),
                validator: (value) {
                  final otp = value?.trim() ?? '';
                  if (otp.length != 6 || int.tryParse(otp) == null) {
                    return 'Enter a valid 6 digit OTP';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Verify Caregiver'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _reject,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Reject Invitation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTimeIst(DateTime value) {
    final istTime = value.toUtc().add(const Duration(hours: 5, minutes: 30));
    final day = istTime.day.toString().padLeft(2, '0');
    final month = istTime.month.toString().padLeft(2, '0');
    final hour = istTime.hour % 12 == 0 ? 12 : istTime.hour % 12;
    final minute = istTime.minute.toString().padLeft(2, '0');
    final period = istTime.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${istTime.year} $hour:$minute $period';
  }
}

class CaregiverVerificationAction {
  const CaregiverVerificationAction._({
    required this.type,
    this.otpCode,
  });

  const CaregiverVerificationAction.verify(String otpCode)
      : this._(type: CaregiverVerificationActionType.verify, otpCode: otpCode);

  const CaregiverVerificationAction.reject()
      : this._(type: CaregiverVerificationActionType.reject);

  final CaregiverVerificationActionType type;
  final String? otpCode;
}

enum CaregiverVerificationActionType { verify, reject }
