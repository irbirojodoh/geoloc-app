import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

/// Persistent shell with bottom [NavigationBar] and [FloatingActionButton]
/// for the main app experience.
///
/// Renders [child] (the current top-level route) in the body while keeping the
/// navigation bar and FAB visible. Used by GoRouter's [ShellRoute].
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationStreamProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final notification = next.value!;
        ref.read(notificationsProvider.notifier).addNotification(notification);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notification.message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                context.go(RoutePaths.notifications);
              },
            ),
          ),
        );
      }
    });

    final user = ref.watch(currentUserProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.createPost),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Post'),
        tooltip: 'Create post',
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: _calculateSelectedIndex(context),
          onDestinationSelected: (index) =>
              _onItemTapped(index, context, user?.id),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(unreadCount.toString()),
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(unreadCount.toString()),
                child: const Icon(Icons.notifications),
              ),
              label: 'Notifications',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(RoutePaths.feed)) return 0;
    if (location.startsWith(RoutePaths.search)) return 1;
    if (location.startsWith(RoutePaths.notifications)) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, String? userId) {
    switch (index) {
      case 0:
        context.go(RoutePaths.feed);
        break;
      case 1:
        context.go(RoutePaths.search);
        break;
      case 2:
        context.go(RoutePaths.notifications);
        break;
      case 3:
        if (userId != null && userId.isNotEmpty) {
          context.go('/profile/$userId');
        } else {
          context.go(RoutePaths.feed);
        }
        break;
    }
  }
}
