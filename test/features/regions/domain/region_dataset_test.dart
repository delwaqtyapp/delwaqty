import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates the canonical region dataset embedded in the migration seed.
/// The migration is the source of truth, so the test parses the SQL seed
/// rather than duplicating the data in Dart.
void main() {
  final seedFile = File(
    'supabase/migrations/030_regional_system.sql',
  );
  final seedRows = _parseSeedRows(seedFile);

  const countryId = '00000000-0000-0000-0000-000000000001';

  group('regions dataset (migration 030)', () {
    test('seed contains Egypt country + all 27 governorates', () {
      expect(seedRows.length, 28, reason: '1 country + 27 governorates');
    });

    test('country row is Egypt with no parent', () {
      final country = seedRows.singleWhere((r) => r['type'] == 'country');
      expect(country['code'], 'EG');
      expect(country['name_ar'], 'مصر');
      expect(country['name_en'], 'Egypt');
      expect(country['parent'], isNull);
    });

    test('region ids are unique', () {
      final ids = seedRows.map((r) => r['id']!).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate region ids');
    });

    test('region codes are unique and stable ISO codes', () {
      final codes = seedRows.map((r) => r['code']!).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate codes');
    });

    test('all governorates exist (27 ISO 3166-2:EG codes)', () {
      final codes = seedRows
          .where((r) => r['type'] == 'governorate')
          .map((r) => r['code']!)
          .toSet();
      expect(
        codes,
        {
          'EG-ALX', 'EG-ASN', 'EG-AST', 'EG-BA', 'EG-BH', 'EG-BNS', 'EG-C',
          'EG-DK', 'EG-DT', 'EG-FYM', 'EG-GH', 'EG-GZ', 'EG-IS', 'EG-JS',
          'EG-KB', 'EG-KFS', 'EG-KN', 'EG-LX', 'EG-MN', 'EG-MNF', 'EG-MT',
          'EG-PTS', 'EG-SHG', 'EG-SHR', 'EG-SIN', 'EG-SUZ', 'EG-WAD',
        },
      );
    });

    test('all governorates have the official English names', () {
      final names = seedRows
          .where((r) => r['type'] == 'governorate')
          .map((r) => r['name_en']!)
          .toSet();
      expect(
        names,
        {
          'Alexandria', 'Aswan', 'Asyut', 'Red Sea', 'Beheira', 'Beni Suef',
          'Cairo', 'Dakahlia', 'Damietta', 'Faiyum', 'Gharbia', 'Giza',
          'Ismailia', 'South Sinai', 'Qalyubia', 'Kafr el Sheikh', 'Qena',
          'Luxor', 'Minya', 'Monufia', 'Matrouh', 'Port Said', 'Sohag',
          'Sharqia', 'North Sinai', 'Suez', 'New Valley',
        },
      );
    });

    test('every governorate has a non-empty Arabic name', () {
      for (final row in seedRows.where((r) => r['type'] == 'governorate')) {
        expect((row['name_ar']! as String).isNotEmpty, isTrue);
      }
    });

    test('all governorates attach to the Egypt country (no orphans)', () {
      final ids = seedRows.map((r) => r['id']!).toSet();
      for (final row in seedRows) {
        final parent = row['parent'];
        if (parent != null) {
          expect(ids, contains(parent), reason: 'orphan parent ${row['id']}');
        }
      }
      final governorates = seedRows.where((r) => r['type'] == 'governorate');
      for (final g in governorates) {
        expect(g['parent'], countryId, reason: '${g['code']} wrong parent');
      }
    });

    test('every governorate is active', () {
      for (final row in seedRows.where((r) => r['type'] == 'governorate')) {
        expect(row['is_active'], isTrue);
      }
    });

    test('region types are from the allowed set', () {
      const allowed = {'country', 'governorate', 'city', 'district', 'area'};
      for (final row in seedRows) {
        expect(allowed, contains(row['type']));
      }
    });

    test('country codes match the region type', () {
      for (final row in seedRows) {
        expect(row['country_code'], 'EG');
      }
    });
  });
}

List<Map<String, Object?>> _parseSeedRows(File file) {
  final lines = file.readAsLinesSync();
  final rows = <Map<String, Object?>>[];
  final regex = RegExp(
    r"""^\s*\('([^']+)', '([^']+)', (NULL|'([^']*)'), '([^']+)', '([^']+)', '([^']+)', '([^']+)', (TRUE|FALSE), '\{.*?\}'::jsonb\),?$""",
  );

  for (final line in lines) {
    final match = regex.firstMatch(line);
    if (match == null) continue;
    rows.add({
      'id': match.group(1),
      'code': match.group(2),
      'parent': match.group(3) == 'NULL' ? null : match.group(4),
      'country_code': match.group(5),
      'type': match.group(6),
      'name_ar': match.group(7),
      'name_en': match.group(8),
      'is_active': match.group(9) == 'TRUE',
    });
  }
  return rows;
}
