import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../core/errors/failures.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/auth_tokens.dart';
import '../data/models/user.dart';

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

/// Authentication service handling login, register, token management
class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthService(this._apiClient);

  /// Register a new user
  Future<User> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Store tokens if returned
        if (data['access_token'] != null) {
          await _storeTokens(AuthTokens.fromJson(data));
        }

        // Store user
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await _storeCurrentUser(user);

        return user;
      }

      throw const ServerFailure(message: 'Registration failed');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Login with email/username and password
  Future<User> login({required String email, required String password}) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {'identifier': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Store tokens first
        await _storeTokens(AuthTokens.fromJson(data));

        // Fetch full user profile from /api/v1/users/me
        final user = await fetchCurrentUserFromApi();
        if (user != null) {
          return user;
        }

        // Fallback to login response user if API call fails
        final loginUser = User.fromJson(data['user'] as Map<String, dynamic>);
        await _storeCurrentUser(loginUser);
        return loginUser;
      }

      throw const InvalidCredentialsFailure();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Refresh the access token
  Future<AuthTokens> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConfig.refreshTokenKey);

      if (refreshToken == null) {
        throw const TokenExpiredFailure();
      }

      final response = await _apiClient.post(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final tokens = AuthTokens.fromJson(
          response.data as Map<String, dynamic>,
        );
        await _storeTokens(tokens);
        return tokens;
      }

      throw const TokenExpiredFailure();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        throw const TokenExpiredFailure();
      }
      throw _handleDioError(e);
    }
  }

  /// Logout - clear all stored data
  Future<void> logout() async {
    await _storage.delete(key: AppConfig.accessTokenKey);
    await _storage.delete(key: AppConfig.refreshTokenKey);
    await _storage.delete(key: AppConfig.accessTokenExpiryKey);
    await _storage.delete(key: AppConfig.refreshTokenExpiryKey);
    await _storage.delete(key: AppConfig.currentUserKey);
  }

  /// Get the current logged-in user from storage
  Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: AppConfig.currentUserKey);
    if (userJson == null) return null;

    try {
      return User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Fetch current user from API (includes profile_picture_url)
  Future<User?> fetchCurrentUserFromApi() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.getCurrentUser);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        // Handle nested 'user' field
        final userJson = data['user'] as Map<String, dynamic>? ?? data;
        final user = User.fromJson(userJson);
        await _storeCurrentUser(user);
        return user;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is authenticated (has valid tokens)
  Future<bool> isAuthenticated() async {
    final accessToken = await _storage.read(key: AppConfig.accessTokenKey);
    final refreshToken = await _storage.read(key: AppConfig.refreshTokenKey);

    if (accessToken == null && refreshToken == null) {
      return false;
    }

    // Check if refresh token is still valid
    final refreshExpiry = await _storage.read(
      key: AppConfig.refreshTokenExpiryKey,
    );
    if (refreshExpiry != null) {
      final expiry = DateTime.parse(refreshExpiry);
      if (DateTime.now().isAfter(expiry)) {
        await logout();
        return false;
      }
    }

    return true;
  }

  /// Get stored access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConfig.accessTokenKey);
  }

  /// Store tokens securely
  Future<void> _storeTokens(AuthTokens tokens) async {
    await _storage.write(
      key: AppConfig.accessTokenKey,
      value: tokens.accessToken,
    );
    await _storage.write(
      key: AppConfig.refreshTokenKey,
      value: tokens.refreshToken,
    );
    await _storage.write(
      key: AppConfig.accessTokenExpiryKey,
      value: tokens.accessTokenExpiry.toIso8601String(),
    );
    await _storage.write(
      key: AppConfig.refreshTokenExpiryKey,
      value: tokens.refreshTokenExpiry.toIso8601String(),
    );
  }

  /// Store current user
  Future<void> _storeCurrentUser(User user) async {
    await _storage.write(
      key: AppConfig.currentUserKey,
      value: jsonEncode(user.toJson()),
    );
  }

  /// Handle Dio errors and convert to Failures
  Failure _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure(message: 'Connection timed out');
    }

    if (e.type == DioExceptionType.connectionError) {
      return const NetworkFailure(message: 'No internet connection');
    }

    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;
      final message = data is Map ? data['error'] as String? : null;

      switch (statusCode) {
        case 400:
          return ValidationFailure(message: message ?? 'Invalid request');
        case 401:
          return InvalidCredentialsFailure(
            message: message ?? 'Authentication failed',
          );
        case 403:
          return const AuthFailure(message: 'Access denied');
        case 404:
          return NotFoundFailure(message: message ?? 'Not found');
        case 429:
          return const RateLimitFailure();
        default:
          if (statusCode != null && statusCode >= 500) {
            return ServerFailure(
              message: message ?? 'Server error',
              statusCode: statusCode,
            );
          }
          return ClientFailure(
            message: message ?? 'Request failed',
            statusCode: statusCode,
          );
      }
    }

    return const UnknownFailure();
  }
}
