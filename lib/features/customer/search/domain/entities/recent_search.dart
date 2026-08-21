import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';

class RecentSearch {
  const RecentSearch({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.location,
    required this.searchedAt,
  });

  factory RecentSearch.fromJson(Map<String, dynamic> json) => RecentSearch(
        placeId: json['placeId'] as String,
        primaryText: json['primaryText'] as String,
        secondaryText: json['secondaryText'] as String? ?? '',
        location: GeoPoint(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        searchedAt: DateTime.tryParse(json['searchedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final GeoPoint location;
  final DateTime searchedAt;

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'primaryText': primaryText,
        'secondaryText': secondaryText,
        'lat': location.latitude,
        'lng': location.longitude,
        'searchedAt': searchedAt.toIso8601String(),
      };
}
