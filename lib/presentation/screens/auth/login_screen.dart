import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';

/// Material 3 login screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authStateProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      context.go(RoutePaths.feed);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final success =
        await ref.read(authStateProvider.notifier).signInWithGoogle();
    if (success && mounted) {
      final authState = ref.read(authStateProvider);
      if (authState.isNewUser) {
        context.go(RoutePaths.editProfile);
      } else {
        context.go(RoutePaths.feed);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    final success =
        await ref.read(authStateProvider.notifier).signInWithApple();
    if (success && mounted) {
      final authState = ref.read(authStateProvider);
      if (authState.isNewUser) {
        context.go(RoutePaths.editProfile);
      } else {
        context.go(RoutePaths.feed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final pillShape = const StadiumBorder();
    final pillOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: colorScheme.onInverseSurface.withValues(alpha: 0.25)),
    );

    // Showcase image: network (cached) with safe fallback so login never breaks.
    const showcaseImageUrl = 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1600&q=60';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background showcase image (cached network) with safe fallback.
            CachedNetworkImage(
              imageUrl: showcaseImageUrl,
              fit: BoxFit.cover,
              memCacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              memCacheHeight:
                  (MediaQuery.sizeOf(context).height *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              fadeInDuration: const Duration(milliseconds: 250),
              placeholder: (context, _) => Container(
                color: colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (context, _, __) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.surfaceContainerHighest,
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),

            // Dark overlay for legibility.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                      colorScheme.scrim.withOpacity(0.25),
                      colorScheme.scrim.withOpacity(0.45),
                      colorScheme.scrim.withOpacity(0.60),
                  ],
                ),
              ),
            ),

            // Bottom login card.
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  color: colorScheme.scrim.withOpacity(0.55),
                  elevation: 3,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 20,
                      // Keep the sheet touching the bottom edge; apply safe/keyboard
                      // inset *inside* the sheet content.
                      bottom: 16 +
                          (MediaQuery.viewInsetsOf(context).bottom > 0
                              ? MediaQuery.viewInsetsOf(context).bottom
                              : MediaQuery.paddingOf(context).bottom),
                    ),
                    child: Theme(
                      // Pill-only styling for this screen's inputs/buttons.
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme:
                            Theme.of(context).inputDecorationTheme.copyWith(
                                  filled: true,
                                  fillColor: colorScheme.onInverseSurface.withValues(alpha: 0.12),
                                  border: pillOutline,
                                  enabledBorder: pillOutline,
                                  focusedBorder: pillOutline,
                                  hintStyle: TextStyle(
                                    color: colorScheme.onInverseSurface.withValues(alpha: 0.5),
                                  ),
                                  labelStyle: TextStyle(
                                    color: colorScheme.onInverseSurface.withValues(alpha: 0.9),
                                  ),
                                  prefixIconColor: colorScheme.onInverseSurface.withValues(alpha: 0.9),
                                  suffixIconColor: colorScheme.onInverseSurface.withValues(alpha: 0.9),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                        filledButtonTheme: FilledButtonThemeData(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: pillShape,
                            textStyle: textTheme.labelLarge,
                          ),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            shape: pillShape,
                            textStyle: textTheme.labelLarge,
                          ),
                        ),
                        outlinedButtonTheme: OutlinedButtonThemeData(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            foregroundColor: colorScheme.onInverseSurface.withValues(alpha: 1),
                            backgroundColor: colorScheme.onInverseSurface.withValues(alpha: 0.08),
                            side: BorderSide(
                              color: colorScheme.onInverseSurface.withValues(alpha: 0.35),
                            ),
                            shape: pillShape,
                            textStyle: textTheme.labelLarge,
                          ),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Welcome to Geoloc.',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onInverseSurface.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enter your credentials',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onInverseSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (authState.error != null) ...[
                              Text(
                                authState.error!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    context.push(RoutePaths.forgotPassword),
                                child: const Text('Forgot Password?'),
                              ),
                            ),

                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed:
                                  authState.isLoading ? null : _handleLogin,
                              child: authState.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),

                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: colorScheme.onInverseSurface.withValues(alpha: 0.25),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or sign in using',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onInverseSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: colorScheme.onInverseSurface.withValues(alpha: 0.25),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SocialAuthButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : _handleGoogleSignIn,
                                    icon: Icons.g_mobiledata,
                                    label: 'Google',
                                  ),
                                ),
                                if (!kIsWeb &&
                                    (Platform.isIOS || Platform.isMacOS)) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SocialAuthButton(
                                      onPressed: authState.isLoading
                                          ? null
                                          : _handleAppleSignIn,
                                      icon: Icons.apple,
                                      label: 'Apple',
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                context.push(RoutePaths.register);
                              },
                              child: RichText(
                                text: TextSpan(
                                  style: textTheme.bodyMedium,
                                  children: [
                                    TextSpan(
                                      text: "Don't have an account? ",
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onInverseSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Sign up',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: colorScheme.onInverseSurface.withValues(alpha: 1),
        backgroundColor: colorScheme.onInverseSurface.withValues(alpha: 0.08),
        side: BorderSide(color: colorScheme.onInverseSurface.withValues(alpha: 0.35)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: colorScheme.onInverseSurface.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
