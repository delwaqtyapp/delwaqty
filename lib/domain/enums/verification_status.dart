enum VerificationStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const VerificationStatus(this.code);

  final String code;

  bool get isApproved => this == VerificationStatus.approved;

  bool get isRejected => this == VerificationStatus.rejected;

  static VerificationStatus fromCode(String? code) => VerificationStatus.values
      .firstWhere(
        (status) => status.code == code,
        orElse: () => VerificationStatus.pending,
      );
}
