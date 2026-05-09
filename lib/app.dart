import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/deep_links.dart';
import 'config/routes.dart';
import 'config/theme.dart';

/// Root app widget — wires [routerProvider] + password-reset deep links.
class GeolocApp extends ConsumerStatefulWidget {
  const GeolocApp({super.key});

  @override
  ConsumerState<GeolocApp> createState() => _GeolocAppState();
}

class _GeolocAppState extends ConsumerState<GeolocApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachDeepLinks());
  }

  Future<void> _attachDeepLinks() async {
    final router = ref.read(routerProvider);

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        navigateFromPasswordResetDeepLink(initial, router);
      }
    } catch (_) {}

    try {
      _linkSub = _appLinks.uriLinkStream.listen((uri) {
        navigateFromPasswordResetDeepLink(uri, router);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Geoloc',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Router configuration
      routerConfig: router,
    );
  }
}
