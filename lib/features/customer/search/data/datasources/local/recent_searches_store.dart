import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/features/customer/search/domain/entities/recent_search.dart';

final recentSearchesStoreProvider = Provider<RecentSearchesStore>((ref) {
  return RecentSearchesStore(ref.watch(sharedPreferencesProvider));
});

class RecentSearchesStore {
  RecentSearchesStore(this._prefs, {this.maxEntries = 8});

  final SharedPreferencesService _prefs;
  final int maxEntries;

  static const _key = 'ride_recent_searches';

  List<RecentSearch> getAll() {
    final raw = _prefs.getString(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List;
      return list
          .map((e) => RecentSearch.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(RecentSearch search) async {
    final current = getAll()
        .where((e) => e.placeId != search.placeId)
        .toList()
      ..insert(0, search);
    final trimmed = current.take(maxEntries).toList();
    await _prefs.saveString(
      key: _key,
      value: json.encode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() => _prefs.remove(key: _key);
}
