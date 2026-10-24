import 'package:dio/dio.dart';

import '../../core/cache/cache_policy.dart';
import '../../core/network/interceptors/retry_interceptor.dart';
import '../models/flix_ai.dart';

class FlixAiError implements Exception {
  const FlixAiError(this.code, {this.usage, this.canRetry = false});
  final String code;
  final FlixAiUsage? usage;

  /// A transport failure may have reached the server. Retry with the same ID.
  final bool canRetry;
}

class FlixAiRepository {
  const FlixAiRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _request(String path,
      {String method = 'GET',
      Object? data,
      required String owner,
      CancelToken? cancelToken}) async {
    try {
      final response = await _dio.request<Object>('flix-ai/$path',
          data: data,
          cancelToken: cancelToken,
          options: Options(
              method: method,
              receiveTimeout: const Duration(seconds: 120),
              extra: {
                'authRequired': true,
                'syncOwner': owner,
                'cachePolicy': CachePolicy.noStore
              }));
      if (response.data is! Map<String, dynamic> ||
          (response.data as Map)['success'] != true) {
        throw const FlixAiError('invalid_response');
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (error) {
      final body = error.response?.data;
      final code = body is Map && body['code'] is String
          ? body['code'] as String
          : 'flix_ai_failed';
      FlixAiUsage? usage;
      try {
        if (body is Map && body['usage'] is Map) {
          usage = FlixAiUsage.fromJson(
              Map<String, dynamic>.from(body['usage'] as Map));
        }
      } catch (_) {/* The fallback still presents a safe error. */}
      throw FlixAiError(code,
          usage: usage,
          canRetry: isTransportFailure(error) ||
              code == 'flix_ai_busy' ||
              ((error.response?.statusCode ?? 0) >= 500 &&
                  (body is! Map || body['code'] is! String)));
    }
  }

  T _parse<T>(T Function() read) {
    try {
      return read();
    } catch (_) {
      throw const FlixAiError('invalid_response');
    }
  }

  Future<FlixAiAvailability> availability(String owner,
      {CancelToken? cancelToken}) async {
    final body =
        await _request('usage', owner: owner, cancelToken: cancelToken);
    return _parse(() => FlixAiAvailability(body['enabled'] == true,
        FlixAiUsage.fromJson(Map<String, dynamic>.from(body['usage'] as Map))));
  }

  Future<List<FlixAiConversation>> conversations(String owner,
      {CancelToken? cancelToken}) async {
    final body =
        await _request('conversations', owner: owner, cancelToken: cancelToken);
    return _parse(() => [
          for (final entry in body['conversations'] as List)
            FlixAiConversation.fromJson(Map<String, dynamic>.from(entry as Map))
        ]);
  }

  Future<List<FlixAiTurn>> history(String id, String owner,
      {CancelToken? cancelToken}) async {
    final body = await _request('conversations/${Uri.encodeComponent(id)}',
        owner: owner, cancelToken: cancelToken);
    return _parse(() => [
          for (final entry in body['turns'] as List)
            FlixAiTurn.fromJson(Map<String, dynamic>.from(entry as Map))
        ]);
  }

  Future<FlixAiReply> send(
      {required String message,
      required String requestId,
      required String owner,
      required String language,
      String? conversationId,
      CancelToken? cancelToken}) async {
    final body = await _request('messages',
        method: 'POST',
        owner: owner,
        cancelToken: cancelToken,
        data: {
          'message': message,
          'request_id': requestId,
          'language': language,
          if (conversationId != null) 'conversation_id': conversationId
        });
    return _parse(() => FlixAiReply(
        FlixAiTurn.fromJson(Map<String, dynamic>.from(body['turn'] as Map)),
        FlixAiUsage.fromJson(Map<String, dynamic>.from(body['usage'] as Map))));
  }

  Future<void> delete(String id, String owner,
      {CancelToken? cancelToken}) async {
    await _request('conversations/${Uri.encodeComponent(id)}',
        method: 'DELETE', owner: owner, cancelToken: cancelToken);
  }
}
