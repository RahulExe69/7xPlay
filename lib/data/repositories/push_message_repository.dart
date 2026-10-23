import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';

class PushMessageRepository {
  const PushMessageRepository(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>?> fetch(String id, {String? owner}) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) return null;
    try {
      final response = await dio.get<dynamic>('push/messages/$id',
          options: Options(extra: {
            'authRequired': owner != null,
            if (owner != null) 'sessionOwner': owner,
            'cachePolicy': CachePolicy.noStore,
          }));
      final body = response.data;
      if (body is! Map || body['success'] != true || body['message'] is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(body['message'] as Map);
    } catch (_) {
      // Private content remains on the API; a stale or unauthorized tap is safe.
      return null;
    }
  }
}
