import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';

// ============================================================================
// Dynamic Colors for Light/Dark Mode Adaptation
// ============================================================================

/// Background gradient colors - adapts to light/dark mode
const CupertinoDynamicColor _backgroundPrimary =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFF2F2F7), // Light mode: iOS system background
      darkColor: Color(0xFF1a1a2e), // Dark mode: Deep dark blue
    );

const CupertinoDynamicColor _backgroundSecondary =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFE5E5EA), // Light mode
      darkColor: Color(0xFF16213e), // Dark mode: Navy
    );

const CupertinoDynamicColor _backgroundTertiary =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFD1D1D6), // Light mode
      darkColor: Color(0xFF0f3460), // Dark mode: Midnight blue
    );

/// Card background colors
const CupertinoDynamicColor _cardBackgroundStart =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFFFFFFF), // Light mode: White
      darkColor: Color(0xFF3B3B3B), // Dark mode: Dark gray
    );

const CupertinoDynamicColor _cardBackgroundEnd =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFF8F8F8), // Light mode: Off-white
      darkColor: Color(0xFF262525), // Dark mode: Darker gray
    );

/// Text field colors
const CupertinoDynamicColor _textFieldFill =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFE8E8E8), // Light mode: Light gray
      darkColor: Color(0xFF1E1E1E), // Dark mode: Very dark gray
    );

/// Text colors
const CupertinoDynamicColor _primaryText = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF000000), // Light mode: Black
  darkColor: Color(0xFFFFFFFF), // Dark mode: White
);

// const CupertinoDynamicColor _secondaryText = // Removed as unused
//     CupertinoDynamicColor.withBrightness(
//       color: Color(0xFF6C6C70), // Light mode: Gray
//       darkColor: Color(0xFF919191), // Dark mode: Light gray
//     );

// const CupertinoDynamicColor _tertiaryText = // Removed as unused
//     CupertinoDynamicColor.withBrightness(
//       color: Color(0xFF8E8E93), // Light mode
//       darkColor: Color(0xFF666666), // Dark mode
//     );

/// Divider color
const CupertinoDynamicColor _dividerColor =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFC6C6C8), // Light mode
      darkColor: Color(0xFF4A4A4A), // Dark mode
    );

/// Shadow color
const CupertinoDynamicColor _shadowColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x1A000000), // Light mode: Subtle shadow
  darkColor: Color(0x80000000), // Dark mode: Stronger shadow
);

// ============================================================================
// Login Screen Widget
// ============================================================================

/// Login screen with Figma design implementation and dynamic theming
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

  /// Determine if we're in dark mode
  bool _isDarkMode(BuildContext context) {
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  /// Resolve a CupertinoDynamicColor to its current brightness value
  Color _resolveColor(
    BuildContext context,
    CupertinoDynamicColor dynamicColor,
  ) {
    return CupertinoDynamicColor.resolve(dynamicColor, context);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isDark = _isDarkMode(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Background with gradient
            _buildBackground(context, screenSize),

            // Top gradient overlay (only in dark mode)
            if (isDark) _buildTopGradient(screenSize),

            // Login card at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildLoginCard(
                context,
                authState,
                screenSize,
                bottomPadding,
                keyboardHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context, Size screenSize) {
    return Image.asset(
      'assets/images/IMG_6454.JPEG',
      width: screenSize.width,
      height: screenSize.height,
      fit: BoxFit.cover,
    );
  }

  Widget _buildTopGradient(Size screenSize) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: screenSize.height * 0.25,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.05, 0.6, 1.0],
            colors: [
              const Color.fromRGBO(0, 0, 0, 0.7),
              const Color.fromRGBO(0, 0, 0, 0.34),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(
    BuildContext context,
    dynamic authState,
    Size screenSize,
    double bottomPadding,
    double keyboardHeight,
  ) {
    // Calculate responsive card height
    final isSmallScreen = screenSize.height < 700;
    final cardMaxHeight = screenSize.height * (isSmallScreen ? 0.72 : 0.65);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: BoxConstraints(
        maxHeight: keyboardHeight > 0
            ? screenSize.height * 0.85
            : cardMaxHeight,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(50),
          topRight: Radius.circular(50),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.14, 0.67],
          colors: [
            _resolveColor(context, _cardBackgroundStart),
            _resolveColor(context, _cardBackgroundEnd),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _resolveColor(context, _shadowColor),
            blurRadius: 30,
            spreadRadius: 10,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(
            left: 30,
            right: 30,
            top: 31,
            bottom: 40 + keyboardHeight / 2,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title section
                _buildTitleSection(context),
                const SizedBox(height: 20),

                // Error message
                if (authState.error != null)
                  _buildErrorMessage(context, authState.error!),

                // Email field
                _buildEmailField(context),
                const SizedBox(height: 13),

                // Password field
                _buildPasswordField(context),
                const SizedBox(height: 4),

                // Forgot password
                _buildForgotPassword(context),
                const SizedBox(height: 13),

                // Login button
                _buildLoginButton(context, authState.isLoading),
                const SizedBox(height: 20),

                // Or divider
                _buildOrDivider(context),
                const SizedBox(height: 20),

                // Social login buttons
                _buildSocialLoginButtons(context),
                const SizedBox(height: 20),

                // Register link
                _buildRegisterLink(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Geoloc.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: _resolveColor(context, _primaryText),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Enter your credentials',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String error) {
    final errorColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemRed,
      context,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color.fromRGBO(
          errorColor.r.toInt(),
          errorColor.g.toInt(),
          errorColor.b.toInt(),
          0.15,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color.fromRGBO(
            errorColor.r.toInt(),
            errorColor.g.toInt(),
            errorColor.b.toInt(),
            0.3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: errorColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.plusJakartaSans(
                color: errorColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: GoogleFonts.plusJakartaSans(
        color: _resolveColor(context, _primaryText),
      ),
      decoration: _buildInputDecoration(
        context: context,
        label: 'Email Address',
        hint: 'Enter your username or email',
        icon: CupertinoIcons.person,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      style: GoogleFonts.plusJakartaSans(
        color: _resolveColor(context, _primaryText),
      ),
      decoration: _buildInputDecoration(
        context: context,
        label: 'Password',
        hint: 'Enter your password',
        icon: CupertinoIcons.lock,
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: Icon(
            _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            color: iconColor,
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
    );
  }

  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final hintColor = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiaryLabel,
      context,
    );
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final fillColor = _resolveColor(context, _textFieldFill);
    final focusBorderColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBlue,
      context,
    );
    final errorBorderColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemRed,
      context,
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.plusJakartaSans(color: labelColor),
      hintStyle: GoogleFonts.plusJakartaSans(color: hintColor),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 25, right: 10),
        child: Icon(icon, color: iconColor),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(right: 15),
              child: suffixIcon,
            )
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: focusBorderColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: errorBorderColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: errorBorderColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildForgotPassword(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () {
          // TODO: Implement forgot password
        },
        child: Text(
          'Forgot Password?',
          style: GoogleFonts.plusJakartaSans(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.secondaryLabel,
              context,
            ),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context, bool isLoading) {
    final buttonColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBlue,
      context,
    );
    return Center(
      child: SizedBox(
        height: 50,
        width: MediaQuery.of(context).size.width * 0.35,
        child: CupertinoButton(
          color: buttonColor,
          borderRadius: BorderRadius.circular(26),
          padding: EdgeInsets.zero,
          onPressed: isLoading ? null : _handleLogin,
          child: isLoading
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Text(
                  'Sign In',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOrDivider(BuildContext context) {
    final dividerColor = _resolveColor(context, _dividerColor);
    final textColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or sign in using',
            style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 14),
          ),
        ),
        Expanded(child: Container(height: 1, color: dividerColor)),
      ],
    );
  }

  Widget _buildSocialLoginButtons(BuildContext context) {
    return Row(
      children: [
        // Google Sign In
        Expanded(
          child: _buildSocialButton(
            context: context,
            iconWidget: SvgPicture.asset(
              'assets/icons/google_logo.svg',
              width: 20,
              height: 20,
            ),
            label: 'Sign in with Google',
            onTap: () {
              // TODO: Implement Google sign in
            },
          ),
        ),
        const SizedBox(width: 13),
        // Apple Sign In
        Expanded(
          child: _buildSocialButton(
            context: context,
            iconWidget: Icon(
              Icons.apple,
              color: CupertinoDynamicColor.resolve(
                _isDarkMode(context)
                    ? CupertinoColors.black
                    : CupertinoColors.label,
                context,
              ),
              size: 24,
            ),
            label: 'Sign in with Apple',
            onTap: () {
              // TODO: Implement Apple sign in
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = _isDarkMode(context);
    final bgColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.systemGrey6;
    final textColor = isDark ? CupertinoColors.black : CupertinoColors.label;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(bgColor, context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.systemGrey4,
              context,
            ),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: CupertinoDynamicColor.resolve(textColor, context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    final secondaryText = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final linkColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBlue,
      context,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.plusJakartaSans(
            color: secondaryText,
            fontSize: 14,
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            HapticFeedback.mediumImpact();
            context.push(RoutePaths.register);
          },
          child: Text(
            'Sign Up',
            style: GoogleFonts.plusJakartaSans(
              color: linkColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
