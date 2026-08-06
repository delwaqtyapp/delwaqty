enum UserType {
  customer('customer'),
  provider('provider'),
  delivery('delivery');

  const UserType(this.code);

  final String code;

  bool get requiresVerification => this != UserType.customer;

  static UserType fromCode(String? code) => UserType.values.firstWhere(
    (type) => type.code == code,
    orElse: () => UserType.customer,
  );
}
