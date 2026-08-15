import 'package:delwaqty/features/regions/domain/entities/region.dart';
import 'package:delwaqty/features/regions/domain/entities/spatial_resolution.dart';

/// Pure Dart detection mapping: resolves canonical governorate ids from
/// geocoded address strings. Deterministic and unit-testable.
///
/// Never creates region records — it only ever returns ids that already exist
/// in the canonical [Region] dataset loaded from Supabase.
class RegionResolver {
  static const Set<String> _stopTokens = {
    'محافظه',
    'governorate',
    'province',
    'muhafazah',
    'muhafaza',
    'mohafazah',
  };

  /// Normalizes a single text value (Arabic + English) for matching.
  static String normalize(String value) {
    var v = value.trim().toLowerCase();
    v = v.replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '');
    v = v.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    v = v.replaceAll('ء', '');
    v = v.replaceAll('ى', 'ي');
    v = v.replaceAll('ة', 'ه');
    v = v.replaceAll('ـ', '');
    v = v.replaceAll('’', "'");
    v = v.replaceAll(RegExp(r'[^a-z0-9\u0621-\u064A\u0660-\u0669\u06F0-\u06F9]+'), ' ');
    v = v.trim().replaceAll(RegExp(r'\s+'), ' ');
    return v;
  }

  /// Tokenizes a normalized string into words, dropping stop tokens.
  static List<String> tokenize(String value) {
    return normalize(value)
        .split(' ')
        .where((w) => w.isNotEmpty && !_stopTokens.contains(w))
        .toList();
  }

  /// Returns the canonical region id when exactly one governorate matches the
  /// combined candidate strings; null when nothing or more than one matches.
  static String? resolveGovernorateId({
    required List<Region> governorates,
    required List<String> candidateStrings,
  }) {
    return resolveRegionId(
      candidates: governorates,
      candidateStrings: candidateStrings,
    );
  }

  /// Level-aware resolution: returns the canonical id of the single region in
  /// [candidates] matching the combined candidate strings (Arabic name,
  /// English name, or alias), scoped to the provided candidate set (typically
  /// the children of one parent, e.g. all markaz of a governorate).
  /// Null when nothing or more than one matches.
  static String? resolveRegionId({
    required List<Region> candidates,
    required List<String> candidateStrings,
  }) {
    if (candidates.isEmpty || candidateStrings.isEmpty) return null;

    final candidateWords = <String>[];
    for (final candidate in candidateStrings) {
      candidateWords.addAll(tokenize(candidate));
    }
    if (candidateWords.isEmpty) return null;

    final matches = candidates.where((c) => _matches(candidateWords, c)).toList();
    if (matches.length != 1) return null;
    return matches.single.id;
  }

  static bool _matches(List<String> candidateWords, Region region) {
    final needles = <List<String>>[
      tokenize(region.nameAr),
      if (region.nameEn != null && region.nameEn!.isNotEmpty)
        tokenize(region.nameEn!),
      for (final alias in region.aliases) tokenize(alias),
    ];
    return needles.any((needle) => _containsPhrase(candidateWords, needle));
  }

  static bool _containsPhrase(List<String> haystack, List<String> needle) {
    if (needle.isEmpty) return false;
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }
}

/// State-preservation policy (ADR-050 + ADR-057): never silently overwrite a
/// verified/manual region with uncertain detection; LOW-confidence spatial
/// resolution never auto-persists.
class RegionPreferencePolicy {
  /// Whether [incoming] should replace [existing].
  static bool shouldUpdate({
    required UserRegionPreference? existing,
    required RegionPreferenceSource incoming,
  }) {
    if (existing == null) return true;
    switch (incoming) {
      case RegionPreferenceSource.detected:
        return existing.source == RegionPreferenceSource.detected;
      case RegionPreferenceSource.manual:
      case RegionPreferenceSource.verified:
        return true;
    }
  }

  /// Spatial-confidence gate (ADR-057 §17) applied before persisting a
  /// GPS-derived detection as `detected`:
  ///   * LOW / UNVERIFIED / INVALID  -> never auto-persisted
  ///   * MEDIUM (snapped)            -> policy-gated: only when there is no
  ///                                    existing preference at all
  ///   * HIGH (point-in-polygon)     -> may persist, but still never
  ///                                    overwrites manual/verified
  static bool shouldPersistDetected({
    required GeoConfidence confidence,
    required UserRegionPreference? existing,
  }) {
    switch (confidence) {
      case GeoConfidence.low:
      case GeoConfidence.unverified:
      case GeoConfidence.invalid:
        return false;
      case GeoConfidence.medium:
        return existing == null;
      case GeoConfidence.high:
        return shouldUpdate(
          existing: existing,
          incoming: RegionPreferenceSource.detected,
        );
    }
  }
}
