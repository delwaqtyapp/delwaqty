import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';

class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.location,
    this.types = const [],
  });

  final String placeId;
  final String name;
  final String formattedAddress;
  final GeoPoint location;
  final List<String> types;
}
