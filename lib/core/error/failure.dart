import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/models/signed_in_device.dart';

part 'failure.freezed.dart';
part 'failure.g.dart';

@freezed
sealed class Failure with _$Failure {
  const factory Failure.network({String? message}) = NetworkFailure;
  const factory Failure.timeout({String? message}) = TimeoutFailure;
  const factory Failure.unauthorized({String? message}) = UnauthorizedFailure;
  const factory Failure.forbidden({String? message}) = ForbiddenFailure;
  const factory Failure.notFound({String? message}) = NotFoundFailure;
  const factory Failure.conflict({String? message}) = ConflictFailure;
  const factory Failure.validation(
    Map<String, List<String>> fields, {
    String? message,
  }) = ValidationFailure;
  const factory Failure.rateLimited({int? retryAfter, String? message}) =
      RateLimitedFailure;
  const factory Failure.server({required int status, String? message}) =
      ServerFailure;
  const factory Failure.clockSkew({
    required int serverTimeUtc,
    required int driftMs,
    String? message,
  }) = ClockSkewFailure;
  /// The account is signed in on as many devices as its plan allows; signing
  /// in again with one of [devices] to replace succeeds.
  const factory Failure.deviceLimit({
    required int limit,
    required List<SignedInDevice> devices,
    String? message,
  }) = DeviceLimitFailure;
  const factory Failure.cache({String? message}) = CacheFailure;
  const factory Failure.unknown({String? message}) = UnknownFailure;

  factory Failure.fromJson(Map<String, dynamic> json) =>
      _$FailureFromJson(json);
}
