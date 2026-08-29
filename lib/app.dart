import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/deep_links.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/logging/app_logger.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/followed_locations_provider.dart';
import 'services/push_notification_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Kick deferred Firebase/push bootstrap.
      ref.read(appBootstrapProvider);
      _attachDeepLinks();
      if (ref.read(authStateProvider).isAuthenticated) {
        unawaited(ref.read(followedLocationsProvider.notifier).refresh());
      }
    });
  }

  Future<void> _attachDeepLinks() async {
    final router = ref.read(routerProvider);

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        navigateFromPasswordResetDeepLink(initial, router);
      }
    } catch (e, st) {
      AppLogger.warning('Failed to read initial deep link', e, st);
    }

    try {
      _linkSub = _appLinks.uriLinkStream.listen(
        (uri) {
          navigateFromPasswordResetDeepLink(uri, router);
        },
        onError: (Object e, StackTrace st) {
          AppLogger.warning('Deep link stream error', e, st);
        },
      );
    } catch (e, st) {
      AppLogger.warning('Failed to attach deep link stream', e, st);
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Consume pending push navigation once bootstrap/router are ready.
    ref.listen<String?>(pendingPushRouteProvider, (prev, next) {
      if (next == null || next.isEmpty) return;
      router.go(next);
      ref.read(pendingPushRouteProvider.notifier).state = null;
    });

    // After upgrade, persisted 5-char prefixes are gone. Refetch the
    // server-owned 6-char list so unfollow uses a live identifier.
    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.isAuthenticated && prev?.isAuthenticated != true) {
        unawaited(ref.read(followedLocationsProvider.notifier).refresh());
      } else if (!next.isAuthenticated && prev?.isAuthenticated == true) {
        ref.read(followedLocationsProvider.notifier).clear();
      }
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final overlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: brightness == Brightness.dark
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: Theme.of(context).colorScheme.surface,
          systemNavigationBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
