import 'package:flutter/material.dart';

/// Exposes the current route's [secondaryAnimation] to descendants.
class RouteSecondaryAnimation extends InheritedWidget {
  const RouteSecondaryAnimation({
    super.key,
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RouteSecondaryAnimation>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(RouteSecondaryAnimation oldWidget) =>
      animation != oldWidget.animation;
}
