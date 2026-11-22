/// Direction helpers for mixed Arabic/Latin UI text.

/// Wraps text that starts with an LTR character (Latin names, digits) in
/// Unicode directional isolates (LRI/PDI). In an RTL paragraph a bare Latin
/// name makes the truncation ellipsis land on the wrong visual side; the
/// isolate gives the run its own direction so the ellipsis follows the text.
String isolateLtr(String text) {
  if (text.isEmpty) return text;
  final first = text.runes.first;
  final startsLtr =
      (first >= 0x30 && first <= 0x39) || // 0-9
      (first >= 0x41 && first <= 0x5A) || // A-Z
      (first >= 0x61 && first <= 0x7A); // a-z
  return startsLtr ? '⁦$text⁩' : text;
}
