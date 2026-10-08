/// Safe avatar-initial extraction.
///
/// `(name ?? email ?? username)?.substring(0, 1)` throws a RangeError as
/// soon as the value is an EMPTY STRING, because `??` only guards null.
/// That crashed the members list, the member drawer, the member detail
/// header, the support-chat picker and the web verifications page on the
/// very first row produced by a seeded or legacy account.
String safeInitial(String? value, {String fallback = '?'}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  return trimmed.substring(0, 1).toUpperCase();
}

/// Convenience overload for the common "pick the first non-empty field"
/// pattern used by the admin member surfaces.
String safeInitialFrom(Iterable<String?> values, {String fallback = '?'}) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed.substring(0, 1).toUpperCase();
  }
  return fallback;
}