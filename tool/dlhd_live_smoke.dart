// Runs real network requests using the app's production resolver.
// Usage: dart run tool/dlhd_live_smoke.dart <scraper-base-url> [channel-id]
import 'dart:convert';
import 'dart:io';

import 'package:flixquest/services/daddylive_service.dart';
import 'package:http/http.dart' as http;

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.origin);

  final String origin;
  final http.Client _upstream = http.Client();
  bool requestedServerStream = false;
  bool requestedBackup = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.startsWith('/backup-')) requestedBackup = true;
    final mockSlug = Platform.environment['DLHD_SMOKE_MOCK_SLUG'];
    if (mockSlug != null && request.url.origin == origin) {
      request.headers['x-mock-slug'] = mockSlug;
    }
    if (request.url.path.endsWith('/stream')) {
      requestedServerStream = true;
      stdout
          .writeln('Local watch-page resolution failed; using embed fallback');
    }
    final timer = Stopwatch()..start();
    final response = await _upstream.send(request);
    if (Platform.environment['DLHD_SMOKE_TRACE'] == '1') {
      stdout.writeln('HTTP ${response.statusCode} '
          '${request.url.host}${request.url.path} '
          '(${timer.elapsedMilliseconds}ms)');
    }
    return response;
  }

  @override
  void close() => _upstream.close();
}

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/dlhd_live_smoke.dart <scraper-base-url> [channel-id]',
    );
    exitCode = 64;
    return;
  }
  final channel = args.length == 2 ? args[1] : '51';
  final recording = _RecordingClient(Uri.parse(args[0]).origin);
  final service = DaddyLiveService(baseUrl: args[0], client: recording);
  final client = http.Client();
  try {
    final channels = await service.getChannels(refresh: true);
    if (!channels.any((item) => item.id == channel)) {
      stdout.writeln(
          'Channel $channel is not in the catalog; using its watch page');
    }
    final timer = Stopwatch()..start();
    final stream = await service.getStream(channel);
    stdout.writeln(
      'Channel $channel resolved by DaddyLiveService in '
      '${timer.elapsed.inMilliseconds}ms; ${stream.variants.length} playable '
      'stream(s); metadata fallback=${recording.requestedServerStream}',
    );
    if (stream.variants.isEmpty || stream.embedUrl.isEmpty) {
      throw StateError('The device did not resolve a local stream');
    }
    if (Platform.environment['DLHD_SMOKE_MOCK_SLUG'] != null &&
        (stream.variants.length != 1 || recording.requestedBackup)) {
      throw StateError('Backup resolution started before content playback');
    }
    for (final variant in stream.variants) {
      stdout.writeln('${variant.title}: ${Uri.parse(variant.url).host}');
    }

    var playlistUri = Uri.parse(stream.url);
    List<String> entries = const [];
    for (var depth = 0; depth < 4; depth++) {
      final response = await client
          .get(playlistUri, headers: stream.headers)
          .timeout(const Duration(seconds: 40));
      final body = utf8.decode(response.bodyBytes);
      stdout.writeln('Device playlist: HTTP ${response.statusCode}');
      if (response.statusCode != 200 ||
          !body.trimLeft().startsWith('#EXTM3U')) {
        throw StateError('Device URL did not return an HLS playlist');
      }
      final entriesInPlaylist = const LineSplitter()
          .convert(body)
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .toList();
      if (entriesInPlaylist.isEmpty) throw StateError('Empty HLS playlist');
      if (body.contains('#EXT-X-STREAM-INF:')) {
        playlistUri = playlistUri.resolve(entriesInPlaylist.first);
        continue;
      }
      entries = entriesInPlaylist;
      break;
    }
    if (entries.length < 3) throw StateError('Fewer than three media segments');
    for (var index = 0; index < 3; index++) {
      final response = await client
          .get(playlistUri.resolve(entries[index]), headers: stream.headers)
          .timeout(const Duration(seconds: 40));
      final bytes = response.bodyBytes;
      // Current DLHD channels use unencrypted MPEG-TS segments.
      final validTs = bytes.length > 376 &&
          bytes[0] == 0x47 &&
          bytes[188] == 0x47 &&
          bytes[376] == 0x47;
      stdout.writeln(
        'Segment ${index + 1}: HTTP ${response.statusCode}, '
        '${bytes.length} bytes, MPEG-TS=$validTs',
      );
      if (response.statusCode != 200 || !validTs) {
        throw StateError('Invalid MPEG-TS media segment');
      }
    }
    final discovery = stream.discovery;
    if (discovery != null &&
        Platform.environment['DLHD_SMOKE_MOCK_SLUG'] != null) {
      final backups =
          discovery.updates.firstWhere((items) => items.length >= 3);
      // Stand in for the shared mobile/TV player's first content progress
      // event only after transport has delivered the three media segments.
      discovery.observePlayback(
        position: const Duration(seconds: 1),
        isPlaying: true,
        isBuffering: false,
        isAd: false,
      );
      final variants = await backups.timeout(const Duration(seconds: 10));
      stdout.writeln('Deferred backups: '
          '${variants.map((variant) => variant.title).join(', ')}');
    }
    stdout.writeln('PASS: Player 1 first, device playlist and 3 segments, '
        'then deferred backup discovery');
  } catch (error) {
    stderr.writeln('FAIL: $error');
    exitCode = 1;
  } finally {
    service.close();
    client.close();
  }
}
