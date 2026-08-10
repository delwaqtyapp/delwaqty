enum UserType {
  customer('customer'),
  merchant('merchant'),
  driver('driver'),
  provider('provider'),
  delivery('delivery');

  const UserType(this.code);

  final String code;

  bool get requiresVerification => this != UserType.customer;

  bool get requiresTradeLicense => this == UserType.merchant;

  bool get requiresDrivingLicense => this == UserType.driver || this == UserType.delivery;

  bool get requiresIdCard => this != UserType.customer;

  bool get requiresProfilePhoto => this != UserType.customer;

  static UserType fromCode(String? code) => UserType.values.firstWhere(
    (type) => type.code == code,
    orElse: () => UserType.customer,
  );
}
