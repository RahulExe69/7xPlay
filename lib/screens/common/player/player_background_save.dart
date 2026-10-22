import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

typedef PlayerSaveErrorReporter = FutureOr<void> Function(
    Object error, StackTrace stackTrace, String operation);

/// Starts immediately so [save] can capture the outgoing player's state before
/// navigation. Its writes finish independently of the route's lifetime.
void savePlayerDataInBackground(
  Future<void> Function() save, {
  required String operation,
  PlayerSaveErrorReporter? reportError,
}) {
  unawaited(_finishSave(
    Future<void>.sync(save),
    operation,
    reportError ?? _reportSaveError,
  ));
}

Future<void> _finishSave(Future<void> save, String operation,
    PlayerSaveErrorReporter reportError) async {
  try {
    await save;
  } catch (error, stackTrace) {
    try {
      await reportError(error, stackTrace, operation);
    } catch (reportingError) {
      debugPrint(
          '[Player] Could not report $operation failure: $reportingError');
    }
  }
}

Future<void> _reportSaveError(
    Object error, StackTrace stackTrace, String operation) async {
  debugPrint('[Player] Failed to save $operation: $error');
  debugPrintStack(stackTrace: stackTrace);
  await FirebaseCrashlytics.instance.recordError(
    error,
    stackTrace,
    reason: 'Saving $operation in the background',
    fatal: false,
  );
}
