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
// Register Screen Widget
// ============================================================================

/// Register screen with dynamic theming matching login screen
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authStateProvider.notifier)
        .register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
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
        backgroundColor:
            Colors.transparent, // Transparent so login background shows
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Register card at bottom - no background, so login background shows through
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildRegisterCard(
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
    return Container(
      width: screenSize.width,
      height: screenSize.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _resolveColor(context, _backgroundPrimary),
            _resolveColor(context, _backgroundSecondary),
            _resolveColor(context, _backgroundTertiary),
          ],
        ),
      ),
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

  Widget _buildRegisterCard(
    BuildContext context,
    dynamic authState,
    Size screenSize,
    double bottomPadding,
    double keyboardHeight,
  ) {
    // Calculate responsive card height - taller for register since more fields
    final isSmallScreen = screenSize.height < 700;
    final cardMaxHeight = screenSize.height * (isSmallScreen ? 0.85 : 0.78);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: BoxConstraints(
        maxHeight: keyboardHeight > 0
            ? screenSize.height * 0.92
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
            bottom: 34 + keyboardHeight,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Back button and title section
                _buildHeader(context),
                const SizedBox(height: 16),

                // Error message
                if (authState.error != null)
                  _buildErrorMessage(context, authState.error!),

                // Full Name field
                _buildTextField(
                  context: context,
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  icon: CupertinoIcons.person,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 13),

                // Username field
                _buildTextField(
                  context: context,
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'Choose a username',
                  icon: CupertinoIcons.at,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                      return 'Only letters, numbers, and underscores';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 13),

                // Email field
                _buildTextField(
                  context: context,
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: CupertinoIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 13),

                // Password field
                _buildPasswordField(
                  context: context,
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  isObscured: _obscurePassword,
                  onToggleObscure: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 13),

                // Confirm Password field
                _buildPasswordField(
                  context: context,
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  isObscured: _obscureConfirmPassword,
                  onToggleObscure: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                  onSubmitted: (_) => _handleRegister(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Register button
                _buildRegisterButton(context, authState.isLoading),
                const SizedBox(height: 16),

                // Or divider
                _buildOrDivider(context),
                const SizedBox(height: 16),

                // Social registration buttons
                _buildSocialButtons(context),
                const SizedBox(height: 16),

                // Terms text
                _buildTermsText(context),
                const SizedBox(height: 20),

                // Login link
                _buildLoginLink(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Back button
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _resolveColor(context, _textFieldFill),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              CupertinoIcons.back,
              color: _resolveColor(context, _primaryText),
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: _resolveColor(context, _primaryText),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sign up to get started',
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
        ),
      ],
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

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      textCapitalization: textCapitalization,
      style: GoogleFonts.plusJakartaSans(
        color: _resolveColor(context, _primaryText),
        fontSize: 13,
      ),
      decoration: _buildInputDecoration(
        context: context,
        label: label,
        hint: hint,
        icon: icon,
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isObscured,
    required VoidCallback onToggleObscure,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return TextFormField(
      controller: controller,
      obscureText: isObscured,
      textInputAction: onSubmitted != null
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      style: GoogleFonts.plusJakartaSans(
        color: _resolveColor(context, _primaryText),
      ),
      decoration: _buildInputDecoration(
        context: context,
        label: label,
        hint: hint,
        icon: CupertinoIcons.lock,
        suffixIcon: GestureDetector(
          onTap: onToggleObscure,
          child: Icon(
            isObscured ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            color: iconColor,
          ),
        ),
      ),
      validator: validator,
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
      labelStyle: GoogleFonts.plusJakartaSans(color: labelColor, fontSize: 13),
      hintStyle: GoogleFonts.plusJakartaSans(color: hintColor, fontSize: 13),
      floatingLabelBehavior:
          FloatingLabelBehavior.never, // Prevents label from cutting border
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
            'or register using',
            style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 14),
          ),
        ),
        Expanded(child: Container(height: 1, color: dividerColor)),
      ],
    );
  }

  Widget _buildSocialButtons(BuildContext context) {
    return Row(
      children: [
        // Google Sign Up
        Expanded(
          child: _buildSocialButton(
            context: context,
            iconWidget: SvgPicture.asset(
              'assets/icons/google_logo.svg',
              width: 20,
              height: 20,
            ),
            label: 'Sign up with Google',
            onTap: () {
              // TODO: Implement Google sign up
            },
          ),
        ),
        const SizedBox(width: 13),
        // Apple Sign Up
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
            label: 'Sign up with Apple',
            onTap: () {
              // TODO: Implement Apple sign up
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

  Widget _buildRegisterButton(BuildContext context, bool isLoading) {
    final buttonColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBlue,
      context,
    );
    return Center(
      child: SizedBox(
        height: 50,
        width: MediaQuery.of(context).size.width * 0.5,
        child: CupertinoButton(
          color: buttonColor,
          borderRadius: BorderRadius.circular(26),
          padding: EdgeInsets.zero,
          onPressed: isLoading ? null : _handleRegister,
          child: isLoading
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Text(
                  'Create Account',
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

  Widget _buildTermsText(BuildContext context) {
    final textColor = CupertinoDynamicColor.resolve(
      CupertinoColors.tertiaryLabel,
      context,
    );
    final linkColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBlue,
      context,
    );
    return Text.rich(
      TextSpan(
        text: 'By signing up, you agree to our ',
        style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 12),
        children: [
          TextSpan(
            text: 'Terms of Service',
            style: GoogleFonts.plusJakartaSans(
              color: linkColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: GoogleFonts.plusJakartaSans(
              color: linkColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoginLink(BuildContext context) {
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
          "Already have an account? ",
          style: GoogleFonts.plusJakartaSans(
            color: secondaryText,
            fontSize: 14,
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
          child: Text(
            'Sign In',
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
