import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_set.freezed.dart';
part 'image_set.g.dart';

@freezed
class ImageSet with _$ImageSet {
  const factory ImageSet({
    String? thumbnail,
    String? medium,
    String? large,
  }) = _ImageSet;

  factory ImageSet.fromJson(Map<String, dynamic> json) =>
      _$ImageSetFromJson(json);
}
