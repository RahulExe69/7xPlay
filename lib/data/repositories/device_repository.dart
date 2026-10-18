import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/network/interceptors/error_interceptor.dart';

class DeviceRepository {
  const DeviceRepository(this.dio);
  final Dio dio;

  Future<Result<void>> register(
      String fcmToken, String platform, String appVersion,
      {required String owner, String provider = 'fcm'}) async {
    try {
      final response = await dio.post<dynamic>(
          provider == 'onesignal' ? 'push/subscriptions' : 'devices/register',
          data: {
            if (provider == 'onesignal')
              'subscription_id': fcmToken
            else
              'fcm_token': fcmToken,
            'platform': platform,
            'app_version': appVersion
          },
          options: Options(extra: {
            'sessionOwner': owner,
            'cachePolicy': CachePolicy.noStore,
          }));
      if (response.data is! Map || response.data['success'] != true) {
        return const Result.err(
            Failure.unknown(message: 'Invalid device registration response.'));
      }
      return const Result.ok(null);
    } on DioException catch (error) {
      return Result.err(failureForDio(error));
    }
  }

  Future<void> unregister(String subscriptionId,
      {required String owner}) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(subscriptionId)) return;
    try {
      await dio.delete<dynamic>('push/subscriptions/$subscriptionId',
          options: Options(extra: {
            'sessionOwner': owner,
            'cachePolicy': CachePolicy.noStore
          }));
    } catch (_) {/* The token association is also removed on server logout. */}
  }
}
