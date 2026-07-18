class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    this.distanceMeters,
    this.types = const [],
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final int? distanceMeters;
  final List<String> types;

  String get fullText =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';

  @override
  bool operator ==(Object other) =>
      other is PlaceSuggestion && other.placeId == placeId;

  @override
  int get hashCode => placeId.hashCode;
}
