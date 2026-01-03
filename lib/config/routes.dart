import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/feed/feed_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/profile/edit_profile_screen.dart';
import '../presentation/screens/search/search_screen.dart';
import '../presentation/screens/notifications/notifications_screen.dart';
import '../presentation/screens/post/create_post_screen.dart';
import '../presentation/screens/post/post_detail_screen.dart';
import '../presentation/providers/auth_provider.dart';

/// Route paths
class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String feed = '/feed';
  static const String createPost = '/create-post';
  static const String postDetail = '/post/:id';
  static const String profile = '/profile/:id';
  static const String editProfile = '/profile/edit';
  static const String search = '/search';
  static const String notifications = '/notifications';
}

/// Router configuration
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == RoutePaths.login ||
          state.matchedLocation == RoutePaths.register;
      final isSplash = state.matchedLocation == RoutePaths.splash;

      // If on splash, redirect based on auth state
      if (isSplash) {
        return isLoggedIn ? RoutePaths.feed : RoutePaths.login;
      }

      // If not logged in and not on auth route, redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        return RoutePaths.login;
      }

      // If logged in and on auth route, redirect to feed
      if (isLoggedIn && isAuthRoute) {
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
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app routes
      GoRoute(
        path: RoutePaths.feed,
        builder: (context, state) => const FeedScreen(),
      ),
      GoRoute(
        path: RoutePaths.createPost,
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: RoutePaths.postDetail,
        builder: (context, state) {
          final postId = state.pathParameters['id']!;
          return PostDetailScreen(postId: postId);
        },
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: RoutePaths.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.matchedLocation}')),
    ),
  );
});

/// Simple splash screen while checking auth state
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
