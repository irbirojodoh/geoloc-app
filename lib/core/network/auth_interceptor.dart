import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../services/secure_storage.dart';
import '../../presentation/providers/auth_provider.dart';
import 'api_endpoints.dart';
import '../logging/app_logger.dart';

/// Interceptor for handling JWT authentication
///
/// - Attaches access token to all requests (except auth endpoints)
/// - Automatically refreshes expired access tokens
/// - Handles logout on refresh failure (notifies [authStateProvider])
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final Ref _ref;

  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  final List<RequestOptions> _pendingRequests = [];

  AuthInterceptor(this._ref, this._dio);

  /// Storage handle (uses platform-hardened options).
  static const _storage = secureStorage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for public endpoints
    if (_isPublicEndpoint(options.path)) {
      handler.next(options);
      return;
    }

    // Check if access token exists and is valid
    final accessToken = await _storage.read(key: AppConfig.accessTokenKey);
    final expiryString = await _storage.read(
      key: AppConfig.accessTokenExpiryKey,
    );

    if (accessToken == null) {
      handler.next(options);
      return;
    }

    // Check if token is expired
    if (expiryString != null) {
      final expiry = DateTime.parse(expiryString);
      if (DateTime.now().isAfter(expiry)) {
        // Token expired, try to refresh
        try {
          await _refreshToken();
          final newToken = await _storage.read(key: AppConfig.accessTokenKey);
          if (newToken != null) {
            options.headers['Authorization'] = 'Bearer $newToken';
          }
        } catch (e) {
          // Refresh failed, continue without token (will get 401)
          handler.next(options);
          return;
        }
      } else {
        // Token still valid
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    } else {
      // No expiry info, just use the token
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Unauthorized - try to refresh token
      final options = err.requestOptions;

      // A logout is already in progress (e.g. the device-unregister call
      // fired from AuthService.logout). Do NOT try to refresh or re-trigger
      // logout, otherwise a 401 here loops back into onError forever.
      if (_isLoggingOut) {
        handler.next(err);
        return;
      }

      // Skip if this is the refresh endpoint itself
      if (options.path == ApiEndpoints.refreshToken) {
        await _handleLogout();
        handler.next(err);
        return;
      }

      // Add to pending requests if already refreshing
      if (_isRefreshing) {
        _pendingRequests.add(options);
        return;
      }

      try {
        await _refreshToken();

        // Retry the original request with new token
        final newToken = await _storage.read(key: AppConfig.accessTokenKey);
        if (newToken != null) {
          options.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(options);
          handler.resolve(response);

          // Retry pending requests
          _retryPendingRequests();
          return;
        }
      } catch (e) {
        // Refresh failed, logout
        await _handleLogout();
        _clearPendingRequests(err);
      }
    }

    handler.next(err);
  }

  /// Check if the endpoint is public (doesn't require auth)
  bool _isPublicEndpoint(String path) {
    return path == ApiEndpoints.login ||
        path == ApiEndpoints.register ||
        path == ApiEndpoints.refreshToken ||
        path == ApiEndpoints.googleToken ||
        path == ApiEndpoints.appleToken ||
        path == ApiEndpoints.forgotPassword ||
        path == ApiEndpoints.resetPassword;
  }

  /// Refresh the access token using the refresh token
  Future<void> _refreshToken() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final refreshToken = await _storage.read(key: AppConfig.refreshTokenKey);

      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      // Create a new Dio instance to avoid interceptor loop
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Store new tokens
        await _storage.write(
          key: AppConfig.accessTokenKey,
          value: data['access_token'] as String?,
        );

        final newRefresh = data['refresh_token'] as String?;
        if (newRefresh != null) {
          await _storage.write(
            key: AppConfig.refreshTokenKey,
            value: newRefresh,
          );
        }

        // Calculate and store new expiry
        final expiry = DateTime.now().add(AppConfig.accessTokenDuration);
        await _storage.write(
          key: AppConfig.accessTokenExpiryKey,
          value: expiry.toIso8601String(),
        );
      } else {
        throw Exception('Token refresh failed');
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Retry all pending requests with new token
  void _retryPendingRequests() async {
    final newToken = await _storage.read(key: AppConfig.accessTokenKey);

    for (final options in _pendingRequests) {
      if (newToken != null) {
        options.headers['Authorization'] = 'Bearer $newToken';
      }
      _dio.fetch(options);
    }

    _pendingRequests.clear();
  }

  /// Clear pending requests on error
  void _clearPendingRequests(DioException _) {
    _pendingRequests.clear();
  }

  /// Handle logout — notify the auth state notifier, which will:
  ///   1) clear secure-storage tokens via [AuthService.logout]
  ///   2) flip [authStateProvider] to unauthenticated
  ///   3) trigger the GoRouter redirect into the login screen.
  ///
  /// We deliberately use [Ref.read] here (not watch): the interceptor lives
  /// for the lifetime of the app and must not subscribe to auth changes.
  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      await _ref.read(authStateProvider.notifier).logout();
    } catch (e) {
      AppLogger.debug('Logout via auth notifier failed: $e');
      // Best-effort fallback: clear tokens directly so the app at least
      // can't keep using a dead session.
      await _storage.delete(key: AppConfig.accessTokenKey);
      await _storage.delete(key: AppConfig.refreshTokenKey);
      await _storage.delete(key: AppConfig.accessTokenExpiryKey);
      await _storage.delete(key: AppConfig.refreshTokenExpiryKey);
      await _storage.delete(key: AppConfig.currentUserKey);
    } finally {
      _isLoggingOut = false;
    }
  }
}
