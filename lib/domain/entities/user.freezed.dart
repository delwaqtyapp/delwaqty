// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$User {

 String get id; String get email; String? get fullName; String? get username; String? get phone; String? get avatarUrl; String get language; bool get isOnboarded; bool get isBiometricEnabled; String get role; UserType get userType; VerificationStatus get verificationStatus; String? get idCardUrl; String? get profilePhotoUrl; String? get tradeLicenseUrl; String? get drivingLicenseUrl; String? get rejectionReason; DateTime? get dateOfBirth; DateTime get createdAt; DateTime? get updatedAt;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as User;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.fullName, _this.fullName) || other.fullName == _this.fullName)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.phone, _this.phone) || other.phone == _this.phone)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.isOnboarded, _this.isOnboarded) || other.isOnboarded == _this.isOnboarded)&&(identical(other.isBiometricEnabled, _this.isBiometricEnabled) || other.isBiometricEnabled == _this.isBiometricEnabled)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.userType, _this.userType) || other.userType == _this.userType)&&(identical(other.verificationStatus, _this.verificationStatus) || other.verificationStatus == _this.verificationStatus)&&(identical(other.idCardUrl, _this.idCardUrl) || other.idCardUrl == _this.idCardUrl)&&(identical(other.profilePhotoUrl, _this.profilePhotoUrl) || other.profilePhotoUrl == _this.profilePhotoUrl)&&(identical(other.tradeLicenseUrl, _this.tradeLicenseUrl) || other.tradeLicenseUrl == _this.tradeLicenseUrl)&&(identical(other.drivingLicenseUrl, _this.drivingLicenseUrl) || other.drivingLicenseUrl == _this.drivingLicenseUrl)&&(identical(other.rejectionReason, _this.rejectionReason) || other.rejectionReason == _this.rejectionReason)&&(identical(other.dateOfBirth, _this.dateOfBirth) || other.dateOfBirth == _this.dateOfBirth)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as User;
  return Object.hashAll([runtimeType,_this.id,_this.email,_this.fullName,_this.username,_this.phone,_this.avatarUrl,_this.language,_this.isOnboarded,_this.isBiometricEnabled,_this.role,_this.userType,_this.verificationStatus,_this.idCardUrl,_this.profilePhotoUrl,_this.tradeLicenseUrl,_this.drivingLicenseUrl,_this.rejectionReason,_this.dateOfBirth,_this.createdAt,_this.updatedAt]);
}

@override
String toString() {
  final _this = this as User;
  return 'User(id: ${_this.id}, email: ${_this.email}, fullName: ${_this.fullName}, username: ${_this.username}, phone: ${_this.phone}, avatarUrl: ${_this.avatarUrl}, language: ${_this.language}, isOnboarded: ${_this.isOnboarded}, isBiometricEnabled: ${_this.isBiometricEnabled}, role: ${_this.role}, userType: ${_this.userType}, verificationStatus: ${_this.verificationStatus}, idCardUrl: ${_this.idCardUrl}, profilePhotoUrl: ${_this.profilePhotoUrl}, tradeLicenseUrl: ${_this.tradeLicenseUrl}, drivingLicenseUrl: ${_this.drivingLicenseUrl}, rejectionReason: ${_this.rejectionReason}, dateOfBirth: ${_this.dateOfBirth}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String id, String email, String? fullName, String? username, String? phone, String? avatarUrl, String language, bool isOnboarded, bool isBiometricEnabled, String role, UserType userType, VerificationStatus verificationStatus, String? idCardUrl, String? profilePhotoUrl, String? tradeLicenseUrl, String? drivingLicenseUrl, String? rejectionReason, DateTime? dateOfBirth, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? fullName = freezed,Object? username = freezed,Object? phone = freezed,Object? avatarUrl = freezed,Object? language = null,Object? isOnboarded = null,Object? isBiometricEnabled = null,Object? role = null,Object? userType = null,Object? verificationStatus = null,Object? idCardUrl = freezed,Object? profilePhotoUrl = freezed,Object? tradeLicenseUrl = freezed,Object? drivingLicenseUrl = freezed,Object? rejectionReason = freezed,Object? dateOfBirth = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,fullName: freezed == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,isOnboarded: null == isOnboarded ? _self.isOnboarded : isOnboarded // ignore: cast_nullable_to_non_nullable
as bool,isBiometricEnabled: null == isBiometricEnabled ? _self.isBiometricEnabled : isBiometricEnabled // ignore: cast_nullable_to_non_nullable
as bool,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,userType: null == userType ? _self.userType : userType // ignore: cast_nullable_to_non_nullable
as UserType,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as VerificationStatus,idCardUrl: freezed == idCardUrl ? _self.idCardUrl : idCardUrl // ignore: cast_nullable_to_non_nullable
as String?,profilePhotoUrl: freezed == profilePhotoUrl ? _self.profilePhotoUrl : profilePhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,tradeLicenseUrl: freezed == tradeLicenseUrl ? _self.tradeLicenseUrl : tradeLicenseUrl // ignore: cast_nullable_to_non_nullable
as String?,drivingLicenseUrl: freezed == drivingLicenseUrl ? _self.drivingLicenseUrl : drivingLicenseUrl // ignore: cast_nullable_to_non_nullable
as String?,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  String? fullName,  String? username,  String? phone,  String? avatarUrl,  String language,  bool isOnboarded,  bool isBiometricEnabled,  String role,  UserType userType,  VerificationStatus verificationStatus,  String? idCardUrl,  String? profilePhotoUrl,  String? tradeLicenseUrl,  String? drivingLicenseUrl,  String? rejectionReason,  DateTime? dateOfBirth,  DateTime createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.fullName,_that.username,_that.phone,_that.avatarUrl,_that.language,_that.isOnboarded,_that.isBiometricEnabled,_that.role,_that.userType,_that.verificationStatus,_that.idCardUrl,_that.profilePhotoUrl,_that.tradeLicenseUrl,_that.drivingLicenseUrl,_that.rejectionReason,_that.dateOfBirth,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  String? fullName,  String? username,  String? phone,  String? avatarUrl,  String language,  bool isOnboarded,  bool isBiometricEnabled,  String role,  UserType userType,  VerificationStatus verificationStatus,  String? idCardUrl,  String? profilePhotoUrl,  String? tradeLicenseUrl,  String? drivingLicenseUrl,  String? rejectionReason,  DateTime? dateOfBirth,  DateTime createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.email,_that.fullName,_that.username,_that.phone,_that.avatarUrl,_that.language,_that.isOnboarded,_that.isBiometricEnabled,_that.role,_that.userType,_that.verificationStatus,_that.idCardUrl,_that.profilePhotoUrl,_that.tradeLicenseUrl,_that.drivingLicenseUrl,_that.rejectionReason,_that.dateOfBirth,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  String? fullName,  String? username,  String? phone,  String? avatarUrl,  String language,  bool isOnboarded,  bool isBiometricEnabled,  String role,  UserType userType,  VerificationStatus verificationStatus,  String? idCardUrl,  String? profilePhotoUrl,  String? tradeLicenseUrl,  String? drivingLicenseUrl,  String? rejectionReason,  DateTime? dateOfBirth,  DateTime createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.fullName,_that.username,_that.phone,_that.avatarUrl,_that.language,_that.isOnboarded,_that.isBiometricEnabled,_that.role,_that.userType,_that.verificationStatus,_that.idCardUrl,_that.profilePhotoUrl,_that.tradeLicenseUrl,_that.drivingLicenseUrl,_that.rejectionReason,_that.dateOfBirth,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _User implements User {
  const _User({required this.id, required this.email, this.fullName, this.username, this.phone, this.avatarUrl, this.language = 'en', this.isOnboarded = false, this.isBiometricEnabled = false, this.role = 'customer', this.userType = UserType.customer, this.verificationStatus = VerificationStatus.pending, this.idCardUrl, this.profilePhotoUrl, this.tradeLicenseUrl, this.drivingLicenseUrl, this.rejectionReason, this.dateOfBirth, required this.createdAt, this.updatedAt});
  factory _User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

@override final  String id;
@override final  String email;
@override final  String? fullName;
@override final  String? username;
@override final  String? phone;
@override final  String? avatarUrl;
@override@JsonKey() final  String language;
@override@JsonKey() final  bool isOnboarded;
@override@JsonKey() final  bool isBiometricEnabled;
@override@JsonKey() final  String role;
@override@JsonKey() final  UserType userType;
@override@JsonKey() final  VerificationStatus verificationStatus;
@override final  String? idCardUrl;
@override final  String? profilePhotoUrl;
@override final  String? tradeLicenseUrl;
@override final  String? drivingLicenseUrl;
@override final  String? rejectionReason;
@override final  DateTime? dateOfBirth;
@override final  DateTime createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.username, username) || other.username == username)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.language, language) || other.language == language)&&(identical(other.isOnboarded, isOnboarded) || other.isOnboarded == isOnboarded)&&(identical(other.isBiometricEnabled, isBiometricEnabled) || other.isBiometricEnabled == isBiometricEnabled)&&(identical(other.role, role) || other.role == role)&&(identical(other.userType, userType) || other.userType == userType)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.idCardUrl, idCardUrl) || other.idCardUrl == idCardUrl)&&(identical(other.profilePhotoUrl, profilePhotoUrl) || other.profilePhotoUrl == profilePhotoUrl)&&(identical(other.tradeLicenseUrl, tradeLicenseUrl) || other.tradeLicenseUrl == tradeLicenseUrl)&&(identical(other.drivingLicenseUrl, drivingLicenseUrl) || other.drivingLicenseUrl == drivingLicenseUrl)&&(identical(other.rejectionReason, rejectionReason) || other.rejectionReason == rejectionReason)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,email,fullName,username,phone,avatarUrl,language,isOnboarded,isBiometricEnabled,role,userType,verificationStatus,idCardUrl,profilePhotoUrl,tradeLicenseUrl,drivingLicenseUrl,rejectionReason,dateOfBirth,createdAt,updatedAt]);
}

@override
String toString() {
    return 'User(id: $id, email: $email, fullName: $fullName, username: $username, phone: $phone, avatarUrl: $avatarUrl, language: $language, isOnboarded: $isOnboarded, isBiometricEnabled: $isBiometricEnabled, role: $role, userType: $userType, verificationStatus: $verificationStatus, idCardUrl: $idCardUrl, profilePhotoUrl: $profilePhotoUrl, tradeLicenseUrl: $tradeLicenseUrl, drivingLicenseUrl: $drivingLicenseUrl, rejectionReason: $rejectionReason, dateOfBirth: $dateOfBirth, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, String? fullName, String? username, String? phone, String? avatarUrl, String language, bool isOnboarded, bool isBiometricEnabled, String role, UserType userType, VerificationStatus verificationStatus, String? idCardUrl, String? profilePhotoUrl, String? tradeLicenseUrl, String? drivingLicenseUrl, String? rejectionReason, DateTime? dateOfBirth, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? fullName = freezed,Object? username = freezed,Object? phone = freezed,Object? avatarUrl = freezed,Object? language = null,Object? isOnboarded = null,Object? isBiometricEnabled = null,Object? role = null,Object? userType = null,Object? verificationStatus = null,Object? idCardUrl = freezed,Object? profilePhotoUrl = freezed,Object? tradeLicenseUrl = freezed,Object? drivingLicenseUrl = freezed,Object? rejectionReason = freezed,Object? dateOfBirth = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,fullName: freezed == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,isOnboarded: null == isOnboarded ? _self.isOnboarded : isOnboarded // ignore: cast_nullable_to_non_nullable
as bool,isBiometricEnabled: null == isBiometricEnabled ? _self.isBiometricEnabled : isBiometricEnabled // ignore: cast_nullable_to_non_nullable
as bool,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,userType: null == userType ? _self.userType : userType // ignore: cast_nullable_to_non_nullable
as UserType,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as VerificationStatus,idCardUrl: freezed == idCardUrl ? _self.idCardUrl : idCardUrl // ignore: cast_nullable_to_non_nullable
as String?,profilePhotoUrl: freezed == profilePhotoUrl ? _self.profilePhotoUrl : profilePhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,tradeLicenseUrl: freezed == tradeLicenseUrl ? _self.tradeLicenseUrl : tradeLicenseUrl // ignore: cast_nullable_to_non_nullable
as String?,drivingLicenseUrl: freezed == drivingLicenseUrl ? _self.drivingLicenseUrl : drivingLicenseUrl // ignore: cast_nullable_to_non_nullable
as String?,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
