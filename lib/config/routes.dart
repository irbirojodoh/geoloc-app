import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/forgot_password_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/auth/reset_password_screen.dart';
import '../presentation/screens/feed/feed_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/profile/edit_profile_screen.dart';
import '../presentation/screens/search/search_screen.dart';
import '../presentation/screens/notifications/notifications_screen.dart';
import '../presentation/screens/post/create_post_screen.dart';
import '../presentation/screens/post/post_detail_screen.dart';
import '../presentation/screens/settings/blocked_users_screen.dart';
import '../presentation/screens/settings/muted_users_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/widgets/app_shell.dart';
import '../presentation/widgets/wordmark.dart';
import '../core/theme/app_colors.dart';

/// Route paths
class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String feed = '/feed';
  static const String createPost = '/create-post';
  static const String postDetail = '/post/:id';
  static const String profile = '/profile/:id';
  static const String editProfile = '/profile/edit';
  static const String onboarding = '/onboarding';
  static const String search = '/search';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String settingsBlocked = '/settings/blocked';
  static const String settingsMuted = '/settings/muted';
}

int _shellNavDirection = 1;

void setShellNavTransitionDirection(int direction) {
  _shellNavDirection = direction == 0 ? 1 : direction.sign;
}

/// Router configuration
///
/// Subscribes once to [authStateProvider] via [ref.listen] and feeds a
/// [ValueNotifier] into GoRouter's [GoRouter.refreshListenable]. The router
/// is **not** rebuilt on every auth state change — only the redirect logic
/// re-runs when the `isAuthenticated` flag flips. This avoids tearing down
/// the navigator stack on benign state updates (e.g. user profile refresh).
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<bool>(
    ref.read(authStateProvider).isAuthenticated,
  );
  ref.listen<AuthState>(authStateProvider, (previous, next) {
    if (previous?.isAuthenticated != next.isAuthenticated) {
      authListenable.value = next.isAuthenticated;
    }
  });
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final isLoggedIn = authListenable.value;
      final loc = state.matchedLocation;
      final isSplash = loc == RoutePaths.splash;

      final publicWhileLoggedOut = {
        RoutePaths.login,
        RoutePaths.register,
        RoutePaths.forgotPassword,
        RoutePaths.resetPassword,
      };

      final isAuthGateRoute =
          loc == RoutePaths.login || loc == RoutePaths.register;

      // If on splash, redirect based on auth state
      if (isSplash) {
        return isLoggedIn ? RoutePaths.feed : RoutePaths.login;
      }

      // If not logged in and not on a public auth-related route, go to login
      if (!isLoggedIn && !publicWhileLoggedOut.contains(loc)) {
        return RoutePaths.login;
      }

      // If logged in and on login/register (not forgot/reset), go to feed
      if (isLoggedIn && isAuthGateRoute) {
        return RoutePaths.feed;
      }

      return null;
    },
    routes: [
      // Splash/Loading route
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const _SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordScreen(initialToken: token);
        },
      ),
      GoRoute(
        path: RoutePaths.register,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          opaque: false, // Allow login background to show through
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide from bottom animation
            const begin = Offset(0.0, 1.0); // Start from bottom
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
        ),
      ),

      // Main app routes — wrapped in ShellRoute for persistent bottom nav
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.feed,
            pageBuilder: (context, state) => _buildShellRootPage(
              state: state,
              child: const FeedScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.createPost,
            pageBuilder: (context, state) => _buildDetailSlidePage(
              state: state,
              child: const CreatePostScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.postDetail,
            pageBuilder: (context, state) {
              final postId = state.pathParameters['id']!;
              return _buildDetailSlidePage(
                state: state,
                child: PostDetailScreen(postId: postId),
              );
            },
          ),
          // Edit profile must come BEFORE /profile/:id to avoid "edit" being parsed as userId
          GoRoute(
            path: RoutePaths.editProfile,
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: RoutePaths.onboarding,
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: RoutePaths.profile,
            pageBuilder: (context, state) {
              final userId = state.pathParameters['id']!;
              return _buildShellRootPage(
                state: state,
                child: ProfileScreen(userId: userId),
              );
            },
          ),
          GoRoute(
            path: RoutePaths.search,
            pageBuilder: (context, state) => _buildShellRootPage(
              state: state,
              child: const SearchScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.notifications,
            pageBuilder: (context, state) => _buildShellRootPage(
              state: state,
              child: const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: RoutePaths.settingsBlocked,
            builder: (context, state) => const BlockedUsersScreen(),
          ),
          GoRoute(
            path: RoutePaths.settingsMuted,
            builder: (context, state) => const MutedUsersScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.matchedLocation}')),
    ),
  );
});

CustomTransitionPage<void> _buildShellRootPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Read direction at transition-time so incoming/outgoing pages
      // participate in the same navigation event direction.
      final direction = _shellNavDirection.toDouble();
      final incomingOffset = Tween<Offset>(
        begin: Offset(direction, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        ),
      );
      final outgoingOffset = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-direction, 0),
      ).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInOutCubic,
        ),
      );
      return SlideTransition(
        position: outgoingOffset,
        child: SlideTransition(
          position: incomingOffset,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 320),
  );
}

CustomTransitionPage<void> _buildDetailSlidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final incomingOffset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        ),
      );
      return SlideTransition(
        position: incomingOffset,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 320),
  );
}

/// Branded splash screen while checking auth state.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Wordmark(fontSize: 28),
            const SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
