import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

@freezed
sealed class Failure with _$Failure {
  const factory Failure.server({required String message}) = ServerFailure;
  const factory Failure.cache({required String message}) = CacheFailure;
  const factory Failure.network({required String message}) = NetworkFailure;
  const factory Failure.auth({required String message}) = AuthFailure;
  const factory Failure.unexpected({required String message}) =
      UnexpectedFailure;
  const factory Failure.notFound({required String message}) = NotFoundFailure;
  const factory Failure.validation({required String message}) =
      ValidationFailure;
}
