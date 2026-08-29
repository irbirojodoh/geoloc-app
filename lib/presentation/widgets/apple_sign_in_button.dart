import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple's official [ASAuthorizationAppleIDButton] on iOS; Flutter fallback elsewhere.
class AppleSignInButton extends StatefulWidget {
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.signUp = false,
    this.height = 44,
  });

  final VoidCallback? onPressed;
  final bool signUp;
  final double height;

  static const _viewType = 'com.irphotoarts.geoloc.apple_id_button';

  @override
  State<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends State<AppleSignInButton> {
  MethodChannel? _channel;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final child = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: AppleSignInButton._viewType,
            creationParams: <String, dynamic>{
              'style': 'white',
              'type': widget.signUp ? 'signUp' : 'signIn',
              'cornerRadius': widget.height / 2,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (id) {
              _channel?.setMethodCallHandler(null);
              _channel = MethodChannel('${AppleSignInButton._viewType}/$id');
              _channel!.setMethodCallHandler((call) async {
                if (call.method == 'onPressed') {
                  widget.onPressed?.call();
                }
              });
            },
          )
        : SignInWithAppleButton(
            onPressed: widget.onPressed ?? () {},
            height: widget.height,
            style: SignInWithAppleButtonStyle.white,
            borderRadius: BorderRadius.circular(widget.height / 2),
            text: widget.signUp ? 'Sign up with Apple' : 'Sign in with Apple',
          );

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: IgnorePointer(
          ignoring: !enabled,
          child: child,
        ),
      ),
    );
  }
}
