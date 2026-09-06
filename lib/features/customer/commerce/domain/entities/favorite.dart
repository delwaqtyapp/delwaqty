import 'package:freezed_annotation/freezed_annotation.dart';

part 'favorite.freezed.dart';
part 'favorite.g.dart';

enum FavoriteType {
  @JsonValue('merchant')
  merchant,
  @JsonValue('product')
  product,
}

@freezed
abstract class Favorite with _$Favorite {
  const factory Favorite({
    required String id,
    required String targetId,
    required FavoriteType type,
    required DateTime createdAt,
  }) = _Favorite;

  factory Favorite.fromJson(Map<String, dynamic> json) =>
      _$FavoriteFromJson(json);
}
