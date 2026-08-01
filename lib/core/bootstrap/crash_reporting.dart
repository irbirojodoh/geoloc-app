import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

/// Wires [FlutterError.onError] and [PlatformDispatcher.instance.onError]
/// to Firebase Crashlytics when available.
Future<void> initCrashReporting({required bool firebaseReady}) async {
  if (firebaseReady && !kIsWeb) {
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (firebaseReady && !kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } else {
      AppLogger.error(
        'FlutterError',
        details.exception,
        details.stack,
      );
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (firebaseReady && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      AppLogger.error('Uncaught async error', error, stack);
    }
    return true;
  };
}

/// Record a non-fatal error (safe if Crashlytics is unavailable).
Future<void> recordNonFatal(
  Object error,
  StackTrace stack, {
  String? reason,
}) async {
  AppLogger.error(reason ?? 'Non-fatal error', error, stack);
  try {
    if (!kIsWeb && FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: false,
      );
    }
  } catch (_) {
    // Crashlytics may not be initialized yet.
  }
}
