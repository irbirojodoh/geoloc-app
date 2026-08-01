import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/bootstrap/crash_reporting.dart';
import 'core/logging/app_logger.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    AppConfig.assertValidForRelease();

    // Prefer bundled fonts; never fetch over the network at runtime.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Hive is required before auth/storage providers touch disk.
    await initLocalStorage();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    // Transparent status bar; brightness is driven by theme in GeolocApp.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
    );

    // Cap decoded-image memory pressure on long feed sessions.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // 80 MB

    final container = ProviderContainer();
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const GeolocApp(),
      ),
    );

    // Deferred: Firebase, Crashlytics, push listeners (no permission dialog).
    unawaited(
      container.read(appBootstrapProvider.future).then<void>(
        (_) {},
        onError: (Object e, StackTrace st) {
          AppLogger.error('Bootstrap failed', e, st);
        },
      ),
    );
  }, (error, stack) {
    AppLogger.error('Zone uncaught error', error, stack);
    unawaited(recordNonFatal(error, stack, reason: 'runZonedGuarded'));
  });
}
