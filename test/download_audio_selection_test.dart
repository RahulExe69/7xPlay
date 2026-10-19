import 'dart:async';

import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/screens/common/download_selection_sheets.dart';
import 'package:flixquest/services/offline_download_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const english = OfflineAudioTrack(
  name: 'English',
  selection: {'groupId': 'audio-en', 'formatId': 'en', 'language': 'en'},
);
const hindi = OfflineAudioTrack(
  name: 'Hindi',
  selection: {'groupId': 'audio-hi', 'formatId': 'hi', 'language': 'hi'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('changing audio on an existing download explains how to replace it', () {
    expect(
      offlineEnqueueErrorMessage(
        PlatformException(code: 'DOWNLOAD_AUDIO_CONFLICT'),
        title: 'Movie',
      ),
      'Remove the existing download in Downloads, then choose the new audio language.',
    );
  });

  test(
      'native inspection and enqueue preserve track identity and source headers',
      () async {
    const channel = MethodChannel('dev.beamlak.flixquest/stream_downloads');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getAudioTracks') {
        return [
          {'name': 'English', 'selection': english.selection},
          {'name': 'Hindi', 'selection': hindi.selection},
        ];
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final tracks = await OfflineDownloadService.instance.getAudioTracks(
      url: 'https://example.test/signed/master',
      format: 'hls',
      headers: const {'Referer': 'https://provider.test/'},
      maxVideoHeight: 720,
    );
    expect(tracks.map((track) => track.name), ['English', 'Hindi']);
    expect(calls.single.arguments['maxVideoHeight'], 720);
    expect(calls.single.arguments['headers'],
        {'Referer': 'https://provider.test/'});
    await OfflineDownloadService.instance.enqueue(OfflineDownloadRequest(
      id: 'movie_1',
      url: 'https://example.test/signed/master',
      format: 'hls',
      title: 'Movie',
      mediaType: 'movie',
      quality: '720p',
      audioTrack: tracks.last,
    ));
    expect(calls.last.method, 'enqueue');
    expect(calls.last.arguments['audioTrack'], hindi.selection);
    expect(calls.last.arguments['audioTrackName'], 'Hindi');
  });

  for (final inPlayer in [false, true]) {
    testWidgets('multiple tracks require a choice (inPlayer: $inPlayer)',
        (tester) async {
      DownloadAudioSelection? selection;
      var finished = false;
      final tracks = Completer<List<OfflineAudioTrack>>();
      await _pumpPicker(tester, tracks.future, (result) {
        finished = true;
        selection = result;
      }, inPlayer: inPlayer);
      expect(find.text('download_audio_loading'), findsOneWidget);
      tracks.complete([english, hindi]);
      await tester.pumpAndSettle();
      expect(find.text('download_choose_audio'), findsOneWidget);
      expect(finished, isFalse);
      await tester.tap(find.text('Hindi'));
      await tester.pumpAndSettle();
      expect(selection?.track?.selection, hindi.selection);
    });
  }

  for (final tracks in <List<OfflineAudioTrack>>[
    [],
    [hindi]
  ]) {
    testWidgets('${tracks.length} audio tracks skip the choice',
        (tester) async {
      DownloadAudioSelection? selection;
      final completer = Completer<List<OfflineAudioTrack>>();
      await _pumpPicker(
          tester, completer.future, (result) => selection = result);
      completer.complete(tracks);
      await tester.pumpAndSettle();
      expect(find.text('download_choose_audio'), findsNothing);
      expect(selection, isNotNull);
      expect(selection?.track, tracks.isEmpty ? isNull : same(hindi));
    });
  }

  testWidgets('cancelling inspection prevents a late audio choice',
      (tester) async {
    var finished = false;
    DownloadAudioSelection? selection;
    final completer = Completer<List<OfflineAudioTrack>>();
    await _pumpPicker(tester, completer.future, (result) {
      finished = true;
      selection = result;
    });
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(selection, isNull);
    completer.complete([english, hindi]);
    await tester.pumpAndSettle();
    expect(find.text('download_choose_audio'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspection failure does not accept a default audio track',
      (tester) async {
    var finished = false;
    DownloadAudioSelection? selection;
    final completer = Completer<List<OfflineAudioTrack>>();
    await _pumpPicker(tester, completer.future, (result) {
      finished = true;
      selection = result;
    });
    completer.completeError(PlatformException(code: 'PREPARE_FAILED'));
    await tester.pumpAndSettle();
    expect(find.text('download_audio_error'), findsOneWidget);
    expect(finished, isFalse);
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(selection, isNull);
  });
}

Future<void> _pumpPicker(
  WidgetTester tester,
  Future<List<OfflineAudioTrack>> tracks,
  ValueChanged<DownloadAudioSelection?> onSelected, {
  bool inPlayer = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      return Scaffold(
        body: TextButton(
          onPressed: () async => onSelected(
            await DownloadSelectionSheets.chooseAudio(context,
                tracks: tracks, inPlayer: inPlayer),
          ),
          child: const Text('Download'),
        ),
      );
    }),
  ));
  await tester.tap(find.text('Download'));
  // Inspection shows an animated progress bar until the native result arrives.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
