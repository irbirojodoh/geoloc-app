import 'package:flutter/material.dart';

/// Shared welcome ↔ sign-up card swap.
///
/// Same [Interval] is used in both directions (no [reverseCurve]) so reverse
/// is the exact mirror of forward: outgoing card eases out, incoming eases in.
class AuthCardSwap {
  AuthCardSwap._();

  static const duration = Duration(milliseconds: 560);

  /// Welcome card slides down in the first half, back up in the last half.
  static final welcomeOffset = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0, 1.15),
  ).chain(
    CurveTween(
      curve: const Interval(0.0, 0.48, curve: Curves.easeInCubic),
    ),
  );

  /// Sign-up card slides up in the second half, back down in the first half.
  static final registerOffset = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).chain(
    CurveTween(
      curve: const Interval(0.52, 1.0, curve: Curves.easeOutCubic),
    ),
  );
}
