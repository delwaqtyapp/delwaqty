import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/regions/domain/entities/region.dart';
import 'package:delwaqty/features/regions/domain/entities/spatial_resolution.dart';
import 'package:delwaqty/features/regions/domain/services/region_resolver.dart';

void main() {
  final now = DateTime(2026, 8, 15);

  Region governorate({
    required String id,
    required String code,
    required String nameAr,
    required String nameEn,
    List<String> aliases = const [],
  }) {
    return Region(
      id: id,
      code: code,
      type: RegionType.governorate,
      nameAr: nameAr,
      nameEn: nameEn,
      metadata: aliases.isEmpty ? null : {'aliases': aliases},
      createdAt: now,
    );
  }

  final cairo = governorate(
    id: 'r-cairo',
    code: 'EG-C',
    nameAr: 'القاهرة',
    nameEn: 'Cairo',
    aliases: const ['Al Qahirah', 'El Qahira'],
  );
  final giza = governorate(
    id: 'r-giza',
    code: 'EG-GZ',
    nameAr: 'الجيزة',
    nameEn: 'Giza',
    aliases: const ['Al Jizah', 'El Giza'],
  );
  final suez = governorate(
    id: 'r-suez',
    code: 'EG-SUZ',
    nameAr: 'السويس',
    nameEn: 'Suez',
    aliases: const ['As Suways'],
  );
  final alexandria = governorate(
    id: 'r-alx',
    code: 'EG-ALX',
    nameAr: 'الإسكندرية',
    nameEn: 'Alexandria',
    aliases: const ['Al Iskandariyah'],
  );

  final governorates = [cairo, giza, suez, alexandria];

  group('RegionResolver.normalize', () {
    test('normalizes Arabic hamza variants', () {
      expect(RegionResolver.normalize('الإسكندرية'), 'الاسكندريه');
      expect(RegionResolver.normalize('الأسكندرية'), 'الاسكندريه');
      expect(RegionResolver.normalize('سيناء'), 'سينا');
    });

    test('strips Arabic diacritics and tatweel', () {
      expect(RegionResolver.normalize('القَاهرة'), 'القاهره');
      expect(RegionResolver.normalize('القاهرةـ'), 'القاهره');
    });

    test('normalizes teh marbuta and alef maqsura', () {
      expect(RegionResolver.normalize('محافظة'), 'محافظه');
      expect(RegionResolver.normalize('المنيا'), 'المنيا');
      expect(RegionResolver.normalize('شمال سيناء'), 'شمال سينا');
    });

    test('lowercases and trims English', () {
      expect(RegionResolver.normalize('  Cairo  '), 'cairo');
      expect(RegionResolver.normalize('CAIRO'), 'cairo');
    });

    test('tokenize strips governorate stop words', () {
      expect(RegionResolver.tokenize('محافظة القاهرة'), ['القاهره']);
      expect(
        RegionResolver.tokenize('Cairo Governorate, Egypt'),
        ['cairo', 'egypt'],
      );
    });
  });

  group('RegionResolver.resolveGovernorateId', () {
    test('matches Arabic name', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['القاهرة'],
        ),
        'r-cairo',
      );
    });

    test('matches Arabic name with governorate prefix', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['محافظة القاهرة، مصر'],
        ),
        'r-cairo',
      );
    });

    test('matches Arabic diacritized name', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['محافظة القَاهرة'],
        ),
        'r-cairo',
      );
    });

    test('matches English name', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['Cairo, Egypt'],
        ),
        'r-cairo',
      );
    });

    test('matches English name with governorate suffix', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['Cairo Governorate'],
        ),
        'r-cairo',
      );
    });

    test('matches aliases', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['Al Qahirah'],
        ),
        'r-cairo',
      );
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['As Suways'],
        ),
        'r-suez',
      );
    });

    test('resolves a full composed geocode address', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const [
            'Zafarana offices، مركز السويس - قرية الزعفرانة، محافظة السويس، مصر',
          ],
        ),
        'r-suez',
      );
    });

    test('matches any of multiple candidate strings', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['Some street', 'Giza'],
        ),
        'r-giza',
      );
    });

    test('returns null on no match', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['Mumbai, India'],
        ),
        isNull,
      );
    });

    test('returns null on ambiguous (two governorates in one string)', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['Cairo, Giza'],
        ),
        isNull,
      );
    });

    test('returns null on empty candidates', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const [],
        ),
        isNull,
      );
    });

    test('returns null on empty governorate list', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: const [],
          candidateStrings: const ['Cairo'],
        ),
        isNull,
      );
    });

    test('returns null on blank candidates', () {
      expect(
        RegionResolver.resolveGovernorateId(
          governorates: governorates,
          candidateStrings: const ['   '],
        ),
        isNull,
      );
    });
  });

  group('RegionResolver.resolveRegionId (new levels)', () {
    Region markaz({
      required String id,
      required String nameAr,
      required String nameEn,
      List<String> aliases = const [],
    }) {
      return Region(
        id: id,
        code: 'EG-ADM2-$id',
        parentRegionId: 'r-giza',
        type: RegionType.markaz,
        nameAr: nameAr,
        nameEn: nameEn,
        metadata: aliases.isEmpty ? null : {'aliases': aliases},
        createdAt: now,
      );
    }

    final markazes = [
      markaz(id: 'r-giza-markaz', nameAr: 'مركز الجيزة', nameEn: 'Giza'),
      markaz(
        id: 'r-imbaba',
        nameAr: 'إمبابة',
        nameEn: 'Imbaba',
        aliases: const ['Imbabah', 'Embaba'],
      ),
      markaz(id: 'r-ayyats', nameAr: 'العياط', nameEn: 'Ayyat'),
    ];

    test('matches an Arabic markaz name within the parent scope', () {
      expect(
        RegionResolver.resolveRegionId(
          candidates: markazes,
          candidateStrings: const ['مركز إمبابة'],
        ),
        'r-imbaba',
      );
    });

    test('matches an English markaz name', () {
      expect(
        RegionResolver.resolveRegionId(
          candidates: markazes,
          candidateStrings: const ['Ayyat'],
        ),
        'r-ayyats',
      );
    });

    test('matches a markaz alias', () {
      expect(
        RegionResolver.resolveRegionId(
          candidates: markazes,
          candidateStrings: const ['Embaba'],
        ),
        'r-imbaba',
      );
    });

    test('resolves within scope even when the name is also a parent-level name', () {
      expect(
        RegionResolver.resolveRegionId(
          candidates: markazes,
          candidateStrings: const ['Giza'],
        ),
        'r-giza-markaz',
      );
    });

    test('does not resolve a name absent from the scoped candidates', () {
      expect(
        RegionResolver.resolveRegionId(
          candidates: markazes,
          candidateStrings: const ['مركز الفيوم'],
        ),
        isNull,
      );
    });

    test('returns null on ambiguity inside the scope', () {
      final dupes = [
        markaz(id: 'r-imbaba', nameAr: 'إمبابة', nameEn: 'Imbaba'),
        markaz(id: 'r-imbaba2', nameAr: 'إمبابة الشرقية', nameEn: 'Imbaba'),
      ];
      expect(
        RegionResolver.resolveRegionId(
          candidates: dupes,
          candidateStrings: const ['Imbaba'],
        ),
        isNull,
      );
    });

    test('resolves villages scoped to their markaz', () {
      final village = Region(
        id: 'v-dikirnis',
        code: 'EG-ADM3-120901',
        parentRegionId: 'm-dikirnis',
        type: RegionType.village,
        nameAr: 'دكرنس',
        createdAt: now,
      );
      final villages = [
        village,
        Region(
          id: 'v-other',
          code: 'EG-ADM3-120902',
          parentRegionId: 'm-dikirnis',
          type: RegionType.village,
          nameAr: 'بلقاس',
          createdAt: now,
        ),
      ];
      expect(
        RegionResolver.resolveRegionId(
          candidates: villages,
          candidateStrings: const ['قرية دكرنس'],
        ),
        'v-dikirnis',
      );
    });
  });

  group('RegionPreferencePolicy.shouldUpdate', () {
    UserRegionPreference existing(RegionPreferenceSource source) {
      return UserRegionPreference(
        userId: 'u1',
        regionId: 'r-suez',
        source: source,
        updatedAt: now,
      );
    }

    test('saves when there is no existing preference', () {
      expect(
        RegionPreferencePolicy.shouldUpdate(
          existing: null,
          incoming: RegionPreferenceSource.detected,
        ),
        isTrue,
      );
    });

    test('detected refines an existing detected region', () {
      expect(
        RegionPreferencePolicy.shouldUpdate(
          existing: existing(RegionPreferenceSource.detected),
          incoming: RegionPreferenceSource.detected,
        ),
        isTrue,
      );
    });

    test('detected never overwrites manual', () {
      expect(
        RegionPreferencePolicy.shouldUpdate(
          existing: existing(RegionPreferenceSource.manual),
          incoming: RegionPreferenceSource.detected,
        ),
        isFalse,
      );
    });

    test('detected never overwrites verified', () {
      expect(
        RegionPreferencePolicy.shouldUpdate(
          existing: existing(RegionPreferenceSource.verified),
          incoming: RegionPreferenceSource.detected,
        ),
        isFalse,
      );
    });

    test('explicit manual always updates', () {
      expect(
        RegionPreferencePolicy.shouldUpdate(
          existing: existing(RegionPreferenceSource.manual),
          incoming: RegionPreferenceSource.manual,
        ),
        isTrue,
      );
      expect(
        RegionPreferencePolicy.shouldUpdate(
          existing: existing(RegionPreferenceSource.verified),
          incoming: RegionPreferenceSource.manual,
        ),
        isTrue,
      );
    });

    test('explicit verified always updates', () {
      expect(
        RegionPreferencePolicy.shouldUpdate(
          existing: existing(RegionPreferenceSource.detected),
          incoming: RegionPreferenceSource.verified,
        ),
        isTrue,
      );
      expect(
        RegionPreferencePolicy.shouldUpdate(
          existing: existing(RegionPreferenceSource.verified),
          incoming: RegionPreferenceSource.verified,
        ),
        isTrue,
      );
    });
  });

  group('RegionPreferencePolicy.shouldPersistDetected (confidence gate)', () {
    UserRegionPreference existing(RegionPreferenceSource source) {
      return UserRegionPreference(
        userId: 'u1',
        regionId: 'r-suez',
        source: source,
        updatedAt: now,
      );
    }

    test('LOW / UNVERIFIED / INVALID never auto-persist', () {
      for (final confidence in [
        GeoConfidence.low,
        GeoConfidence.unverified,
        GeoConfidence.invalid,
      ]) {
        expect(
          RegionPreferencePolicy.shouldPersistDetected(
            confidence: confidence,
            existing: null,
          ),
          isFalse,
          reason: '$confidence should not persist even with no preference',
        );
        expect(
          RegionPreferencePolicy.shouldPersistDetected(
            confidence: confidence,
            existing: existing(RegionPreferenceSource.detected),
          ),
          isFalse,
          reason: '$confidence should never overwrite a detected region',
        );
      }
    });

    test('MEDIUM (snapped) persists only when no preference exists', () {
      expect(
        RegionPreferencePolicy.shouldPersistDetected(
          confidence: GeoConfidence.medium,
          existing: null,
        ),
        isTrue,
      );
      for (final source in RegionPreferenceSource.values) {
        expect(
          RegionPreferencePolicy.shouldPersistDetected(
            confidence: GeoConfidence.medium,
            existing: existing(source),
          ),
          isFalse,
          reason: 'MEDIUM must not overwrite $source',
        );
      }
    });

    test('HIGH may persist but never overwrites manual/verified', () {
      expect(
        RegionPreferencePolicy.shouldPersistDetected(
          confidence: GeoConfidence.high,
          existing: null,
        ),
        isTrue,
      );
      expect(
        RegionPreferencePolicy.shouldPersistDetected(
          confidence: GeoConfidence.high,
          existing: existing(RegionPreferenceSource.detected),
        ),
        isTrue,
      );
      expect(
        RegionPreferencePolicy.shouldPersistDetected(
          confidence: GeoConfidence.high,
          existing: existing(RegionPreferenceSource.manual),
        ),
        isFalse,
      );
      expect(
        RegionPreferencePolicy.shouldPersistDetected(
          confidence: GeoConfidence.high,
          existing: existing(RegionPreferenceSource.verified),
        ),
        isFalse,
      );
    });

    test('mayAutoPersist flag reflects the gate', () {
      expect(GeoConfidence.high.mayAutoPersist, isTrue);
      expect(GeoConfidence.medium.mayAutoPersist, isTrue);
      expect(GeoConfidence.low.mayAutoPersist, isFalse);
      expect(GeoConfidence.unverified.mayAutoPersist, isFalse);
      expect(GeoConfidence.invalid.mayAutoPersist, isFalse);
    });
  });
}
