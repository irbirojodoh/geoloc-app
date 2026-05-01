import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_extensions.dart';

/// Persistent shell with bottom [NavigationBar] and [FloatingActionButton]
/// for the main app experience.
///
/// Renders [child] (the current top-level route) in the body while keeping the
/// navigation bar and FAB visible. Used by GoRouter's [ShellRoute].
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return Scaffold(
      body: child,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          onPressed: () => context.push(RoutePaths.createPost),
          backgroundColor: gold,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.sharpAll),
          elevation: 0,
          tooltip: 'Create post',
          child: Icon(Icons.add, color: cs.onPrimary, size: AppIconSize.lg),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        backgroundColor: cs.surface,
        indicatorColor: gold.withValues(alpha: 0.12),
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline, size: 32),
            selectedIcon: Icon(Icons.add_circle, size: 32),
            label: 'Post',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(RoutePaths.feed)) return 0;
    if (location.startsWith(RoutePaths.search)) return 1;
    if (location.startsWith('/create')) return 2;
    if (location.startsWith(RoutePaths.notifications)) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RoutePaths.feed);
        break;
      case 1:
        context.go(RoutePaths.search);
        break;
      case 2:
        context.push(RoutePaths.createPost);
        break;
      case 3:
        context.go(RoutePaths.notifications);
        break;
      case 4:
        context.go(RoutePaths.feed); // Profile needs userId, go to feed
        break;
    }
  }
}
