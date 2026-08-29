import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failures.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/username.dart';

/// Typed client for the three username endpoints.
abstract class UsernameApi {
  Future<UsernameAvailability> checkAvailability(
    String username, {
    CancelToken? cancelToken,
  });

  Future<UsernameChangeResult> changeUsername(String username);

  Future<UsernameHistory> getHistory({int limit = 50});
}

final usernameServiceProvider = Provider<UsernameApi>((ref) {
  return UsernameService(ref.watch(apiClientProvider));
});

class UsernameService implements UsernameApi {
  UsernameService(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<UsernameAvailability> checkAvailability(
    String username, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.usernameAvailable,
        queryParameters: {'username': username},
        cancelToken: cancelToken,
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return UsernameAvailability.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw const ServerFailure(message: 'Could not check username');
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw _mapError(e);
    }
  }

  @override
  Future<UsernameChangeResult> changeUsername(String username) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.changeUsername,
        data: {'username': username},
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return UsernameChangeResult.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw const ServerFailure(message: 'Could not change username');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<UsernameHistory> getHistory({int limit = 50}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.usernameHistory,
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return UsernameHistory.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw const ServerFailure(message: 'Could not load username history');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Failure _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure(message: 'Connection timed out');
    }
    if (e.type == DioExceptionType.connectionError) {
      return const NetworkFailure(message: 'No internet connection');
    }

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    final error = data is Map
        ? (data['error'] as String? ?? data['message'] as String?)
        : null;

    switch (statusCode) {
      case 400:
        return ValidationFailure(
          message: error ?? 'Invalid username',
          fieldErrors: {'username': error ?? 'Invalid username'},
        );
      case 403:
        return AuthFailure(message: error ?? 'This account cannot be modified');
      case 409:
        return UsernameTakenFailure(
          message: error ?? 'This username is already taken',
        );
      case 429:
        DateTime? lastChangedAt;
        DateTime? nextChangeAt;
        if (data is Map) {
          lastChangedAt = _tryParseDate(data['last_changed_at']);
          nextChangeAt = _tryParseDate(data['next_change_at']);
        }
        if (nextChangeAt != null) {
          return UsernameCooldownFailure(
            nextChangeAt: nextChangeAt,
            lastChangedAt: lastChangedAt,
            message: error ?? 'You cannot change your username yet',
          );
        }
        return RateLimitFailure(
          message: error ?? 'You cannot change your username yet',
        );
      default:
        if (statusCode != null && statusCode >= 500) {
          return ServerFailure(
            message: error ?? 'Server error',
            statusCode: statusCode,
          );
        }
        return ClientFailure(
          message: error ?? 'Request failed',
          statusCode: statusCode,
        );
    }
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
