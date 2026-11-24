/// One structured item of an ask-anything (436) request: the customer
/// picks a unit (kilo / half / quarter) or an EGP amount and writes the
/// product name.
class CourierShoppingItem {
  const CourierShoppingItem({
    required this.productName,
    required this.unit,
    this.amountEgp,
  });

  final String productName;

  /// kilo | half | quarter | amount
  final String unit;

  /// Required when [unit] is 'amount', null otherwise.
  final double? amountEgp;

  Map<String, dynamic> toJson() => {
    'product_name': productName,
    'unit': unit,
    if (amountEgp != null) 'amount_egp': amountEgp,
  };
}
