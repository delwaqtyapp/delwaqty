import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/regions/domain/entities/region.dart';
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
}
