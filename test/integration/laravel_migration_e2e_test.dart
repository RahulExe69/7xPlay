import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/data/models/auth_session.dart';
import 'package:flixquest/data/repositories/auth_repository.dart';
import 'package:flixquest/data/repositories/bookmark_repository.dart';
import 'package:flixquest/data/repositories/device_repository.dart';
import 'package:flixquest/data/repositories/recently_watched_repository.dart';
import 'package:flixquest/data/repositories/wellness_repository.dart';
import 'package:flixquest/data/sources/laravel_api.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fakes.dart';

/// Opt-in rehearsal: creates synthetic accounts and deletes only those accounts.
/// Use an isolated local backend or disposable staging database, never production.
void main() {
  const base = String.fromEnvironment('FLIXQUEST_E2E_API_URL');
  const allowWrites = bool.fromEnvironment('FLIXQUEST_E2E_ALLOW_WRITES');
  test(
      'real Laravel contract: two devices, skew recovery, pagination and account lifecycle',
      () async {
    final uri = Uri.parse(base);
    expect(['http', 'https'], contains(uri.scheme));
    expect(uri.path.endsWith('/api/v1/'), isTrue);
    Dio client([String? token]) => Dio(BaseOptions(
        baseUrl: base,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 30)))
      ..httpClientAdapter =
          IOHttpClientAdapter(createHttpClient: () => HttpClient());
    final anonymous = client();
    final auth = AuthRepository(LaravelApi(anonymous));
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final email = 'f8_$suffix@example.test';
    const password = 'F8-rehearsal-only-Password42!';
    final registration = await auth.signUp(RegisterRequest(
        name: 'F8 rehearsal',
        email: email,
        username: 'f8_$suffix',
        password: password));
    expect(registration, isA<Ok<AuthSession>>(),
        reason: 'Synthetic registration must return the real app contract.');
    final account = (registration as Ok<AuthSession>).value;
    final phone = client(account.token);
    addTearDown(() async {
      await AuthRepository(LaravelApi(phone)).deleteAccount();
      phone.close(force: true);
      anonymous.close(force: true);
    });
    final televisionAuth =
        await auth.signIn(LoginRequest(email: email, password: password));
    expect(televisionAuth, isA<Ok<AuthSession>>());
    final television = client((televisionAuth as Ok<AuthSession>).value.token);
    final phoneAuth = AuthRepository(LaravelApi(phone));
    addTearDown(() async {
      await AuthRepository(LaravelApi(television)).deleteAccount();
      television.close(force: true);
    });
    final owner = 'user:${account.user.id}';
    final phoneStore = FakeKvStore();
    final tvStore = FakeKvStore();
    final phoneBookmarks = BookmarkRepository(phone, phoneStore);
    final tvBookmarks = BookmarkRepository(television, tvStore);
    await phoneBookmarks
        .sync(owner, [Movie(id: 101, title: 'Phone bookmark')], []);
    final union = await tvBookmarks
        .sync(owner, [Movie(id: 102, title: 'TV bookmark')], []);
    expect(union.movies.map((m) => m.id).toSet(), {101, 102});
    expect(
        (await phoneBookmarks.sync(owner, [Movie(id: 101)], []))
            .movies
            .map((m) => m.id)
            .toSet(),
        {101, 102});

    final clock = ServerClock(phoneStore);
    final recent = RecentlyWatchedRepository(phone, phoneStore, clock);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await recent.sync(owner, movies: [
      {
        'movie_id': 101,
        'elapsed': 20,
        'remaining': 80,
        'updated_at_utc': now - 2000
      }
    ]);
    final tvRecent =
        RecentlyWatchedRepository(television, tvStore, ServerClock(tvStore));
    final latest = await tvRecent.sync(owner, movies: [
      {
        'movie_id': 101,
        'elapsed': 60,
        'remaining': 40,
        'updated_at_utc': now - 1000
      }
    ]);
    expect((latest.data['movies'] as List).single['elapsed'], 60);
    final stale = await recent.sync(owner, movies: [
      {
        'movie_id': 101,
        'elapsed': 10,
        'remaining': 90,
        'updated_at_utc': now - 3000
      }
    ]);
    expect((stale.data['movies'] as List).single['elapsed'], 60);

    final skewClock = ServerClock(FakeKvStore(),
        now: () => DateTime.now().toUtc().add(const Duration(hours: 25)));
    final statuses = <int?>[];
    phone.interceptors.add(InterceptorsWrapper(onError: (error, handler) {
      statuses.add(error.response?.statusCode);
      handler.next(error);
    }));
    final recovered =
        await RecentlyWatchedRepository(phone, FakeKvStore(), skewClock)
            .sync(owner);
    expect(statuses, contains(422));
    expect(skewClock.offsetMs,
        lessThan(-const Duration(hours: 24).inMilliseconds));
    expect(recovered.data['success'], isTrue);

    final sessions = List.generate(
        451,
        (i) => <String, dynamic>{
              'id': 'f8-$suffix-$i',
              'device_id': 'f8-phone',
              'media_type': 'movie',
              'playback_source': 'stream',
              'content_id': '101',
              'title': 'Rehearsal session',
              'started_at_utc': now - 60000,
              'ended_at_utc': now - 1000,
              'timezone_offset_minutes': 0,
              'watched_ms': 1000,
              'duration_ms': 100000,
              'progress_end_ms': 1000,
              'updated_at_utc': now - 1000,
            });
    final wellness = await WellnessRepository(phone, phoneStore, clock)
        .sync(owner, sessions: sessions);
    expect(wellness.sessions.length, 451);
    await wellness.save();
    final tvWellness =
        await WellnessRepository(television, tvStore, ServerClock(tvStore))
            .sync(owner);
    expect(tvWellness.sessions.length, 451);

    final bootstrap = await anonymous.get<dynamic>('config/bootstrap');
    expect(bootstrap.data['success'], isTrue);
    expect(bootstrap.headers.value('etag'), isNotEmpty);
    final unchanged = await anonymous.get<dynamic>('config/bootstrap',
        options: Options(
            headers: {'If-None-Match': bootstrap.headers.value('etag')},
            validateStatus: (status) => status == 304));
    expect(unchanged.statusCode, 304);
    final ads = await anonymous.get<dynamic>('ads');
    final sameAds = await anonymous.get<dynamic>('ads',
        options: Options(
            headers: {'If-None-Match': ads.headers.value('etag')},
            validateStatus: (status) => status == 304));
    expect(sameAds.statusCode, 304);

    final device = DeviceRepository(phone);
    expect(
        await device.register(
            '11111111-1111-4111-8111-111111111111', 'android', 'f8',
            owner: owner, provider: 'onesignal'),
        isA<Ok<void>>());
    expect(await phoneAuth.signOut(), isA<Ok<void>>());
    expect(await phoneAuth.profile(), isA<Err>());
    expect(await AuthRepository(LaravelApi(television)).profile(), isA<Ok>());
    expect(await AuthRepository(LaravelApi(television)).deleteAccount(),
        isA<Ok<void>>());
    expect(await AuthRepository(LaravelApi(television)).profile(), isA<Err>());
  },
      skip: base.isEmpty || !allowWrites
          ? 'Set FLIXQUEST_E2E_API_URL and FLIXQUEST_E2E_ALLOW_WRITES=true for disposable staging.'
          : false,
      timeout: const Timeout(Duration(minutes: 3)));
}
