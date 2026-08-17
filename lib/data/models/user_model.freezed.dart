// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String? get fullName => throw _privateConstructorUsedError;
  String? get username => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String get language => throw _privateConstructorUsedError;
  bool get isOnboarded => throw _privateConstructorUsedError;
  bool get isBiometricEnabled => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  UserType get userType => throw _privateConstructorUsedError;
  VerificationStatus get verificationStatus =>
      throw _privateConstructorUsedError;
  String? get idCardUrl => throw _privateConstructorUsedError;
  String? get profilePhotoUrl => throw _privateConstructorUsedError;
  String? get tradeLicenseUrl => throw _privateConstructorUsedError;
  String? get drivingLicenseUrl => throw _privateConstructorUsedError;
  DateTime? get dateOfBirth => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call({
    String id,
    String email,
    String? fullName,
    String? username,
    String? phone,
    String? avatarUrl,
    String language,
    bool isOnboarded,
    bool isBiometricEnabled,
    String role,
    UserType userType,
    VerificationStatus verificationStatus,
    String? idCardUrl,
    String? profilePhotoUrl,
    String? tradeLicenseUrl,
    String? drivingLicenseUrl,
    DateTime? dateOfBirth,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? fullName = freezed,
    Object? username = freezed,
    Object? phone = freezed,
    Object? avatarUrl = freezed,
    Object? language = null,
    Object? isOnboarded = null,
    Object? isBiometricEnabled = null,
    Object? role = null,
    Object? userType = null,
    Object? verificationStatus = null,
    Object? idCardUrl = freezed,
    Object? profilePhotoUrl = freezed,
    Object? tradeLicenseUrl = freezed,
    Object? drivingLicenseUrl = freezed,
    Object? dateOfBirth = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            fullName: freezed == fullName
                ? _value.fullName
                : fullName // ignore: cast_nullable_to_non_nullable
                      as String?,
            username: freezed == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String?,
            phone: freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String?,
            avatarUrl: freezed == avatarUrl
                ? _value.avatarUrl
                : avatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            language: null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                      as String,
            isOnboarded: null == isOnboarded
                ? _value.isOnboarded
                : isOnboarded // ignore: cast_nullable_to_non_nullable
                      as bool,
            isBiometricEnabled: null == isBiometricEnabled
                ? _value.isBiometricEnabled
                : isBiometricEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String,
            userType: null == userType
                ? _value.userType
                : userType // ignore: cast_nullable_to_non_nullable
                      as UserType,
            verificationStatus: null == verificationStatus
                ? _value.verificationStatus
                : verificationStatus // ignore: cast_nullable_to_non_nullable
                      as VerificationStatus,
            idCardUrl: freezed == idCardUrl
                ? _value.idCardUrl
                : idCardUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            profilePhotoUrl: freezed == profilePhotoUrl
                ? _value.profilePhotoUrl
                : profilePhotoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            tradeLicenseUrl: freezed == tradeLicenseUrl
                ? _value.tradeLicenseUrl
                : tradeLicenseUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            drivingLicenseUrl: freezed == drivingLicenseUrl
                ? _value.drivingLicenseUrl
                : drivingLicenseUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            dateOfBirth: freezed == dateOfBirth
                ? _value.dateOfBirth
                : dateOfBirth // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
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
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
    _$UserModelImpl value,
    $Res Function(_$UserModelImpl) then,
  ) = __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String email,
    String? fullName,
    String? username,
    String? phone,
    String? avatarUrl,
    String language,
    bool isOnboarded,
    bool isBiometricEnabled,
    String role,
    UserType userType,
    VerificationStatus verificationStatus,
    String? idCardUrl,
    String? profilePhotoUrl,
    String? tradeLicenseUrl,
    String? drivingLicenseUrl,
    DateTime? dateOfBirth,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
    _$UserModelImpl _value,
    $Res Function(_$UserModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? fullName = freezed,
    Object? username = freezed,
    Object? phone = freezed,
    Object? avatarUrl = freezed,
    Object? language = null,
    Object? isOnboarded = null,
    Object? isBiometricEnabled = null,
    Object? role = null,
    Object? userType = null,
    Object? verificationStatus = null,
    Object? idCardUrl = freezed,
    Object? profilePhotoUrl = freezed,
    Object? tradeLicenseUrl = freezed,
    Object? drivingLicenseUrl = freezed,
    Object? dateOfBirth = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$UserModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        fullName: freezed == fullName
            ? _value.fullName
            : fullName // ignore: cast_nullable_to_non_nullable
                  as String?,
        username: freezed == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String?,
        phone: freezed == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String?,
        avatarUrl: freezed == avatarUrl
            ? _value.avatarUrl
            : avatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        language: null == language
            ? _value.language
            : language // ignore: cast_nullable_to_non_nullable
                  as String,
        isOnboarded: null == isOnboarded
            ? _value.isOnboarded
            : isOnboarded // ignore: cast_nullable_to_non_nullable
                  as bool,
        isBiometricEnabled: null == isBiometricEnabled
            ? _value.isBiometricEnabled
            : isBiometricEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String,
        userType: null == userType
            ? _value.userType
            : userType // ignore: cast_nullable_to_non_nullable
                  as UserType,
        verificationStatus: null == verificationStatus
            ? _value.verificationStatus
            : verificationStatus // ignore: cast_nullable_to_non_nullable
                  as VerificationStatus,
        idCardUrl: freezed == idCardUrl
            ? _value.idCardUrl
            : idCardUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        profilePhotoUrl: freezed == profilePhotoUrl
            ? _value.profilePhotoUrl
            : profilePhotoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        tradeLicenseUrl: freezed == tradeLicenseUrl
            ? _value.tradeLicenseUrl
            : tradeLicenseUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        drivingLicenseUrl: freezed == drivingLicenseUrl
            ? _value.drivingLicenseUrl
            : drivingLicenseUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        dateOfBirth: freezed == dateOfBirth
            ? _value.dateOfBirth
            : dateOfBirth // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
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
class _$UserModelImpl extends _UserModel {
  const _$UserModelImpl({
    required this.id,
    required this.email,
    this.fullName,
    this.username,
    this.phone,
    this.avatarUrl,
    this.language = 'en',
    this.isOnboarded = false,
    this.isBiometricEnabled = false,
    this.role = 'customer',
    this.userType = UserType.customer,
    this.verificationStatus = VerificationStatus.pending,
    this.idCardUrl,
    this.profilePhotoUrl,
    this.tradeLicenseUrl,
    this.drivingLicenseUrl,
    this.dateOfBirth,
    required this.createdAt,
    this.updatedAt,
  }) : super._();

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  @override
  final String id;
  @override
  final String email;
  @override
  final String? fullName;
  @override
  final String? username;
  @override
  final String? phone;
  @override
  final String? avatarUrl;
  @override
  @JsonKey()
  final String language;
  @override
  @JsonKey()
  final bool isOnboarded;
  @override
  @JsonKey()
  final bool isBiometricEnabled;
  @override
  @JsonKey()
  final String role;
  @override
  @JsonKey()
  final UserType userType;
  @override
  @JsonKey()
  final VerificationStatus verificationStatus;
  @override
  final String? idCardUrl;
  @override
  final String? profilePhotoUrl;
  @override
  final String? tradeLicenseUrl;
  @override
  final String? drivingLicenseUrl;
  @override
  final DateTime? dateOfBirth;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, fullName: $fullName, username: $username, phone: $phone, avatarUrl: $avatarUrl, language: $language, isOnboarded: $isOnboarded, isBiometricEnabled: $isBiometricEnabled, role: $role, userType: $userType, verificationStatus: $verificationStatus, idCardUrl: $idCardUrl, profilePhotoUrl: $profilePhotoUrl, tradeLicenseUrl: $tradeLicenseUrl, drivingLicenseUrl: $drivingLicenseUrl, dateOfBirth: $dateOfBirth, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.isOnboarded, isOnboarded) ||
                other.isOnboarded == isOnboarded) &&
            (identical(other.isBiometricEnabled, isBiometricEnabled) ||
                other.isBiometricEnabled == isBiometricEnabled) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.userType, userType) ||
                other.userType == userType) &&
            (identical(other.verificationStatus, verificationStatus) ||
                other.verificationStatus == verificationStatus) &&
            (identical(other.idCardUrl, idCardUrl) ||
                other.idCardUrl == idCardUrl) &&
            (identical(other.profilePhotoUrl, profilePhotoUrl) ||
                other.profilePhotoUrl == profilePhotoUrl) &&
            (identical(other.tradeLicenseUrl, tradeLicenseUrl) ||
                other.tradeLicenseUrl == tradeLicenseUrl) &&
            (identical(other.drivingLicenseUrl, drivingLicenseUrl) ||
                other.drivingLicenseUrl == drivingLicenseUrl) &&
            (identical(other.dateOfBirth, dateOfBirth) ||
                other.dateOfBirth == dateOfBirth) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    email,
    fullName,
    username,
    phone,
    avatarUrl,
    language,
    isOnboarded,
    isBiometricEnabled,
    role,
    userType,
    verificationStatus,
    idCardUrl,
    profilePhotoUrl,
    tradeLicenseUrl,
    drivingLicenseUrl,
    dateOfBirth,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(this);
  }
}

abstract class _UserModel extends UserModel {
  const factory _UserModel({
    required final String id,
    required final String email,
    final String? fullName,
    final String? username,
    final String? phone,
    final String? avatarUrl,
    final String language,
    final bool isOnboarded,
    final bool isBiometricEnabled,
    final String role,
    final UserType userType,
    final VerificationStatus verificationStatus,
    final String? idCardUrl,
    final String? profilePhotoUrl,
    final String? tradeLicenseUrl,
    final String? drivingLicenseUrl,
    final DateTime? dateOfBirth,
    required final DateTime createdAt,
    final DateTime? updatedAt,
  }) = _$UserModelImpl;
  const _UserModel._() : super._();

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override
  String get id;
  @override
  String get email;
  @override
  String? get fullName;
  @override
  String? get username;
  @override
  String? get phone;
  @override
  String? get avatarUrl;
  @override
  String get language;
  @override
  bool get isOnboarded;
  @override
  bool get isBiometricEnabled;
  @override
  String get role;
  @override
  UserType get userType;
  @override
  VerificationStatus get verificationStatus;
  @override
  String? get idCardUrl;
  @override
  String? get profilePhotoUrl;
  @override
  String? get tradeLicenseUrl;
  @override
  String? get drivingLicenseUrl;
  @override
  DateTime? get dateOfBirth;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
