import 'package:delwaqty/core/utils/egypt_phone.dart';

enum DirectDeliveryError { noDropoff, noPhone, badPhone, nothingToDeliver }

/// Validates the direct-delivery form. Returns the first problem, or null.
///
/// The drop-off must be a text or a pin, the phone must be an Egyptian mobile
/// (01 + 9 digits), and the request needs at least one shopping item or a
/// written description.
DirectDeliveryError? validateDirectDelivery({
  required String dropoffText,
  required String phone,
  required int itemCount,
  required String description,
}) {
  if (dropoffText.trim().isEmpty) return DirectDeliveryError.noDropoff;
  final p = phone.trim();
  if (p.isEmpty) return DirectDeliveryError.noPhone;
  if (!isEgyptMobilePhone(p)) return DirectDeliveryError.badPhone;
  if (itemCount < 1 && description.trim().isEmpty) {
    return DirectDeliveryError.nothingToDeliver;
  }
  return null;
}

/// Parses the quantity field: a whole number of at least 1, else null.
int? parseItemQuantity(String raw) {
  final q = int.tryParse(raw.trim());
  if (q == null || q < 1) return null;
  return q;
}
