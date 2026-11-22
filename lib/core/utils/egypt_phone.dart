/// Matches the backend's Egyptian phone normalization for auth identifiers.
/// Formatting variants must never create separate technical email accounts.
String normalizeEgyptPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0020')) digits = digits.substring(2);
  if (digits.startsWith('20')) return '+$digits';
  if (digits.startsWith('0')) return '+2$digits';
  if (digits.startsWith('1') && digits.length == 10) return '+20$digits';
  return '+$digits';
}

String phoneAuthIdentifier(String phone) {
  final digits = normalizeEgyptPhone(phone).replaceFirst('+', '');
  return 'phone_$digits@delwaqty.app';
}

bool isEgyptMobilePhone(String raw) =>
    RegExp(r'^\+201[0-9]{9}$').hasMatch(normalizeEgyptPhone(raw));
