import 'dart:async';

import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/provider/offline_download_provider.dart';
import 'package:flixquest/screens/common/downloads_screen.dart';
import 'package:flixquest/services/offline_download_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

OfflineDownload _item(
  String id, {
  required int createdAt,
  required OfflineDownloadState state,
  double progress = 0,
}) =>
    OfflineDownload(
      id: id,
      title: id,
      mediaType: 'movie',
      quality: '720p',
      state: state,
      progress: progress,
      bytesDownloaded: 0,
      contentLength: -1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );

class _Gateway implements OfflineDownloadGateway {
  _Gateway(this.items);

  final List<OfflineDownload> items;
  final _events = StreamController<List<OfflineDownload>>.broadcast();

  @override
  Stream<List<OfflineDownload>> get downloadEvents => _events.stream;

  @override
  Future<List<OfflineDownload>> getDownloads() async => items;

  @override
  Future<void> enqueue(OfflineDownloadRequest request) async {}

  @override
  Future<void> pause(String id) async {}

  @override
  Future<void> resume(String id) async {}

  @override
  Future<void> retry(String id) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<OfflineExportProgress> getExportProgress(String id) async =>
      const OfflineExportProgress(state: 'idle');

  @override
  Future<void> openExternal(String id) async {}

  @override
  Future<bool> saveCopy(String id) async => true;
}

Future<OfflineDownloadProvider> _pump(
  WidgetTester tester,
  List<OfflineDownload> items,
) async {
  final provider = OfflineDownloadProvider(service: _Gateway(items));
  await provider.initialize();
  await tester.pumpWidget(
    ChangeNotifierProvider<OfflineDownloadProvider>.value(
      value: provider,
      child: const MaterialApp(home: DownloadsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  testWidgets('groups downloads by active, ready and attention states',
      (tester) async {
    final provider = await _pump(tester, <OfflineDownload>[
      _item(
        'Ready movie',
        createdAt: 1,
        state: OfflineDownloadState.completed,
        progress: 100,
      ),
      _item(
        'Failed movie',
        createdAt: 4,
        state: OfflineDownloadState.failed,
      ),
      _item(
        'Active movie',
        createdAt: 3,
        state: OfflineDownloadState.downloading,
        progress: 42,
      ),
      _item(
        'Paused movie',
        createdAt: 2,
        state: OfflineDownloadState.stopped,
      ),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('offline_library'), findsOneWidget);
    expect(find.text('Active movie'), findsOneWidget);
    expect(find.text('Ready movie'), findsOneWidget);
    expect(find.text('Failed movie'), findsOneWidget);
    expect(find.text('Paused movie'), findsOneWidget);

    final activeHeader = tester.getTopLeft(
      find.text('downloads_in_progress').last,
    );
    final readyHeader = tester.getTopLeft(find.text('downloads_ready').last);
    final attentionHeader = tester.getTopLeft(
      find.text('downloads_attention').last,
    );
    expect(activeHeader.dy, lessThan(readyHeader.dy));
    expect(readyHeader.dy, lessThan(attentionHeader.dy));

    final activeName = tester.getTopLeft(find.text('Active movie'));
    final readyName = tester.getTopLeft(find.text('Ready movie'));
    final failedName = tester.getTopLeft(find.text('Failed movie'));
    final pausedName = tester.getTopLeft(find.text('Paused movie'));
    expect(activeName.dy, greaterThan(activeHeader.dy));
    expect(readyName.dy, greaterThan(readyHeader.dy));
    expect(failedName.dy, greaterThan(attentionHeader.dy));
    expect(pausedName.dy, greaterThan(attentionHeader.dy));
    provider.dispose();
  });

  testWidgets('shows all three zero metrics and retains empty state',
      (tester) async {
    final provider = await _pump(tester, const <OfflineDownload>[]);

    expect(find.text('no_downloads_yet'), findsOneWidget);
    expect(find.text('offline_library'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    provider.dispose();
  });
}
