import 'dart:async';

import 'package:flixquest/screens/common/player/player_background_save.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures state immediately and finishes without holding the caller',
      () async {
    final diskWrite = Completer<void>();
    final finished = Completer<void>();
    var position = 42;
    int? savedPosition;
    var started = false;

    savePlayerDataInBackground(() async {
      started = true;
      final snapshot = position;
      await diskWrite.future;
      savedPosition = snapshot;
      finished.complete();
    }, operation: 'progress');

    expect(started, isTrue);
    expect(finished.isCompleted, isFalse);
    // Navigation may replace the current player before the disk write finishes.
    position = 0;
    diskWrite.complete();
    await finished.future;
    expect(savedPosition, 42);
  });

  for (final synchronous in [true, false]) {
    test('reports a ${synchronous ? 'synchronous' : 'future'} save failure',
        () async {
      final error = StateError('write failed');
      final failure = Completer<void>();
      final reported = Completer<void>();
      savePlayerDataInBackground(
        () {
          if (synchronous) throw error;
          return failure.future;
        },
        operation: 'progress',
        reportError: (value, stack, operation) {
          expect(value, same(error));
          expect(stack, isA<StackTrace>());
          expect(operation, 'progress');
          reported.complete();
        },
      );
      if (!synchronous) failure.completeError(error);
      await reported.future;
    });
  }

  test('a reporting failure does not become an unhandled save error', () async {
    var reported = false;
    savePlayerDataInBackground(
      () async => throw StateError('disk unavailable'),
      operation: 'progress',
      reportError: (error, stack, operation) async {
        reported = true;
        throw StateError('Crashlytics unavailable');
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(reported, isTrue);
  });
}
