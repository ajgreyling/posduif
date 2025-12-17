class EnrollmentResponse {
  final String token;
  final Map<String, dynamic> qrCodeData;
  final DateTime expiresAt;

  EnrollmentResponse({
    required this.token,
    required this.qrCodeData,
    required this.expiresAt,
  });

  factory EnrollmentResponse.fromJson(Map<String, dynamic> json) {
    return EnrollmentResponse(
      token: json['token'],
      qrCodeData: json['qr_code_data'] as Map<String, dynamic>,
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }
}

class EnrollmentDetails {
  final String token;
  final String tenantId;
  final String createdBy;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final bool valid;

  EnrollmentDetails({
    required this.token,
    required this.tenantId,
    required this.createdBy,
    required this.expiresAt,
    this.usedAt,
    required this.valid,
  });

  factory EnrollmentDetails.fromJson(Map<String, dynamic> json) {
    return EnrollmentDetails(
      token: json['token'],
      tenantId: json['tenant_id'],
      createdBy: json['created_by'],
      expiresAt: DateTime.parse(json['expires_at']),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at']) : null,
      valid: json['valid'] ?? false,
    );
  }
}

