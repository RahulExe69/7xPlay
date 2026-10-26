import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/data/repositories/flix_ai_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_dio.dart';

Map<String, dynamic> flixAiUsageJson({int remaining = 4}) => {
      'plan': 'free',
      'limit': 5,
      'used': 5 - remaining,
      'remaining': remaining,
      'resets_at': '2026-10-25T00:00:00.000000Z',
    };

Map<String, dynamic> flixAiTurnJson({String type = 'movie'}) => {
      'id': 'turn-1',
      'conversation_id': 'chat-1',
      'request_id': 'request-1',
      'status': 'completed',
      'message': 'Something like Love Actually',
      'reply': 'Warm romantic comedies.',
      'needs_clarification': false,
      'broadened': false,
      'keywords': [
        {'id': 9673, 'name': 'romantic comedy'}
      ],
      'recommendations': [
        {
          'id': 1581,
          'media_type': type,
          'title': 'The Holiday',
          'name': 'The Holiday',
          'overview': 'Two women exchange homes.',
          'poster_path': null,
          'backdrop_path': null,
          'genre_ids': [35, 10749],
          'vote_average': 7.1,
          'release_date': '2006-12-08',
          'first_air_date': '2006-12-08',
        }
      ],
    };

void main() {
  late Dio dio;
  late FakeDioAdapter adapter;
  late FlixAiRepository repository;
  setUp(() {
    adapter = FakeDioAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    repository = FlixAiRepository(dio);
  });
  tearDown(() => dio.close(force: true));

  test(
      'parses real movie and TV cards and uses authenticated uncached requests',
      () async {
    for (final type in ['movie', 'tv']) {
      adapter.enqueueJson({
        'success': true,
        'turn': flixAiTurnJson(type: type),
        'usage': flixAiUsageJson()
      });
      final reply = await repository.send(
          message: 'Something like Love Actually',
          requestId: 'stable-request',
          owner: 'user:1',
          language: 'en');
      expect(reply.turn.recommendations.single.id, 1581);
      expect(reply.turn.recommendations.single.title, 'The Holiday');
      expect(reply.turn.recommendations.single.kind.name,
          type == 'movie' ? 'movie' : 'series');
      expect(reply.usage.remaining, 4);
    }
    final request = adapter.requests.first;
    expect(request.path, 'flix-ai/messages');
    expect(request.data['request_id'], 'stable-request');
    expect(request.extra['syncOwner'], 'user:1');
    expect(request.extra['authRequired'], true);
    expect(request.extra['cachePolicy'], CachePolicy.noStore);
    expect(request.receiveTimeout, const Duration(seconds: 120));
  });

  test('quota errors preserve the server allowance', () async {
    adapter.enqueueJson({
      'success': false,
      'code': 'flix_ai_limit_reached',
      'usage': flixAiUsageJson(remaining: 0)
    }, statusCode: 429);
    await expectLater(
        repository.send(
            message: 'Romance',
            requestId: 'request',
            owner: 'user:1',
            language: 'en'),
        throwsA(isA<FlixAiError>()
            .having((e) => e.code, 'code', 'flix_ai_limit_reached')
            .having((e) => e.usage?.remaining, 'remaining', 0)
            .having((e) => e.canRetry, 'retry', false)));
  });

  test(
      'transport failures and busy replies allow the same request to be retried',
      () async {
    adapter.enqueueError(type: DioExceptionType.receiveTimeout);
    await expectLater(
        repository.send(
            message: 'Romance',
            requestId: 'request',
            owner: 'user:1',
            language: 'en'),
        throwsA(isA<FlixAiError>().having((e) => e.canRetry, 'retry', true)));
    adapter.enqueueJson({'success': false, 'code': 'flix_ai_busy'},
        statusCode: 409);
    await expectLater(
        repository.send(
            message: 'Romance',
            requestId: 'request',
            owner: 'user:1',
            language: 'en'),
        throwsA(isA<FlixAiError>().having((e) => e.canRetry, 'retry', true)));
  });

  test('malformed payloads and unknown recommendation types fail safely',
      () async {
    adapter.enqueueJson({
      'success': true,
      'turn': flixAiTurnJson(type: 'person'),
      'usage': flixAiUsageJson()
    });
    await expectLater(
        repository.send(
            message: 'Romance',
            requestId: 'request',
            owner: 'user:1',
            language: 'en'),
        throwsA(isA<FlixAiError>()
            .having((e) => e.code, 'code', 'invalid_response')));
  });
}
