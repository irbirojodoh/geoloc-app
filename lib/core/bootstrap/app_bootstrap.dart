import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../firebase_options.dart';
import '../../services/push_notification_service.dart';
import '../cache/local_migrations.dart';
import '../logging/app_logger.dart';
import 'crash_reporting.dart';

/// Result of deferred platform bootstrap (Firebase / push).
class AppBootstrapResult {
  const AppBootstrapResult({required this.firebaseReady});

  final bool firebaseReady;
}

/// Completes when deferred Firebase/push setup finishes.
final appBootstrapProvider =
    FutureProvider<AppBootstrapResult>((ref) async {
  return bootstrapAfterFirstFrame(ref);
});

/// Hive must be available before auth/storage providers run.
Future<void> initLocalStorage() async {
  await Hive.initFlutter();
  await LocalMigrations.run();
}

/// Firebase + Crashlytics + push listeners (no permission dialog).
Future<AppBootstrapResult> bootstrapAfterFirstFrame(Ref ref) async {
  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (!isMobile) {
    await initCrashReporting(firebaseReady: false);
    return const AppBootstrapResult(firebaseReady: false);
  }

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e, st) {
    AppLogger.warning(
      'Firebase unavailable on this build target; push/crash reporting limited.',
      e,
      st,
    );
  }

  await initCrashReporting(firebaseReady: firebaseReady);

  if (firebaseReady) {
    try {
      final pushService = ref.read(pushNotificationServiceProvider);
      await pushService.setupListeners();
    } catch (e, st) {
      AppLogger.warning('Push listener setup failed', e, st);
    }
  }

  return AppBootstrapResult(firebaseReady: firebaseReady);
}
