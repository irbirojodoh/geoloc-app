import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Minimum width of the leading-edge hit target (iOS uses 20).
const double kSwipeBackGestureWidth = 20.0;

const double _kMinFlingVelocity = 1.0;
const int _kMaxDroppedSwipePageForwardAnimationTime = 800;
const int _kMaxPageBackAnimationTime = 300;

/// [CustomTransitionPage]-compatible page that adds an iOS-style edge swipe
/// to pop whenever the route is not first in the stack.
class SwipeBackPage<T> extends Page<T> {
  const SwipeBackPage({
    required this.child,
    required this.transitionsBuilder,
    this.transitionDuration = const Duration(milliseconds: 320),
    this.reverseTransitionDuration = const Duration(milliseconds: 320),
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.barrierLabel,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;
  final Duration transitionDuration;
  final Duration reverseTransitionDuration;
  final bool maintainState;
  final bool fullscreenDialog;
  final bool opaque;
  final bool barrierDismissible;
  final Color? barrierColor;
  final String? barrierLabel;
  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) transitionsBuilder;

  @override
  Route<T> createRoute(BuildContext context) => _SwipeBackPageRoute<T>(this);
}

class _SwipeBackPageRoute<T> extends PageRoute<T> {
  _SwipeBackPageRoute(SwipeBackPage<T> page) : super(settings: page);

  SwipeBackPage<T> get _page => settings as SwipeBackPage<T>;

  @override
  bool get barrierDismissible => _page.barrierDismissible;

  @override
  Color? get barrierColor => _page.barrierColor;

  @override
  String? get barrierLabel => _page.barrierLabel;

  @override
  Duration get transitionDuration => _page.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _page.reverseTransitionDuration;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  bool get opaque => _page.opaque;

  @override
  bool get popGestureEnabled {
    if (isFirst) return false;
    if (willHandlePopInternally) return false;
    if (fullscreenDialog) return false;
    if (animation!.status != AnimationStatus.completed) return false;
    if (secondaryAnimation!.status != AnimationStatus.dismissed) return false;
    if (navigator!.userGestureInProgress) return false;
    if (popDisposition == RoutePopDisposition.doNotPop) return false;
    return true;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _page.child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final wrapped = _page.transitionsBuilder(
      context,
      animation,
      secondaryAnimation,
      child,
    );
    return _SwipeBackDetector(
      enabled: popGestureEnabled,
      onStartPopGesture: _startPopGesture,
      child: wrapped,
    );
  }

  _SwipeBackController _startPopGesture() {
    assert(popGestureEnabled);
    return _SwipeBackController(
      navigator: navigator!,
      controller: controller!,
    );
  }
}

/// Drive [animation] linearly while an edge-swipe is in progress so the page
/// tracks the finger. Use in [SwipeBackPage.transitionsBuilder].
bool swipeBackGestureInProgress(BuildContext context) {
  return Navigator.of(context).userGestureInProgress;
}

class _SwipeBackDetector extends StatefulWidget {
  const _SwipeBackDetector({
    required this.enabled,
    required this.onStartPopGesture,
    required this.child,
  });

  final bool enabled;
  final _SwipeBackController Function() onStartPopGesture;
  final Widget child;

  @override
  State<_SwipeBackDetector> createState() => _SwipeBackDetectorState();
}

class _SwipeBackDetectorState extends State<_SwipeBackDetector> {
  _SwipeBackController? _swipe;
  late HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabled) {
      _recognizer.addPointer(event);
    }
  }

  double get _screenWidth {
    final size = context.size;
    if (size == null || size.width <= 0) {
      return MediaQuery.sizeOf(context).width;
    }
    return size.width;
  }

  void _handleDragStart(DragStartDetails details) {
    assert(mounted);
    assert(_swipe == null);
    _swipe = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted);
    final width = _screenWidth;
    if (width <= 0) return;
    var delta = details.primaryDelta! / width;
    if (Directionality.of(context) == TextDirection.rtl) {
      delta = -delta;
    }
    _swipe!.dragUpdate(delta);
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted);
    var velocity = details.velocity.pixelsPerSecond.dx / _screenWidth;
    if (Directionality.of(context) == TextDirection.rtl) {
      velocity = -velocity;
    }
    _swipe!.dragEnd(velocity);
    _swipe = null;
  }

  void _handleDragCancel() {
    assert(mounted);
    _swipe?.dragEnd(0);
    _swipe = null;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final edge = Directionality.of(context) == TextDirection.ltr
        ? padding.left
        : padding.right;
    final dragAreaWidth = math.max(edge, kSwipeBackGestureWidth);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: dragAreaWidth,
          top: 0,
          bottom: 0,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
          ),
        ),
      ],
    );
  }
}

class _SwipeBackController {
  _SwipeBackController({
    required this.navigator,
    required this.controller,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;

  void dragUpdate(double delta) {
    controller.value = (controller.value - delta).clamp(0.0, 1.0);
  }

  void dragEnd(double velocity) {
    const curve = Curves.fastLinearToSlowEaseIn;
    final bool animateForward;
    if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      final droppedPageForwardAnimationTime = math.min(
        lerpDouble(
              _kMaxDroppedSwipePageForwardAnimationTime,
              0,
              controller.value,
            )!
            .floor(),
        _kMaxPageBackAnimationTime,
      );
      controller.animateTo(
        1,
        duration: Duration(milliseconds: droppedPageForwardAnimationTime),
        curve: curve,
      );
    } else {
      navigator.pop();
      if (controller.isAnimating) {
        final droppedPageBackAnimationTime = lerpDouble(
          0,
          _kMaxDroppedSwipePageForwardAnimationTime,
          controller.value,
        )!.floor();
        controller.animateBack(
          0,
          duration: Duration(milliseconds: droppedPageBackAnimationTime),
          curve: curve,
        );
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener listener;
      listener = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(listener);
      };
      controller.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }
}
