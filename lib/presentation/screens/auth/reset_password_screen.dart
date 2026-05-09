import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../widgets/geoloc_app_bar.dart';
import '../../widgets/icon_square_button.dart';

import '../../../config/routes.dart';
import '../../../services/auth_service.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// Token from emailed deep link (?token=…) or pasted by user.
  final String initialToken;

  const ResetPasswordScreen({super.key, required this.initialToken});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController _tokenController;
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).resetPassword(
            token: _tokenController.text.trim(),
            newPassword: _pwd.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated — you can sign in now.')),
      );
      context.go(RoutePaths.login);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reset password. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          GeolocAppBar(
            title: 'New password',
            leading: IconSquareButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Back',
              onTap: () => context.go(RoutePaths.login),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create a secure password for your account.',
                  style: context.bodyMedium.copyWith(height: 1.45),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _tokenController,
                  style: context.bodyMedium,
                  decoration: const InputDecoration(labelText: 'Reset token'),
                  validator: (v) {
                    if (v == null || v.trim().length < 8) {
                      return 'Paste the token from your email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _pwd,
                  obscureText: _obscure,
                  style: context.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Minimum 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pwd2,
                  obscureText: _obscure,
                  style: context.bodyMedium,
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                  validator: (value) {
                    if (value != _pwd.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _submit,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.primary),
                      foregroundColor: cs.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: cs.primary,
                            ),
                          )
                        : Text(
                            'UPDATE PASSWORD',
                            style: context.username,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
      ),
    );
  }
}
