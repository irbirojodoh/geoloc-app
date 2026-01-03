import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';

/// Login screen with Figma design implementation
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background with gradient
          _buildBackground(screenSize),

          // Top gradient overlay
          _buildTopGradient(screenSize),

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
    );
  }

  Widget _buildBackground(Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a2e), // Deep dark blue
            Color(0xFF16213e), // Navy
            Color(0xFF0f3460), // Midnight blue
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.14, 0.67],
          colors: [
            Color(0xFF3B3B3B), // rgb(59, 59, 59)
            Color(0xFF262525), // rgb(38, 37, 37)
          ],
        ),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.5),
            blurRadius: 30,
            spreadRadius: 10,
            offset: Offset(0, -10),
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
            bottom: 34 + bottomPadding,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title section
                _buildTitleSection(),
                const SizedBox(height: 20),

                // Error message
                if (authState.error != null)
                  _buildErrorMessage(authState.error!),

                // Email field
                _buildEmailField(),
                const SizedBox(height: 13),

                // Password field
                _buildPasswordField(),
                const SizedBox(height: 8),

                // Forgot password
                _buildForgotPassword(),
                const SizedBox(height: 20),

                // Login button
                _buildLoginButton(authState.isLoading),
                const SizedBox(height: 20),

                // Or divider
                _buildOrDivider(),
                const SizedBox(height: 20),

                // Social login buttons
                _buildSocialLoginButtons(),
                const SizedBox(height: 20),

                // Register link
                _buildRegisterLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Enter your credentials',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF919191),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(244, 67, 54, 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(244, 67, 54, 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.redAccent,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: GoogleFonts.plusJakartaSans(color: Colors.white),
      decoration: _buildInputDecoration(
        label: 'Email Address',
        hint: 'Enter your email',
        icon: Icons.email_outlined,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      style: GoogleFonts.plusJakartaSans(color: Colors.white),
      decoration: _buildInputDecoration(
        label: 'Password',
        hint: 'Enter your password',
        icon: Icons.lock_outlined,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: const Color(0xFF919191),
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF919191)),
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF666666)),
      prefixIcon: Icon(icon, color: const Color(0xFF919191)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          // TODO: Implement forgot password
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Forgot Password?',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF6366F1),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool isLoading) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color.fromRGBO(99, 102, 241, 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Sign In',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFF4A4A4A))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919191),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFF4A4A4A))),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    return Row(
      children: [
        // Google Sign In
        Expanded(
          child: _buildSocialButton(
            icon: Icons.g_mobiledata,
            label: 'Google',
            onTap: () {
              // TODO: Implement Google sign in
            },
          ),
        ),
        const SizedBox(width: 13),
        // Apple Sign In
        Expanded(
          child: _buildSocialButton(
            icon: Icons.apple,
            label: 'Apple',
            onTap: () {
              // TODO: Implement Apple sign in
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.roboto(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919191),
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () => context.go(RoutePaths.register),
          child: Text(
            'Sign Up',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF6366F1),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
