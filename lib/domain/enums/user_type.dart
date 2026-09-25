enum UserType {
  admin('admin'),
  owner('owner'),
  merchant('merchant'),
  provider('provider'),
  driver('driver'),
  delivery('delivery'),
  customer('customer');

  const UserType(this.code);

  final String code;

  bool get requiresVerification =>
      this != UserType.customer && this != UserType.admin && this != UserType.owner;

  bool get requiresTradeLicense =>
      this == UserType.merchant || this == UserType.admin;

  bool get requiresDrivingLicense =>
      this == UserType.driver || this == UserType.delivery;

  bool get requiresIdCard => this != UserType.customer && this != UserType.admin;

  bool get requiresProfilePhoto =>
      this != UserType.customer && this != UserType.admin;

  bool get isAdmin => this == UserType.admin;

  bool get isOwner => this == UserType.owner || this == UserType.admin;

  bool get isProvider => this == UserType.provider;

  bool get isDriver => this == UserType.driver || this == UserType.delivery;

  bool get isCustomer => this == UserType.customer;

  static UserType fromCode(String? code) => UserType.values.firstWhere(
    (type) => type.code == code,
    orElse: () => UserType.customer,
  );
}