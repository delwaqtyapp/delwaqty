import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates the Phase 2.1B geographic dataset embedded in the migration seed.
/// The migration is the source of truth, so the test parses the SQL seed
/// (and the canonical 030 seed) rather than duplicating the data in Dart.
void main() {
  final seedFile = File('supabase/migrations/032_egypt_geographic_seed.sql');
  final schemaFile = File('supabase/migrations/032_egypt_geographic_schema.sql');
  final canonicalFile = File('supabase/migrations/030_regional_system.sql');

  final lines = seedFile.readAsLinesSync();
  final schema = schemaFile.readAsStringSync();
  final regionRows = _rowsFor(lines, 'regions');
  final placeRows = _rowsFor(lines, 'geo_places');
  final aliasRows = _rowsFor(lines, 'geo_aliases');
  final boundaryRows = _rowsFor(lines, 'geo_admin_boundaries');

  final canonicalIds = _canonicalIds(canonicalFile.readAsLinesSync());

  final newRegionIds = regionRows.map((r) => r[0]).toSet();
  final allRegionIds = newRegionIds.union(canonicalIds);
  final placeIds = placeRows.map((p) => p[0]).toSet();

  group('032 seed — regions (Phase 2.1B hierarchy)', () {
    test('adds exactly 6,129 regions; total 6,157 with canonical 28', () {
      expect(regionRows.length, 6129);
      expect(newRegionIds.length, 6129, reason: 'duplicate region ids');
      expect(allRegionIds.length, 6129 + 28);
    });

    test('counts by type match the approved taxonomy', () {
      int count(String type) =>
          regionRows.where((r) => r[4] == type).length;
      expect(count('markaz'), 165);
      expect(count('district'), 173);
      expect(count('city'), 27);
      expect(count('village'), 4580);
      expect(count('new_city'), 52);
      expect(count('area'), 1132);
    });

    test('does not re-insert or mutate the 28 canonical regions', () {
      for (final id in canonicalIds) {
        expect(newRegionIds, isNot(contains(id)), reason: 'canonical $id');
      }
    });

    test('every region carries deterministic unique codes', () {
      final codes = regionRows.map((r) => r[1]).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate codes');
      for (final code in codes) {
        expect(
          code,
          anyOf(
            startsWith('EG-ADM2-'),
            startsWith('EG-ADM3-'),
            startsWith('EG-NC-'),
            startsWith('EG-CITY-'),
          ),
          reason: 'unexpected code $code',
        );
      }
    });

    test('every parent_region_id resolves (no orphans)', () {
      for (final r in regionRows) {
        final parent = r[2];
        expect(
          allRegionIds,
          contains(parent),
          reason: 'orphan parent $parent of ${r[1]}',
        );
      }
    });

    test('parent-type matrix is exact', () {
      String parentType(String pid) {
        for (final r in regionRows) {
          if (r[0] == pid) return r[4];
        }
        return 'governorate';
      }

      for (final r in regionRows) {
        final type = r[4];
        final parent = parentType(r[2]);
        final bool ok;
        switch (type) {
          case 'village':
            ok = parent == 'markaz';
          case 'area':
            ok = parent == 'district' || parent == 'new_city';
          default:
            ok = parent == 'governorate';
        }
        expect(ok, isTrue, reason: '${r[1]} (${r[4]}) has parent $parent');
      }
    });

    test('every region carries provenance metadata', () {
      for (final r in regionRows) {
        final metadata = r[8];
        for (final key in ['source', 'source_date', 'source_type', 'confidence']) {
          expect(metadata, contains('"$key"'), reason: '${r[1]} missing $key');
        }
      }
    });
  });

  group('032 seed — geo_places', () {
    test('64 places with approved types only', () {
      expect(placeRows.length, 64);
      const allowed = {
        'hotel', 'resort', 'tourist_village', 'tourist_city', 'compound',
        'development', 'airport', 'port', 'university', 'hospital', 'station',
        'landmark', 'settlement', 'poi',
      };
      for (final p in placeRows) {
        expect(allowed, contains(p[1]), reason: 'type ${p[1]}');
      }
    });

    test('every place resolves to a canonical or new region (or null)', () {
      for (final p in placeRows) {
        final regionId = p[2];
        if (regionId == 'NULL') continue;
        expect(
          allRegionIds,
          contains(regionId),
          reason: 'place ${p[4]} orphan region',
        );
      }
    });

    test('every place has lat/lon and provenance fields', () {
      for (final p in placeRows) {
        expect(p[5], isNot('NULL'), reason: '${p[4]} missing lat');
        expect(p[6], isNot('NULL'), reason: '${p[4]} missing lon');
        expect(double.parse(p[5]), inInclusiveRange(-90, 90));
        expect(double.parse(p[6]), inInclusiveRange(-180, 180));
        expect(p[8], isNotEmpty, reason: '${p[4]} missing source');
        expect(p[9], isNotEmpty, reason: '${p[4]} missing source_ref');
        expect(p[11], isNotEmpty, reason: '${p[4]} missing source_type');
        expect(p[12], isNotEmpty, reason: '${p[4]} missing confidence');
      }
    });

    test('sources are unique per place', () {
      final refs = placeRows.map((p) => '${p[8]}:${p[9]}').toList();
      expect(refs.toSet().length, refs.length, reason: 'duplicate source_ref');
    });
  });

  group('032 seed — geo_aliases', () {
    test('6,885 inserts collapse to 6,879 unique tuples (idempotent)', () {
      expect(aliasRows.length, 6885);
      final unique = aliasRows
          .map((a) => '${a[0]}|${a[1]}|${a[2]}|${a[3]}')
          .toSet();
      expect(unique.length, 6879);
    });

    test('every alias entity_id resolves to a region or place', () {
      final regionAliases = aliasRows.where((a) => a[0] == 'region');
      final placeAliases = aliasRows.where((a) => a[0] == 'place');
      for (final a in regionAliases) {
        expect(newRegionIds, contains(a[1]), reason: 'unknown region ${a[1]}');
      }
      for (final a in placeAliases) {
        expect(placeIds, contains(a[1]), reason: 'unknown place ${a[1]}');
      }
    });

    test('alias source mix matches provenance contract', () {
      int bySource(String source) =>
          aliasRows.where((a) => a[5] == source).length;
      expect(bySource('cod-ab'), 6546);
      expect(bySource('geonames'), 333);
      expect(bySource('openstreetmap'), 4);
      expect(bySource('wikipedia'), 2);
    });
  });

  group('032 seed — geo_admin_boundaries', () {
    test('374 boundaries: 27 ADM1 + 347 ADM2', () {
      expect(boundaryRows.length, 374);
      expect(boundaryRows.where((b) => b[1] == '1').length, 27);
      expect(boundaryRows.where((b) => b[1] == '2').length, 347);
    });

    test('every boundary resolves to a region', () {
      for (final b in boundaryRows) {
        expect(
          allRegionIds,
          contains(b[0]),
          reason: 'boundary orphan region ${b[0]}',
        );
      }
    });

    test('every boundary has a source and source_ref', () {
      for (final b in boundaryRows) {
        expect(b[3], isNotEmpty, reason: 'missing source');
        expect(b[4], isNotEmpty, reason: 'missing source_ref');
      }
    });
  });

  group('032 schema — taxonomy, tables, RLS, RPC', () {
    test('regions.type CHECK extended additively to 8 types (D3)', () {
      expect(
        schema,
        contains("'country','governorate','markaz','district','city',"),
      );
      expect(schema, contains("'village','new_city','area')"));
      expect(
        schema,
        contains('regions_type_check'),
        reason: 'constraint must be present',
      );
    });

    test('geo tables + spatial RPC declared', () {
      for (final table in ['geo_places', 'geo_aliases', 'geo_admin_boundaries']) {
        expect(schema, contains('CREATE TABLE IF NOT EXISTS public.$table'));
        expect(schema, contains('ENABLE ROW LEVEL SECURITY'));
      }
      expect(schema, contains('geo_region_for_point'));
    });

    test('RLS: public SELECT + admin write, no anon writes', () {
      expect(
        schema.contains('"geo_places select public"') &&
            schema.contains('"geo_places admin write"'),
        isTrue,
      );
      expect(
        schema.contains('"geo_aliases select public"') &&
            schema.contains('"geo_aliases admin write"'),
        isTrue,
      );
      expect(
        schema.contains('"geo_admin_boundaries select public"') &&
            schema.contains('"geo_admin_boundaries admin write"'),
        isTrue,
      );
      expect(
        schema,
        contains('REVOKE ALL ON public.geo_places FROM anon, authenticated'),
      );
      expect(
        schema.contains('GRANT SELECT ON public.geo_places, public.geo_aliases,') &&
            schema.contains('TO anon, authenticated'),
        isTrue,
      );
    });

    test('RPC is SECURITY DEFINER with search_path + authenticated EXECUTE', () {
      expect(schema, contains('SECURITY DEFINER'));
      expect(schema, contains('SET search_path = public, pg_temp'));
      expect(
        schema.contains('GRANT EXECUTE ON FUNCTION public.geo_region_for_point(') &&
            schema.contains('TO authenticated'),
        isTrue,
      );
    });
  });
}

/// Extracts the VALUES tuple of every `INSERT INTO public.<table>` row.
/// Handles SQL single-quote escaping (`''`) inside quoted literals.
List<List<String>> _rowsFor(List<String> lines, String table) {
  final rows = <List<String>>[];
  for (final line in lines) {
    if (!line.startsWith('INSERT INTO public.$table')) continue;
    final valuesStart = line.indexOf('VALUES (');
    final conflictEnd = line.lastIndexOf(') ON CONFLICT');
    final body = line.substring(valuesStart + 8, conflictEnd);
    rows.add(_splitValues(body));
  }
  return rows;
}

List<String> _splitValues(String body) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuote = false;
  var parenDepth = 0;
  var i = 0;
  while (i < body.length) {
    final c = body[i];
    if (inQuote) {
      if (c == "'") {
        if (i + 1 < body.length && body[i + 1] == "'") {
          buffer.write("'");
          i++;
        } else {
          inQuote = false;
        }
      } else {
        buffer.write(c);
      }
    } else if (c == "'") {
      inQuote = true;
    } else if (c == '(' || c == '[') {
      parenDepth++;
      buffer.write(c);
    } else if (c == ')' || c == ']') {
      parenDepth--;
      buffer.write(c);
    } else if (c == ',' && parenDepth == 0) {
      fields.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(c);
    }
    i++;
  }
  fields.add(buffer.toString().trim());
  return fields;
}

/// Parses the canonical region ids from the 030 seed (single-line tuples
/// ending with `::jsonb)`).
Set<String> _canonicalIds(List<String> lines) {
  final ids = <String>{};
  final regex = RegExp(r"^\s*\('([^']+)',\s*'");
  for (final line in lines) {
    final match = regex.firstMatch(line);
    if (match != null) ids.add(match.group(1)!);
  }
  return ids;
}
