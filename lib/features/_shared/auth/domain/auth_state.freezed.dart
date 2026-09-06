// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AuthState()';
}


}

/// @nodoc
class $AuthStateCopyWith<$Res>  {
$AuthStateCopyWith(AuthState _, $Res Function(AuthState) __);
}


/// Adds pattern-matching-related methods to [AuthState].
extension AuthStatePatterns on AuthState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AuthInitial value)?  initial,TResult Function( AuthLoading value)?  loading,TResult Function( AuthAuthenticated value)?  authenticated,TResult Function( AuthGuest value)?  guest,TResult Function( AuthUnauthenticated value)?  unauthenticated,TResult Function( AuthPhoneVerification value)?  phoneVerificationRequired,TResult Function( AuthEmailConfirmationRequired value)?  emailConfirmationRequired,TResult Function( AuthPendingVerification value)?  pendingVerification,TResult Function( AuthError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AuthInitial() when initial != null:
return initial(_that);case AuthLoading() when loading != null:
return loading(_that);case AuthAuthenticated() when authenticated != null:
return authenticated(_that);case AuthGuest() when guest != null:
return guest(_that);case AuthUnauthenticated() when unauthenticated != null:
return unauthenticated(_that);case AuthPhoneVerification() when phoneVerificationRequired != null:
return phoneVerificationRequired(_that);case AuthEmailConfirmationRequired() when emailConfirmationRequired != null:
return emailConfirmationRequired(_that);case AuthPendingVerification() when pendingVerification != null:
return pendingVerification(_that);case AuthError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AuthInitial value)  initial,required TResult Function( AuthLoading value)  loading,required TResult Function( AuthAuthenticated value)  authenticated,required TResult Function( AuthGuest value)  guest,required TResult Function( AuthUnauthenticated value)  unauthenticated,required TResult Function( AuthPhoneVerification value)  phoneVerificationRequired,required TResult Function( AuthEmailConfirmationRequired value)  emailConfirmationRequired,required TResult Function( AuthPendingVerification value)  pendingVerification,required TResult Function( AuthError value)  error,}){
final _that = this;
switch (_that) {
case AuthInitial():
return initial(_that);case AuthLoading():
return loading(_that);case AuthAuthenticated():
return authenticated(_that);case AuthGuest():
return guest(_that);case AuthUnauthenticated():
return unauthenticated(_that);case AuthPhoneVerification():
return phoneVerificationRequired(_that);case AuthEmailConfirmationRequired():
return emailConfirmationRequired(_that);case AuthPendingVerification():
return pendingVerification(_that);case AuthError():
return error(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AuthInitial value)?  initial,TResult? Function( AuthLoading value)?  loading,TResult? Function( AuthAuthenticated value)?  authenticated,TResult? Function( AuthGuest value)?  guest,TResult? Function( AuthUnauthenticated value)?  unauthenticated,TResult? Function( AuthPhoneVerification value)?  phoneVerificationRequired,TResult? Function( AuthEmailConfirmationRequired value)?  emailConfirmationRequired,TResult? Function( AuthPendingVerification value)?  pendingVerification,TResult? Function( AuthError value)?  error,}){
final _that = this;
switch (_that) {
case AuthInitial() when initial != null:
return initial(_that);case AuthLoading() when loading != null:
return loading(_that);case AuthAuthenticated() when authenticated != null:
return authenticated(_that);case AuthGuest() when guest != null:
return guest(_that);case AuthUnauthenticated() when unauthenticated != null:
return unauthenticated(_that);case AuthPhoneVerification() when phoneVerificationRequired != null:
return phoneVerificationRequired(_that);case AuthEmailConfirmationRequired() when emailConfirmationRequired != null:
return emailConfirmationRequired(_that);case AuthPendingVerification() when pendingVerification != null:
return pendingVerification(_that);case AuthError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  loading,TResult Function( User user)?  authenticated,TResult Function()?  guest,TResult Function()?  unauthenticated,TResult Function( String phone)?  phoneVerificationRequired,TResult Function( String email)?  emailConfirmationRequired,TResult Function()?  pendingVerification,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AuthInitial() when initial != null:
return initial();case AuthLoading() when loading != null:
return loading();case AuthAuthenticated() when authenticated != null:
return authenticated(_that.user);case AuthGuest() when guest != null:
return guest();case AuthUnauthenticated() when unauthenticated != null:
return unauthenticated();case AuthPhoneVerification() when phoneVerificationRequired != null:
return phoneVerificationRequired(_that.phone);case AuthEmailConfirmationRequired() when emailConfirmationRequired != null:
return emailConfirmationRequired(_that.email);case AuthPendingVerification() when pendingVerification != null:
return pendingVerification();case AuthError() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  loading,required TResult Function( User user)  authenticated,required TResult Function()  guest,required TResult Function()  unauthenticated,required TResult Function( String phone)  phoneVerificationRequired,required TResult Function( String email)  emailConfirmationRequired,required TResult Function()  pendingVerification,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case AuthInitial():
return initial();case AuthLoading():
return loading();case AuthAuthenticated():
return authenticated(_that.user);case AuthGuest():
return guest();case AuthUnauthenticated():
return unauthenticated();case AuthPhoneVerification():
return phoneVerificationRequired(_that.phone);case AuthEmailConfirmationRequired():
return emailConfirmationRequired(_that.email);case AuthPendingVerification():
return pendingVerification();case AuthError():
return error(_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  loading,TResult? Function( User user)?  authenticated,TResult? Function()?  guest,TResult? Function()?  unauthenticated,TResult? Function( String phone)?  phoneVerificationRequired,TResult? Function( String email)?  emailConfirmationRequired,TResult? Function()?  pendingVerification,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case AuthInitial() when initial != null:
return initial();case AuthLoading() when loading != null:
return loading();case AuthAuthenticated() when authenticated != null:
return authenticated(_that.user);case AuthGuest() when guest != null:
return guest();case AuthUnauthenticated() when unauthenticated != null:
return unauthenticated();case AuthPhoneVerification() when phoneVerificationRequired != null:
return phoneVerificationRequired(_that.phone);case AuthEmailConfirmationRequired() when emailConfirmationRequired != null:
return emailConfirmationRequired(_that.email);case AuthPendingVerification() when pendingVerification != null:
return pendingVerification();case AuthError() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class AuthInitial implements AuthState {
  const AuthInitial();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AuthState.initial()';
}


}




/// @nodoc


class AuthLoading implements AuthState {
  const AuthLoading();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AuthState.loading()';
}


}




/// @nodoc


class AuthAuthenticated implements AuthState {
  const AuthAuthenticated({required this.user});
  

 final  User user;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthAuthenticatedCopyWith<AuthAuthenticated> get copyWith => _$AuthAuthenticatedCopyWithImpl<AuthAuthenticated>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthAuthenticated&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode {
    return Object.hash(runtimeType,user);
}

@override
String toString() {
    return 'AuthState.authenticated(user: $user)';
}


}

/// @nodoc
abstract mixin class $AuthAuthenticatedCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthAuthenticatedCopyWith(AuthAuthenticated value, $Res Function(AuthAuthenticated) _then) = _$AuthAuthenticatedCopyWithImpl;
@useResult
$Res call({
 User user
});


$UserCopyWith<$Res> get user;

}
/// @nodoc
class _$AuthAuthenticatedCopyWithImpl<$Res>
    implements $AuthAuthenticatedCopyWith<$Res> {
  _$AuthAuthenticatedCopyWithImpl(this._self, this._then);

  final AuthAuthenticated _self;
  final $Res Function(AuthAuthenticated) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? user = null,}) {
  return _then(AuthAuthenticated(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,
  ));
}

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

/// @nodoc


class AuthGuest implements AuthState {
  const AuthGuest();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthGuest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AuthState.guest()';
}


}




/// @nodoc


class AuthUnauthenticated implements AuthState {
  const AuthUnauthenticated();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthUnauthenticated);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AuthState.unauthenticated()';
}


}




/// @nodoc


class AuthPhoneVerification implements AuthState {
  const AuthPhoneVerification({required this.phone});
  

 final  String phone;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthPhoneVerificationCopyWith<AuthPhoneVerification> get copyWith => _$AuthPhoneVerificationCopyWithImpl<AuthPhoneVerification>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthPhoneVerification&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone);
}

@override
String toString() {
    return 'AuthState.phoneVerificationRequired(phone: $phone)';
}


}

/// @nodoc
abstract mixin class $AuthPhoneVerificationCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthPhoneVerificationCopyWith(AuthPhoneVerification value, $Res Function(AuthPhoneVerification) _then) = _$AuthPhoneVerificationCopyWithImpl;
@useResult
$Res call({
 String phone
});




}
/// @nodoc
class _$AuthPhoneVerificationCopyWithImpl<$Res>
    implements $AuthPhoneVerificationCopyWith<$Res> {
  _$AuthPhoneVerificationCopyWithImpl(this._self, this._then);

  final AuthPhoneVerification _self;
  final $Res Function(AuthPhoneVerification) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,}) {
  return _then(AuthPhoneVerification(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthEmailConfirmationRequired implements AuthState {
  const AuthEmailConfirmationRequired({required this.email});
  

 final  String email;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthEmailConfirmationRequiredCopyWith<AuthEmailConfirmationRequired> get copyWith => _$AuthEmailConfirmationRequiredCopyWithImpl<AuthEmailConfirmationRequired>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthEmailConfirmationRequired&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString() {
    return 'AuthState.emailConfirmationRequired(email: $email)';
}


}

/// @nodoc
abstract mixin class $AuthEmailConfirmationRequiredCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthEmailConfirmationRequiredCopyWith(AuthEmailConfirmationRequired value, $Res Function(AuthEmailConfirmationRequired) _then) = _$AuthEmailConfirmationRequiredCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$AuthEmailConfirmationRequiredCopyWithImpl<$Res>
    implements $AuthEmailConfirmationRequiredCopyWith<$Res> {
  _$AuthEmailConfirmationRequiredCopyWithImpl(this._self, this._then);

  final AuthEmailConfirmationRequired _self;
  final $Res Function(AuthEmailConfirmationRequired) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(AuthEmailConfirmationRequired(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AuthPendingVerification implements AuthState {
  const AuthPendingVerification();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthPendingVerification);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AuthState.pendingVerification()';
}


}




/// @nodoc


class AuthError implements AuthState {
  const AuthError({required this.message});
  

 final  String message;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthErrorCopyWith<AuthError> get copyWith => _$AuthErrorCopyWithImpl<AuthError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'AuthState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $AuthErrorCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory $AuthErrorCopyWith(AuthError value, $Res Function(AuthError) _then) = _$AuthErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$AuthErrorCopyWithImpl<$Res>
    implements $AuthErrorCopyWith<$Res> {
  _$AuthErrorCopyWithImpl(this._self, this._then);

  final AuthError _self;
  final $Res Function(AuthError) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(AuthError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
