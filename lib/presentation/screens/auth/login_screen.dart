import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_card_swap.dart';
import '../../widgets/auth_glass_sheet.dart';
import '../../widgets/route_secondary_animation.dart';
import '../../widgets/social_auth_buttons.dart';
import 'social_link_confirm.dart';

/// Material 3 login screen (Apple / Google only).
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    await completeSocialSignInFlow(
      context: context,
      ref: ref,
      signIn: () => ref.read(authStateProvider.notifier).signInWithGoogle(),
    );
  }

  Future<void> _handleAppleSignIn(BuildContext context, WidgetRef ref) async {
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

    // Light-on-glass: navbar-style liquid glass over the photo.
    const sheetFg = AuthGlassSheet.foreground;
    const pillShape = StadiumBorder();

    // Showcase image: network (cached) with safe fallback so login never breaks.
    const showcaseImageUrl =
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1600&q=60';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: showcaseImageUrl,
              fit: BoxFit.cover,
              memCacheWidth: (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
              memCacheHeight: (MediaQuery.sizeOf(context).height *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
              fadeInDuration: const Duration(milliseconds: 250),
              placeholder: (context, _) =>
                  Container(color: colorScheme.surfaceContainerHighest),
              errorWidget: (context, _, _) => Container(
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

            // Soft vignette — keep photo visible so liquid glass can refract it.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.40),
                  ],
                ),
              ),
            ),

            _slideWelcomeCardAway(
              context,
              child: AuthGlassSheet(
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
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 40),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                foregroundColor: sheetFg.withValues(alpha: 0.9),
                                shape: pillShape,
                                textStyle: textTheme.labelLarge,
                              ),
                            ),
                            outlinedButtonTheme: OutlinedButtonThemeData(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                foregroundColor: sheetFg,
                                backgroundColor: sheetFg.withValues(alpha: 0.10),
                                side: BorderSide(
                                  color: sheetFg.withValues(alpha: 0.4),
                                ),
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
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: colorScheme.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Welcome to Geoloc.',
                                    style: textTheme.titleLarge?.copyWith(
                                      color: sheetFg,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sign in with Apple or Google',
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
                                enabled: !authState.isLoading,
                                onApple: () =>
                                    _handleAppleSignIn(context, ref),
                                onGoogle: () =>
                                    _handleGoogleSignIn(context, ref),
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
                                  context.push(RoutePaths.register);
                                },
                                child: RichText(
                                  text: TextSpan(
                                    style: textTheme.bodyMedium,
                                    children: [
                                      TextSpan(
                                        text: "Don't have an account? ",
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: sheetFg.withValues(
                                            alpha: 0.75,
                                          ),
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
          ],
        ),
      ),
    );
  }
}

/// Slides the welcome sheet off-screen while register (or another route)
/// is pushed, so the two cards do not stack.
Widget _slideWelcomeCardAway(BuildContext context, {required Widget child}) {
  final secondary = RouteSecondaryAnimation.of(context) ??
      ModalRoute.of(context)?.secondaryAnimation;
  if (secondary == null) return child;

  return SlideTransition(
    position: secondary.drive(AuthCardSwap.welcomeOffset),
    child: child,
  );
}

