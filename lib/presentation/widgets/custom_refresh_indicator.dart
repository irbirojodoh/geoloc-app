import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom pull-to-refresh indicator with dots animation and haptic feedback
class CustomRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final ScrollController? scrollController;

  const CustomRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.scrollController,
  });

  @override
  State<CustomRefreshIndicator> createState() => _CustomRefreshIndicatorState();
}

class _CustomRefreshIndicatorState extends State<CustomRefreshIndicator>
    with SingleTickerProviderStateMixin {
  static const double _triggerOffset = 80.0;
  static const double _maxOffset = 120.0;

  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  bool _hasTriggeredHaptic = false;
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    if (!_hasTriggeredHaptic && _dragOffset >= _triggerOffset) {
      HapticFeedback.mediumImpact();
      _hasTriggeredHaptic = true;
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    _dotsController.repeat();
    HapticFeedback.lightImpact();

    try {
      await widget.onRefresh();
    } finally {
      HapticFeedback.lightImpact();
      setState(() {
        _isRefreshing = false;
        _dragOffset = 0.0;
        _hasTriggeredHaptic = false;
      });
      _dotsController.stop();
      _dotsController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_isRefreshing) return false;

        if (notification is ScrollUpdateNotification) {
          if (notification.metrics.pixels < 0) {
            setState(() {
              _dragOffset = (-notification.metrics.pixels).clamp(
                0.0,
                _maxOffset,
              );
            });
            _triggerHaptic();
          }
        }

        if (notification is ScrollEndNotification) {
          if (_dragOffset >= _triggerOffset && !_isRefreshing) {
            _handleRefresh();
          } else {
            setState(() {
              _dragOffset = 0.0;
              _hasTriggeredHaptic = false;
            });
          }
        }

        return false;
      },
      child: Stack(
        children: [
          // Pull-to-refresh indicator
          if (_dragOffset > 0 || _isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: _isRefreshing ? 60 : _dragOffset,
                alignment: Alignment.center,
                child: _isRefreshing
                    ? AnimatedBuilder(
                        animation: _dotsController,
                        builder: (context, _) {
                          return _DotsIndicator(
                            progress: _dotsController.value,
                          );
                        },
                      )
                    : _PullIndicator(
                        progress: _dragOffset / _triggerOffset,
                        isTriggered: _hasTriggeredHaptic,
                      ),
              ),
            ),
          // Main content with offset
          Transform.translate(
            offset: Offset(0, _isRefreshing ? 60 : _dragOffset),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Pull indicator showing progress before refresh triggers
class _PullIndicator extends StatelessWidget {
  final double progress;
  final bool isTriggered;

  const _PullIndicator({required this.progress, required this.isTriggered});

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(
      isTriggered ? CupertinoColors.systemBlue : CupertinoColors.secondaryLabel,
      context,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final dotProgress = (progress - (index * 0.2)).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8 + (dotProgress * 4),
          height: 8 + (dotProgress * 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.3 + (dotProgress * 0.7)),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// Animated dots indicator during refresh
class _DotsIndicator extends StatelessWidget {
  final double progress;

  const _DotsIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBlue,
      context,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        // Stagger the animation for each dot
        final dotProgress = ((progress + (index * 0.33)) % 1.0);
        final scale = 0.6 + (0.4 * _bounceValue(dotProgress));
        final opacity = 0.4 + (0.6 * _bounceValue(dotProgress));

        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }

  double _bounceValue(double value) {
    // Create a spring-like bounce effect
    if (value < 0.5) {
      return 4 * value * value * value;
    } else {
      return 1 - ((-2 * value + 2) * (-2 * value + 2) * (-2 * value + 2)) / 2;
    }
  }
}
