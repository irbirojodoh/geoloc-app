import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/auth_glass_sheet.dart';
import '../../widgets/social_auth_buttons.dart';
import 'social_link_confirm.dart';

/// Material 3 register screen (Apple / Google only).
class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  Future<void> _handleGoogleSignUp(BuildContext context, WidgetRef ref) async {
    await completeSocialSignInFlow(
      context: context,
      ref: ref,
      signIn: () => ref.read(authStateProvider.notifier).signInWithGoogle(),
    );
  }

  Future<void> _handleAppleSignUp(BuildContext context, WidgetRef ref) async {
    await completeSocialSignInFlow(
      context: context,
      ref: ref,
      signIn: () => ref.read(authStateProvider.notifier).signInWithApple(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    const sheetFg = AuthGlassSheet.foreground;
    const pillShape = StadiumBorder();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AuthGlassSheet(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 10 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                brightness: Brightness.dark,
                colorScheme: colorScheme.copyWith(
                  brightness: Brightness.dark,
                  onSurface: sheetFg,
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: sheetFg,
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    foregroundColor: sheetFg.withValues(alpha: 0.9),
                    shape: pillShape,
                    textStyle: textTheme.labelLarge,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to sign in',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                        },
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Create account',
                          style: textTheme.titleLarge?.copyWith(
                            color: sheetFg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign up with Apple or Google',
                    style: textTheme.bodyMedium?.copyWith(
                      color: sheetFg.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (authState.error != null) ...[
                    Text(
                      authState.error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (authState.isLoading) ...[
                    Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SocialAuthButtons(
                    signUp: true,
                    enabled: !authState.isLoading,
                    onApple: () => _handleAppleSignUp(context, ref),
                    onGoogle: () => _handleGoogleSignUp(context, ref),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'By registering, you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: sheetFg.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: sheetFg.withValues(alpha: 0.28),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
                    child: RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: 'Already have an account? ',
                            style: textTheme.bodyMedium?.copyWith(
                              color: sheetFg.withValues(alpha: 0.75),
                            ),
                          ),
                          TextSpan(
                            text: 'Sign in',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
