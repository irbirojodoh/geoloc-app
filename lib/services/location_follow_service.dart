import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failures.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/location_follow.dart';

/// Typed client for location-follow endpoints.
///
/// Unfollow identifies a row by `geohash_prefix` from the latest
/// `GET /locations/following` — never a client-computed or cached prefix.
abstract class LocationFollowApi {
  Future<List<LocationFollow>> getFollowing();

  Future<LocationFollow> follow({
    required double latitude,
    required double longitude,
    String? name,
  });

  /// [geohashPrefix] must be the server-owned identifier from [getFollowing].
  Future<void> unfollow(String geohashPrefix);
}

final locationFollowServiceProvider = Provider<LocationFollowApi>((ref) {
  return LocationFollowService(ref.watch(apiClientProvider));
});

class LocationFollowService implements LocationFollowApi {
  LocationFollowService(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<LocationFollow>> getFollowing() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.getFollowedLocations);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return parseFollowingResponse(response.data as Map<String, dynamic>);
      }
      throw const ServerFailure(message: 'Could not load followed locations');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<LocationFollow> follow({
    required double latitude,
    required double longitude,
    String? name,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.followLocation,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'name': ?name,
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final location = data['location'] as Map<String, dynamic>? ?? data;
        return LocationFollow.fromJson(location);
      }
      throw const ServerFailure(message: 'Could not follow location');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> unfollow(String geohashPrefix) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.unfollowLocation(geohashPrefix),
      );
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throw const ServerFailure(message: 'Could not unfollow location');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static List<LocationFollow> parseFollowingResponse(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['locations'] as List<dynamic>? ??
        data['data'] as List<dynamic>? ??
        const [];
    return raw
        .whereType<Map>()
        .map((item) => LocationFollow.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Failure _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure(message: 'Request timed out');
    }
    if (e.type == DioExceptionType.connectionError) {
      return const NetworkFailure(message: 'No internet connection');
    }
    final status = e.response?.statusCode;
    if (status != null && status >= 500) {
      return ServerFailure(message: 'Server error', statusCode: status);
    }
    return ClientFailure(
      message: e.message ?? 'Request failed',
      statusCode: status,
    );
  }
}
