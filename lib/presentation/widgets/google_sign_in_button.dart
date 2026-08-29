import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official "Sign in with Google" button (iOS branding kit: light pill).
///
/// Colors, height, logo size, and type match Google's iOS assets
/// (`Theme=Light, Show text=Yes, Shape=Pill`).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.signUp = false,
    this.height = 44,
  });

  final VoidCallback? onPressed;
  final bool signUp;
  final double height;

  static const _fill = Color(0xFFFFFFFF);
  static const _stroke = Color(0xFF747775);
  static const _label = Color(0xFF1F1F1F);
  static const _logoSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final label = signUp ? 'Sign up with Google' : 'Sign in with Google';

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: _fill,
          shape: const StadiumBorder(
            side: BorderSide(color: _stroke),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/icons/google_logo.svg',
                  width: _logoSize,
                  height: _logoSize,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: _label,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
