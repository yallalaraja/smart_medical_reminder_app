import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/caregiver.dart';
import '../services/caregiver_api_service.dart';
import '../services/reminder_api_service.dart';
import 'add_caregiver_screen.dart';
import 'verify_caregiver_screen.dart';

class CaregiversScreen extends StatefulWidget {
  const CaregiversScreen({super.key});

  @override
  State<CaregiversScreen> createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends State<CaregiversScreen> {
  final CaregiverApiService _apiService = CaregiverApiService();
  final List<Caregiver> _caregivers = <Caregiver>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCaregivers();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _loadCaregivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final caregivers = await _apiService.fetchCaregivers(
        userId: AppConfig.defaultUserId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _caregivers
          ..clear()
          ..addAll(caregivers);
        _isLoading = false;
      });
    } on ReminderApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load caregivers right now.';
      });
    }
  }

  Future<void> _openAddCaregiver() async {
    final caregiver = await Navigator.of(context).push<Caregiver>(
      MaterialPageRoute(builder: (_) => const AddCaregiverScreen()),
    );

    if (caregiver == null) {
      return;
    }

    try {
      final saved = await _apiService.createCaregiver(
        userId: AppConfig.defaultUserId,
        caregiver: caregiver,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _caregivers.add(saved);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${saved.fullName} invited. Enter the OTP from their SMS to verify.',
          ),
        ),
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
        const SnackBar(content: Text('Could not save caregiver')),
      );
    }
  }

  Future<void> _verifyCaregiver(Caregiver caregiver) async {
    final action = await Navigator.of(context).push<CaregiverVerificationAction>(
      MaterialPageRoute(
        builder: (_) => VerifyCaregiverScreen(caregiver: caregiver),
      ),
    );

    if (action == null) {
      return;
    }

    try {
      late final Caregiver updatedCaregiver;
      late final String message;

      if (action.type == CaregiverVerificationActionType.verify) {
        updatedCaregiver = await _apiService.verifyOtp(
          caregiverId: caregiver.id,
          otpCode: action.otpCode!,
        );
        message = '${updatedCaregiver.fullName} verified successfully';
      } else {
        updatedCaregiver = await _apiService.rejectInvitation(
          caregiverId: caregiver.id,
        );
        message = '${updatedCaregiver.fullName} invitation rejected';
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _replaceCaregiver(updatedCaregiver);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
        const SnackBar(content: Text('Could not complete caregiver verification')),
      );
    }
  }

  Future<void> _resendInvitation(Caregiver caregiver) async {
    try {
      final updatedCaregiver = await _apiService.resendInvitation(
        caregiverId: caregiver.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _replaceCaregiver(updatedCaregiver);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP resent to ${updatedCaregiver.phoneNumber}')),
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
        const SnackBar(content: Text('Could not resend invitation')),
      );
    }
  }

  void _replaceCaregiver(Caregiver caregiver) {
    final index = _caregivers.indexWhere((item) => item.id == caregiver.id);
    if (index == -1) {
      _caregivers.add(caregiver);
      return;
    }
    _caregivers[index] = caregiver;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregivers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCaregiver,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Caregiver'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : _caregivers.isEmpty
                      ? const Center(
                          child: Text(
                            'No caregivers added yet.\nAdd one so missed reminders can send alerts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pending caregivers must verify their OTP before they start receiving missed reminder alerts.',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.separated(
                          itemCount: _caregivers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final caregiver = _caregivers[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            caregiver.fullName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                        ),
                                        _StatusChip(status: caregiver.status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(caregiver.phoneNumber),
                                    if (caregiver.relationship.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Relationship: ${caregiver.relationship}'),
                                    ],
                                    const SizedBox(height: 4),
                                    Text('Alerts via: ${caregiver.channelLabel()}'),
                                    if (caregiver.invitedAt != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Invited: ${_formatDateTimeIst(caregiver.invitedAt!)} IST',
                                      ),
                                    ],
                                    if (caregiver.otpExpiresAt != null &&
                                        caregiver.isPending) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'OTP expires: ${_formatDateTimeIst(caregiver.otpExpiresAt!)} IST',
                                        style: const TextStyle(
                                          color: Color(0xFF7C5E10),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (caregiver.isPending)
                                          FilledButton(
                                            onPressed: () => _verifyCaregiver(caregiver),
                                            child: const Text('Enter OTP'),
                                          ),
                                        if (caregiver.isPending)
                                          OutlinedButton(
                                            onPressed: () => _resendInvitation(caregiver),
                                            child: const Text('Resend OTP'),
                                          ),
                                        if (caregiver.isAccepted)
                                          const Text(
                                            'This caregiver is verified and will receive alerts.',
                                            style: TextStyle(
                                              color: Color(0xFF2F855A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        if (caregiver.isRejected)
                                          const Text(
                                            'This caregiver rejected the invitation and will not receive alerts.',
                                            style: TextStyle(
                                              color: Color(0xFFC2410C),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'accepted' => ('Accepted', const Color(0xFF2F855A)),
      'rejected' => ('Rejected', const Color(0xFFC2410C)),
      _ => ('Pending', const Color(0xFFB7791F)),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(24),
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
