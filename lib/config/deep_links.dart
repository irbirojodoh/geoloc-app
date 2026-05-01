import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Returns true when [uri] is a reset-password deeplink handled by Geoloc.
bool isPasswordResetDeepLink(Uri uri) {
  if (uri.path.contains('reset-password')) return true;
  if (uri.scheme == 'geoloc' &&
      uri.host.toLowerCase().trim() == 'reset-password') {
    return true;
  }
  return false;
}

/// Navigates to [RoutePaths.resetPassword] with extracted `token` query.
void navigateFromPasswordResetDeepLink(Uri uri, GoRouter router) {
  if (!isPasswordResetDeepLink(uri)) return;
  final rawToken = uri.queryParameters['token']?.trim() ??
      uri.queryParameters['reset_token']?.trim() ??
      '';
  final q =
      rawToken.isEmpty ? '' : '?token=${Uri.encodeQueryComponent(rawToken)}';
  router.go('${RoutePaths.resetPassword}$q');
}
