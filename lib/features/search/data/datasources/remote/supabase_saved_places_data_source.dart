import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delwaqty/features/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/search/domain/entities/saved_place.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final supabaseSavedPlacesDataSourceProvider =
    Provider<SupabaseSavedPlacesDataSource>((ref) {
  return SupabaseSavedPlacesDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseSavedPlacesDataSource {
  SupabaseSavedPlacesDataSource(this._client);

  final SupabaseClient _client;

  static const String _table = 'saved_places';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  SavedPlace _fromRow(Map<String, dynamic> row) => SavedPlace(
        id: row['id'] as String?,
        label: row['label'] as String? ?? '',
        type: SavedPlaceTypeX.fromWire(row['place_type'] as String? ?? 'favorite'),
        address: row['address'] as String? ?? '',
        location: GeoPoint(
          (row['latitude'] as num).toDouble(),
          (row['longitude'] as num).toDouble(),
        ),
      );

  Future<List<SavedPlace>> getSavedPlaces() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<SavedPlace> upsertSavedPlace(SavedPlace place) async {
    final payload = <String, dynamic>{
      'user_id': _userId,
      'label': place.label,
      'place_type': place.type.wire,
      'address': place.address,
      'latitude': place.location.latitude,
      'longitude': place.location.longitude,
    };

    Map<String, dynamic> row;
    if (place.type == SavedPlaceType.home ||
        place.type == SavedPlaceType.work) {
      final existing = await _client
          .from(_table)
          .select('id')
          .eq('user_id', _userId)
          .eq('place_type', place.type.wire)
          .maybeSingle();
      if (existing != null) {
        row = await _client
            .from(_table)
            .update(payload)
            .eq('id', existing['id'] as String)
            .select()
            .single();
      } else {
        row = await _client.from(_table).insert(payload).select().single();
      }
    } else if (place.id != null) {
      row = await _client
          .from(_table)
          .update(payload)
          .eq('id', place.id!)
          .select()
          .single();
    } else {
      row = await _client.from(_table).insert(payload).select().single();
    }
    return _fromRow(row);
  }

  Future<void> deleteSavedPlace(String id) async {
    await _client.from(_table).delete().eq('id', id).eq('user_id', _userId);
  }
}
