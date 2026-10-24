import 'package:dio/dio.dart';
import 'package:flixquest/presentation/session/session_view_model.dart';
import 'error_interceptor.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.session, String apiUrl) : _api = Uri.parse(apiUrl);
  final SessionViewModel session;
  final Uri _api;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    final allowed = uri.origin == _api.origin && uri.path.startsWith(_api.path);
    options.extra.remove('sessionToken');
    // Device requests belong to the account (guests included); sync requests
    // belong to the signed-in owner whose library they carry.
    final sessionOwner = options.extra['sessionOwner'];
    final syncOwner = options.extra['syncOwner'];
    if ((sessionOwner != null && sessionOwner != session.accountId.value) ||
        (syncOwner != null && syncOwner != session.ownerId.value)) {
      handler.reject(DioException(requestOptions: options,
          type: DioExceptionType.cancel, message: 'Sync account changed.'));
      return;
    }
    if (allowed &&
        options.extra['authRequired'] != false &&
        session.token != null) {
      final token = session.token!;
      options.headers['Authorization'] = 'Bearer $token';
      options.extra['sessionToken'] = token;
      if (session.ownerId.value != null) {
        options.extra['authScope'] = session.ownerId.value;
      }
    } else {
      options.headers
          .removeWhere((key, _) => key.toLowerCase() == 'authorization');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final rejected = err.requestOptions.extra['sessionToken'];
    if (err.response?.statusCode == 401 &&
        isApiEnvelope(err.response?.data) &&
        rejected is String) {
      try {
        await session.expire(rejected);
      } catch (_) {/* Gate is already expired. */}
    }
    handler.next(err);
  }
}
