import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'apple_sign_in_button.dart';
import 'google_sign_in_button.dart';

/// Stacked official Apple + Google sign-in buttons.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.onApple,
    required this.onGoogle,
    this.signUp = false,
    this.enabled = true,
  });

  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final bool signUp;
  final bool enabled;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final showApple = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showApple) ...[
            AppleSignInButton(
              onPressed: enabled ? onApple : null,
              signUp: signUp,
            ),
            const SizedBox(height: _gap),
          ],
          GoogleSignInButton(
            onPressed: enabled ? onGoogle : null,
            signUp: signUp,
          ),
        ],
      ),
    );
  }
}
