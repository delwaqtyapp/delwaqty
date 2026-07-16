// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Review _$ReviewFromJson(Map<String, dynamic> json) {
  return _Review.fromJson(json);
}

/// @nodoc
mixin _$Review {
  String get id => throw _privateConstructorUsedError;
  String get merchantId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String? get userName => throw _privateConstructorUsedError;
  String? get productId => throw _privateConstructorUsedError;
  String? get orderId => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  String? get comment => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Review to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewCopyWith<Review> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewCopyWith<$Res> {
  factory $ReviewCopyWith(Review value, $Res Function(Review) then) =
      _$ReviewCopyWithImpl<$Res, Review>;
  @useResult
  $Res call({
    String id,
    String merchantId,
    String userId,
    String? userName,
    String? productId,
    String? orderId,
    double rating,
    String? comment,
    List<String> imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$ReviewCopyWithImpl<$Res, $Val extends Review>
    implements $ReviewCopyWith<$Res> {
  _$ReviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? userId = null,
    Object? userName = freezed,
    Object? productId = freezed,
    Object? orderId = freezed,
    Object? rating = null,
    Object? comment = freezed,
    Object? imageUrls = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            merchantId: null == merchantId
                ? _value.merchantId
                : merchantId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            userName: freezed == userName
                ? _value.userName
                : userName // ignore: cast_nullable_to_non_nullable
                      as String?,
            productId: freezed == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String?,
            orderId: freezed == orderId
                ? _value.orderId
                : orderId // ignore: cast_nullable_to_non_nullable
                      as String?,
            rating: null == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                      as double,
            comment: freezed == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String?,
            imageUrls: null == imageUrls
                ? _value.imageUrls
                : imageUrls // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewImplCopyWith<$Res> implements $ReviewCopyWith<$Res> {
  factory _$$ReviewImplCopyWith(
    _$ReviewImpl value,
    $Res Function(_$ReviewImpl) then,
  ) = __$$ReviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String merchantId,
    String userId,
    String? userName,
    String? productId,
    String? orderId,
    double rating,
    String? comment,
    List<String> imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$ReviewImplCopyWithImpl<$Res>
    extends _$ReviewCopyWithImpl<$Res, _$ReviewImpl>
    implements _$$ReviewImplCopyWith<$Res> {
  __$$ReviewImplCopyWithImpl(
    _$ReviewImpl _value,
    $Res Function(_$ReviewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? userId = null,
    Object? userName = freezed,
    Object? productId = freezed,
    Object? orderId = freezed,
    Object? rating = null,
    Object? comment = freezed,
    Object? imageUrls = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ReviewImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        merchantId: null == merchantId
            ? _value.merchantId
            : merchantId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        userName: freezed == userName
            ? _value.userName
            : userName // ignore: cast_nullable_to_non_nullable
                  as String?,
        productId: freezed == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String?,
        orderId: freezed == orderId
            ? _value.orderId
            : orderId // ignore: cast_nullable_to_non_nullable
                  as String?,
        rating: null == rating
            ? _value.rating
            : rating // ignore: cast_nullable_to_non_nullable
                  as double,
        comment: freezed == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageUrls: null == imageUrls
            ? _value._imageUrls
            : imageUrls // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewImpl implements _Review {
  const _$ReviewImpl({
    required this.id,
    required this.merchantId,
    required this.userId,
    this.userName,
    this.productId,
    this.orderId,
    required this.rating,
    this.comment,
    final List<String> imageUrls = const [],
    this.createdAt,
    this.updatedAt,
  }) : _imageUrls = imageUrls;

  factory _$ReviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewImplFromJson(json);

  @override
  final String id;
  @override
  final String merchantId;
  @override
  final String userId;
  @override
  final String? userName;
  @override
  final String? productId;
  @override
  final String? orderId;
  @override
  final double rating;
  @override
  final String? comment;
  final List<String> _imageUrls;
  @override
  @JsonKey()
  List<String> get imageUrls {
    if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageUrls);
  }

  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Review(id: $id, merchantId: $merchantId, userId: $userId, userName: $userName, productId: $productId, orderId: $orderId, rating: $rating, comment: $comment, imageUrls: $imageUrls, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            const DeepCollectionEquality().equals(
              other._imageUrls,
              _imageUrls,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    merchantId,
    userId,
    userName,
    productId,
    orderId,
    rating,
    comment,
    const DeepCollectionEquality().hash(_imageUrls),
    createdAt,
    updatedAt,
  );

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewImplCopyWith<_$ReviewImpl> get copyWith =>
      __$$ReviewImplCopyWithImpl<_$ReviewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewImplToJson(this);
  }
}

abstract class _Review implements Review {
  const factory _Review({
    required final String id,
    required final String merchantId,
    required final String userId,
    final String? userName,
    final String? productId,
    final String? orderId,
    required final double rating,
    final String? comment,
    final List<String> imageUrls,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$ReviewImpl;

  factory _Review.fromJson(Map<String, dynamic> json) = _$ReviewImpl.fromJson;

  @override
  String get id;
  @override
  String get merchantId;
  @override
  String get userId;
  @override
  String? get userName;
  @override
  String? get productId;
  @override
  String? get orderId;
  @override
  double get rating;
  @override
  String? get comment;
  @override
  List<String> get imageUrls;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewImplCopyWith<_$ReviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReviewSummary _$ReviewSummaryFromJson(Map<String, dynamic> json) {
  return _ReviewSummary.fromJson(json);
}

/// @nodoc
mixin _$ReviewSummary {
  double get averageRating => throw _privateConstructorUsedError;
  int get totalReviews => throw _privateConstructorUsedError;
  int get fiveStarCount => throw _privateConstructorUsedError;
  int get fourStarCount => throw _privateConstructorUsedError;
  int get threeStarCount => throw _privateConstructorUsedError;
  int get twoStarCount => throw _privateConstructorUsedError;
  int get oneStarCount => throw _privateConstructorUsedError;

  /// Serializes this ReviewSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewSummaryCopyWith<ReviewSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewSummaryCopyWith<$Res> {
  factory $ReviewSummaryCopyWith(
    ReviewSummary value,
    $Res Function(ReviewSummary) then,
  ) = _$ReviewSummaryCopyWithImpl<$Res, ReviewSummary>;
  @useResult
  $Res call({
    double averageRating,
    int totalReviews,
    int fiveStarCount,
    int fourStarCount,
    int threeStarCount,
    int twoStarCount,
    int oneStarCount,
  });
}

/// @nodoc
class _$ReviewSummaryCopyWithImpl<$Res, $Val extends ReviewSummary>
    implements $ReviewSummaryCopyWith<$Res> {
  _$ReviewSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? averageRating = null,
    Object? totalReviews = null,
    Object? fiveStarCount = null,
    Object? fourStarCount = null,
    Object? threeStarCount = null,
    Object? twoStarCount = null,
    Object? oneStarCount = null,
  }) {
    return _then(
      _value.copyWith(
            averageRating: null == averageRating
                ? _value.averageRating
                : averageRating // ignore: cast_nullable_to_non_nullable
                      as double,
            totalReviews: null == totalReviews
                ? _value.totalReviews
                : totalReviews // ignore: cast_nullable_to_non_nullable
                      as int,
            fiveStarCount: null == fiveStarCount
                ? _value.fiveStarCount
                : fiveStarCount // ignore: cast_nullable_to_non_nullable
                      as int,
            fourStarCount: null == fourStarCount
                ? _value.fourStarCount
                : fourStarCount // ignore: cast_nullable_to_non_nullable
                      as int,
            threeStarCount: null == threeStarCount
                ? _value.threeStarCount
                : threeStarCount // ignore: cast_nullable_to_non_nullable
                      as int,
            twoStarCount: null == twoStarCount
                ? _value.twoStarCount
                : twoStarCount // ignore: cast_nullable_to_non_nullable
                      as int,
            oneStarCount: null == oneStarCount
                ? _value.oneStarCount
                : oneStarCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewSummaryImplCopyWith<$Res>
    implements $ReviewSummaryCopyWith<$Res> {
  factory _$$ReviewSummaryImplCopyWith(
    _$ReviewSummaryImpl value,
    $Res Function(_$ReviewSummaryImpl) then,
  ) = __$$ReviewSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double averageRating,
    int totalReviews,
    int fiveStarCount,
    int fourStarCount,
    int threeStarCount,
    int twoStarCount,
    int oneStarCount,
  });
}

/// @nodoc
class __$$ReviewSummaryImplCopyWithImpl<$Res>
    extends _$ReviewSummaryCopyWithImpl<$Res, _$ReviewSummaryImpl>
    implements _$$ReviewSummaryImplCopyWith<$Res> {
  __$$ReviewSummaryImplCopyWithImpl(
    _$ReviewSummaryImpl _value,
    $Res Function(_$ReviewSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? averageRating = null,
    Object? totalReviews = null,
    Object? fiveStarCount = null,
    Object? fourStarCount = null,
    Object? threeStarCount = null,
    Object? twoStarCount = null,
    Object? oneStarCount = null,
  }) {
    return _then(
      _$ReviewSummaryImpl(
        averageRating: null == averageRating
            ? _value.averageRating
            : averageRating // ignore: cast_nullable_to_non_nullable
                  as double,
        totalReviews: null == totalReviews
            ? _value.totalReviews
            : totalReviews // ignore: cast_nullable_to_non_nullable
                  as int,
        fiveStarCount: null == fiveStarCount
            ? _value.fiveStarCount
            : fiveStarCount // ignore: cast_nullable_to_non_nullable
                  as int,
        fourStarCount: null == fourStarCount
            ? _value.fourStarCount
            : fourStarCount // ignore: cast_nullable_to_non_nullable
                  as int,
        threeStarCount: null == threeStarCount
            ? _value.threeStarCount
            : threeStarCount // ignore: cast_nullable_to_non_nullable
                  as int,
        twoStarCount: null == twoStarCount
            ? _value.twoStarCount
            : twoStarCount // ignore: cast_nullable_to_non_nullable
                  as int,
        oneStarCount: null == oneStarCount
            ? _value.oneStarCount
            : oneStarCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewSummaryImpl implements _ReviewSummary {
  const _$ReviewSummaryImpl({
    required this.averageRating,
    required this.totalReviews,
    this.fiveStarCount = 0,
    this.fourStarCount = 0,
    this.threeStarCount = 0,
    this.twoStarCount = 0,
    this.oneStarCount = 0,
  });

  factory _$ReviewSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewSummaryImplFromJson(json);

  @override
  final double averageRating;
  @override
  final int totalReviews;
  @override
  @JsonKey()
  final int fiveStarCount;
  @override
  @JsonKey()
  final int fourStarCount;
  @override
  @JsonKey()
  final int threeStarCount;
  @override
  @JsonKey()
  final int twoStarCount;
  @override
  @JsonKey()
  final int oneStarCount;

  @override
  String toString() {
    return 'ReviewSummary(averageRating: $averageRating, totalReviews: $totalReviews, fiveStarCount: $fiveStarCount, fourStarCount: $fourStarCount, threeStarCount: $threeStarCount, twoStarCount: $twoStarCount, oneStarCount: $oneStarCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewSummaryImpl &&
            (identical(other.averageRating, averageRating) ||
                other.averageRating == averageRating) &&
            (identical(other.totalReviews, totalReviews) ||
                other.totalReviews == totalReviews) &&
            (identical(other.fiveStarCount, fiveStarCount) ||
                other.fiveStarCount == fiveStarCount) &&
            (identical(other.fourStarCount, fourStarCount) ||
                other.fourStarCount == fourStarCount) &&
            (identical(other.threeStarCount, threeStarCount) ||
                other.threeStarCount == threeStarCount) &&
            (identical(other.twoStarCount, twoStarCount) ||
                other.twoStarCount == twoStarCount) &&
            (identical(other.oneStarCount, oneStarCount) ||
                other.oneStarCount == oneStarCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    averageRating,
    totalReviews,
    fiveStarCount,
    fourStarCount,
    threeStarCount,
    twoStarCount,
    oneStarCount,
  );

  /// Create a copy of ReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewSummaryImplCopyWith<_$ReviewSummaryImpl> get copyWith =>
      __$$ReviewSummaryImplCopyWithImpl<_$ReviewSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewSummaryImplToJson(this);
  }
}

abstract class _ReviewSummary implements ReviewSummary {
  const factory _ReviewSummary({
    required final double averageRating,
    required final int totalReviews,
    final int fiveStarCount,
    final int fourStarCount,
    final int threeStarCount,
    final int twoStarCount,
    final int oneStarCount,
  }) = _$ReviewSummaryImpl;

  factory _ReviewSummary.fromJson(Map<String, dynamic> json) =
      _$ReviewSummaryImpl.fromJson;

  @override
  double get averageRating;
  @override
  int get totalReviews;
  @override
  int get fiveStarCount;
  @override
  int get fourStarCount;
  @override
  int get threeStarCount;
  @override
  int get twoStarCount;
  @override
  int get oneStarCount;

  /// Create a copy of ReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewSummaryImplCopyWith<_$ReviewSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
