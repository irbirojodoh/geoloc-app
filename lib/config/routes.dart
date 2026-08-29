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
import '../presentation/screens/settings/change_username_screen.dart';
import '../presentation/screens/settings/muted_users_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/messages/inbox_screen.dart';
import '../presentation/screens/messages/chat_screen.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/widgets/app_shell.dart';
import '../presentation/widgets/auth_card_swap.dart';
import '../presentation/widgets/route_secondary_animation.dart';
import '../presentation/widgets/swipe_back_page.dart';
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
  static const String profileTab = '/profile';
  static const String profile = '/profile/:id';
  static const String editProfile = '/profile/edit';
  static const String onboarding = '/onboarding';
  static const String search = '/search';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String settingsBlocked = '/settings/blocked';
  static const String settingsMuted = '/settings/muted';
  static const String settingsUsername = '/settings/username';
  static const String messages = '/messages';
  static const String dmChat = '/messages/chat/:id';

  static String chatPath(String conversationId, String peerUserId) =>
      '/messages/chat/$conversationId?peerUserId=$peerUserId';
}

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Kept for call sites that used to drive tab-slide direction.
void setShellNavTransitionDirection(int direction) {}

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
    navigatorKey: _rootNavigatorKey,
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
        pageBuilder: (context, state) => SwipeBackPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // No page-level motion — the welcome card listens to
            // [secondaryAnimation] and slides itself out for register.
            return RouteSecondaryAnimation(
              animation: secondaryAnimation,
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        pageBuilder: (context, state) => _buildDetailSlidePage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return _buildDetailSlidePage(
            state: state,
            child: ResetPasswordScreen(initialToken: token),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.register,
        pageBuilder: (context, state) => SwipeBackPage(
          key: state.pageKey,
          opaque: false, // Allow login background to show through
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(AuthCardSwap.registerOffset),
              child: child,
            );
          },
          transitionDuration: AuthCardSwap.duration,
          reverseTransitionDuration: AuthCardSwap.duration,
        ),
      ),

      // Tabs stay mounted in an IndexedStack so switching pages does not
      // dispose them or refetch. Overlay routes sit on the root navigator.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.feed,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: FeedScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.search,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SearchScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.messages,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: InboxScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.notifications,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: NotificationsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profileTab,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CurrentUserProfileTab(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.createPost,
        pageBuilder: (context, state) => _buildDetailSlidePage(
          state: state,
          child: const CreatePostScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.postDetail,
        pageBuilder: (context, state) {
          final postId = state.pathParameters['id']!;
          return _buildDetailSlidePage(
            state: state,
            child: PostDetailScreen(postId: postId),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.editProfile,
        pageBuilder: (context, state) => _buildDetailSlidePage(
          state: state,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.onboarding,
        pageBuilder: (context, state) => _buildDetailSlidePage(
          state: state,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.profile,
        pageBuilder: (context, state) {
          final userId = state.pathParameters['id']!;
          return _buildDetailSlidePage(
            state: state,
            child: ProfileScreen(userId: userId),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.settings,
        pageBuilder: (context, state) => _buildDetailSlidePage(
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.settingsUsername,
        pageBuilder: (context, state) => _buildDetailSlidePage(
          state: state,
          child: const ChangeUsernameScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.settingsBlocked,
        pageBuilder: (context, state) => _buildDetailSlidePage(
          state: state,
          child: const BlockedUsersScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.settingsMuted,
        pageBuilder: (context, state) => _buildDetailSlidePage(
          state: state,
          child: const MutedUsersScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RoutePaths.dmChat,
        pageBuilder: (context, state) {
          final conversationId = state.pathParameters['id']!;
          final peerUserId = state.uri.queryParameters['peerUserId'] ?? '';
          return _buildDetailSlidePage(
            state: state,
            child: ChatScreen(
              conversationId: conversationId,
              peerUserId: peerUserId,
            ),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.matchedLocation}')),
    ),
  );
});

SwipeBackPage<void> _buildDetailSlidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return SwipeBackPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = swipeBackGestureInProgress(context)
          ? Curves.linear
          : Curves.easeInOutCubic;
      final incomingOffset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: curve,
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
