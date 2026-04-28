import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

/// Provider for UploadService
final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(apiClientProvider));
});

/// Service for handling file uploads
class UploadService {
  final ApiClient _apiClient;

  UploadService(this._apiClient);

  /// Upload avatar image
  /// Returns the URL of the uploaded avatar
  Future<String> uploadAvatar(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final response = await _apiClient.post(
      ApiEndpoints.uploadAvatar,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      return data['url'] as String? ?? data['profile_picture_url'] as String;
    }

    throw Exception('Failed to upload avatar: ${response.statusCode}');
  }

  /// Upload cover image
  /// Returns the URL of the uploaded cover
  Future<String> uploadCover(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    // Use upload avatar endpoint with cover type or dedicated endpoint
    final response = await _apiClient.post(
      '${ApiEndpoints.uploadAvatar}?type=cover',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      return data['url'] as String? ?? data['cover_image_url'] as String;
    }

    throw Exception('Failed to upload cover: ${response.statusCode}');
  }

  /// Upload post media files
  /// Returns list of URLs for uploaded files
  Future<List<String>> uploadPostMedia(List<File> files) async {
    final urls = <String>[];

    for (final file in files) {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'post_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _apiClient.post(
        ApiEndpoints.uploadPostMedia,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        urls.add(data['url'] as String);
      } else {
        throw Exception('Failed to upload media: ${response.statusCode}');
      }
    }

    return urls;
  }
}
