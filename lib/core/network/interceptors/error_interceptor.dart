import 'package:dio/dio.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/json/json_reader.dart';
import 'package:flixquest/data/models/signed_in_device.dart';
import 'package:flixquest/data/models/api_error.dart';
import 'retry_interceptor.dart';

/// Laravel (and TMDB) answer every outcome with a `success` envelope. A 401 or
/// 403 without one comes from the edge (a Cloudflare challenge, Caddy), not
/// from an account decision, so it must never end a session.
bool isApiEnvelope(Object? data) => data is Map && data['success'] is bool;

Failure failureForDio(DioException error) {
  if (error.error is Failure) return error.error as Failure;
  final status = error.response?.statusCode;
  final data = error.response?.data;
  final api = ApiError.fromJson(data is Map<String, dynamic> ? data : {});
  if ([
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout
  ].contains(error.type)) {
    return const Failure.timeout();
  }
  if (isTransportFailure(error)) return const Failure.network();
  if (api.code == 'clock_skew_detected' && api.clockSkew != null) {
    return Failure.clockSkew(
        serverTimeUtc: api.clockSkew!.serverTimeUtc,
        driftMs: api.clockSkew!.maxDriftMs,
        message: api.message);
  }
  if (status == 409 && api.code == 'device_limit_reached') {
    final devices = data is Map ? JsonReader.asList(data['devices']) : null;
    return Failure.deviceLimit(
        limit: JsonReader.asInt(data is Map ? data['limit'] : null) ?? 0,
        devices: [
          for (final device in devices ?? const <dynamic>[])
            if (JsonReader.asMap(device) case final Map<String, dynamic> json)
              SignedInDevice.fromJson(json),
        ],
        message: api.message);
  }
  return switch (status) {
    final int code when (code == 401 || code == 403) && !isApiEnvelope(data) =>
      Failure.server(status: code, message: api.message),
    401 => Failure.unauthorized(message: api.message),
    403 => Failure.forbidden(message: api.message),
    404 => Failure.notFound(message: api.message),
    409 => Failure.conflict(message: api.message),
    422 => Failure.validation(api.errors, message: api.message),
    429 => Failure.rateLimited(
        retryAfter: api.retryAfter ??
            int.tryParse(error.response?.headers.value('retry-after') ?? ''),
        message: api.message),
    final int code when code >= 500 =>
      Failure.server(status: code, message: api.message),
    _ => Failure.unknown(message: api.message),
  };
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) =>
      handler.next(err.copyWith(error: failureForDio(err)));
}
