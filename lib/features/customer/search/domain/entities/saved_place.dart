import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';

enum SavedPlaceType { home, work, favorite }

extension SavedPlaceTypeX on SavedPlaceType {
  String get wire {
    switch (this) {
      case SavedPlaceType.home:
        return 'home';
      case SavedPlaceType.work:
        return 'work';
      case SavedPlaceType.favorite:
        return 'favorite';
    }
  }

  static SavedPlaceType fromWire(String value) {
    switch (value) {
      case 'home':
        return SavedPlaceType.home;
      case 'work':
        return SavedPlaceType.work;
      default:
        return SavedPlaceType.favorite;
    }
  }
}

class SavedPlace {
  const SavedPlace({
    this.id,
    required this.label,
    required this.type,
    required this.address,
    required this.location,
  });

  final String? id;
  final String label;
  final SavedPlaceType type;
  final String address;
  final GeoPoint location;

  SavedPlace copyWith({
    String? id,
    String? label,
    SavedPlaceType? type,
    String? address,
    GeoPoint? location,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      address: address ?? this.address,
      location: location ?? this.location,
    );
  }
}
