import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:delwaqty/domain/entities/user.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated({required User user}) =
      AuthAuthenticated;
  const factory AuthState.guest() = AuthGuest;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.phoneVerificationRequired({required String phone}) =
      AuthPhoneVerification;
  const factory AuthState.emailConfirmationRequired({required String email}) =
      AuthEmailConfirmationRequired;
  const factory AuthState.pendingVerification() = AuthPendingVerification;
  const factory AuthState.error({required String message}) = AuthError;
}
