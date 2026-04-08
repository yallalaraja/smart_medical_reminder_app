class Caregiver {
  Caregiver({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phoneNumber,
    required this.relationship,
    required this.notificationChannel,
    this.status = 'pending',
    this.invitedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.otpExpiresAt,
  });

  final String id;
  final String userId;
  final String fullName;
  final String phoneNumber;
  final String relationship;
  final String notificationChannel;
  final String status;
  final DateTime? invitedAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? otpExpiresAt;

  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      id: json['id'].toString(),
      userId: (json['user_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      relationship: (json['relationship'] ?? '').toString(),
      notificationChannel: (json['notification_channel'] ?? 'sms').toString(),
      status: (json['status'] ?? 'pending').toString(),
      invitedAt: json['invited_at'] != null
          ? DateTime.tryParse(json['invited_at'].toString())
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'].toString())
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.tryParse(json['rejected_at'].toString())
          : null,
      otpExpiresAt: json['otp_expires_at'] != null
          ? DateTime.tryParse(json['otp_expires_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toCreateJson({required String userId}) {
    return {
      'user_id': userId,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'relationship': relationship,
      'notification_channel': notificationChannel,
    };
  }

  String channelLabel() {
    switch (notificationChannel) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'both':
        return 'SMS + WhatsApp';
      default:
        return 'SMS';
    }
  }

  String statusLabel() {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}
