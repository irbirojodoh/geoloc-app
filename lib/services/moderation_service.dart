import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/user.dart';

final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService(ref.watch(apiClientProvider));
});

/// Trust & safety: reports, blocks, and mutes
class ModerationService {
  final ApiClient _apiClient;

  ModerationService(this._apiClient);

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.reports,
      data: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Report failed',
      );
    }
  }

  Future<void> blockUser(String userId) async {
    final response = await _apiClient.post(ApiEndpoints.blockUser(userId));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Block failed',
      );
    }
  }

  Future<void> unblockUser(String userId) async {
    final response = await _apiClient.delete(ApiEndpoints.unblockUser(userId));
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Unblock failed',
      );
    }
  }

  Future<void> muteUser(String userId) async {
    final response = await _apiClient.post(ApiEndpoints.muteUser(userId));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Mute failed',
      );
    }
  }

  Future<void> unmuteUser(String userId) async {
    final response = await _apiClient.delete(ApiEndpoints.unmuteUser(userId));
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Unmute failed',
      );
    }
  }

  /// DELETE /api/v1/posts/:id — delete post authored by current user
  Future<bool> deletePost(String postId) async {
    final response = await _apiClient.delete<void>(
      ApiEndpoints.deletePost(postId),
    );
    return response.statusCode == 200;
  }

  Future<List<User>> fetchBlockedUsers() async {
    final response = await _apiClient.get(ApiEndpoints.getBlockedUsers);
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Failed to load blocked users',
      );
    }
    return _parseUserList(response.data);
  }

  Future<List<User>> fetchMutedUsers() async {
    final response = await _apiClient.get(ApiEndpoints.getMutedUsers);
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Failed to load muted users',
      );
    }
    return _parseUserList(response.data);
  }

  List<User> _parseUserList(dynamic data) {
    if (data is! Map<String, dynamic>) return [];
    final rawList =
        data['users'] as List<dynamic>? ??
        data['data'] as List<dynamic>? ??
        data['blocked'] as List<dynamic>? ??
        data['muted'] as List<dynamic>? ??
        [];
    return rawList
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
