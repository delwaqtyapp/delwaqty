import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/features/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/search/domain/entities/recent_search.dart';
import 'package:delwaqty/features/search/domain/entities/saved_place.dart';
import 'package:delwaqty/features/search/domain/entities/search_session.dart';

void main() {
  group('SearchSession', () {
    test('generates unique tokens', () {
      final a = SearchSession.generate();
      final b = SearchSession.generate();
      expect(a.token, isNotEmpty);
      expect(a, isNot(equals(b)));
    });
  });

  group('SavedPlaceType wire mapping', () {
    test('round-trips known types', () {
      expect(SavedPlaceTypeX.fromWire('home'), SavedPlaceType.home);
      expect(SavedPlaceTypeX.fromWire('work'), SavedPlaceType.work);
      expect(SavedPlaceTypeX.fromWire('favorite'), SavedPlaceType.favorite);
      expect(SavedPlaceType.home.wire, 'home');
    });

    test('unknown wire falls back to favorite', () {
      expect(SavedPlaceTypeX.fromWire('anything'), SavedPlaceType.favorite);
    });
  });

  group('PlaceSuggestion', () {
    test('fullText joins primary and secondary', () {
      const s = PlaceSuggestion(
          placeId: 'p', primaryText: 'Cafe', secondaryText: 'Cairo');
      expect(s.fullText, 'Cafe, Cairo');
    });

    test('fullText uses primary when secondary empty', () {
      const s =
          PlaceSuggestion(placeId: 'p', primaryText: 'Cafe', secondaryText: '');
      expect(s.fullText, 'Cafe');
    });

    test('equality by placeId', () {
      const a = PlaceSuggestion(placeId: 'x', primaryText: 'A', secondaryText: '');
      const b = PlaceSuggestion(placeId: 'x', primaryText: 'B', secondaryText: 'C');
      expect(a, equals(b));
    });
  });

  group('RecentSearch json', () {
    test('serializes and deserializes', () {
      final r = RecentSearch(
        placeId: 'pid',
        primaryText: 'Home',
        secondaryText: 'Nasr City',
        location: const GeoPoint(30.05, 31.34),
        searchedAt: DateTime.parse('2026-01-01T10:00:00.000Z'),
      );
      final back = RecentSearch.fromJson(r.toJson());
      expect(back.placeId, 'pid');
      expect(back.primaryText, 'Home');
      expect(back.location, const GeoPoint(30.05, 31.34));
      expect(back.searchedAt, r.searchedAt);
    });
  });
}
