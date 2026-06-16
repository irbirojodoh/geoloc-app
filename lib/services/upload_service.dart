import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/upload_result.dart';

/// Provider for UploadService
final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(apiClientProvider));
});

/// Thrown when client-side or server-side upload validation fails.
class UploadException implements Exception {
  final String message;

  const UploadException(this.message);

  @override
  String toString() => message;
}

/// Allowed image extensions for R2 uploads.
const _allowedExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};

/// Service for handling R2 media uploads (Pattern A — server-side multipart).
class UploadService {
  final ApiClient _apiClient;

  UploadService(this._apiClient);

  /// Validate image file before upload (10MB max, JPEG/PNG/GIF/WebP only).
  void validateImageFile(File file) {
    final length = file.lengthSync();
    if (length > AppConfig.maxMediaSizeBytes) {
      throw UploadException(
        'Image must be ${AppConfig.maxMediaSizeMB}MB or smaller',
      );
    }

    final ext = _fileExtension(file.path);
    if (!_allowedExtensions.contains(ext)) {
      throw const UploadException(
        'Only JPEG, PNG, GIF, and WebP images are supported',
      );
    }
  }

  String _fileExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  /// Upload avatar image. Returns R2 key and resolved URL.
  Future<UploadResult> uploadAvatar(File imageFile) async {
    validateImageFile(imageFile);
    return _uploadFile(imageFile, ApiEndpoints.uploadAvatar);
  }

  /// Upload cover image. Returns R2 key and resolved URL.
  Future<UploadResult> uploadCover(File imageFile) async {
    validateImageFile(imageFile);
    return _uploadFile(imageFile, ApiEndpoints.uploadCover);
  }

  /// Upload a single post media image. Returns R2 key and resolved URL.
  Future<UploadResult> uploadPostMedia(
    File file, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    validateImageFile(file);
    return _uploadFile(
      file,
      ApiEndpoints.uploadPostMedia,
      onSendProgress: onSendProgress,
    );
  }

  Future<UploadResult> _uploadFile(
    File file,
    String endpoint, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    File processedFile = file;
    bool isTempFile = false;
    
    try {
      final processedPath = await compute(compressAndResizeImageIsolate, file.path);
      if (processedPath != file.path) {
        processedFile = File(processedPath);
        isTempFile = true;
      }
    } catch (_) {
      // Fallback to original file on any compression failure
      processedFile = file;
      isTempFile = false;
    }

    try {
      final response = await _apiClient.uploadFile(
        endpoint,
        filePath: processedFile.path,
        fieldName: 'file',
        onSendProgress: onSendProgress,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UploadResult.fromJson(response.data as Map<String, dynamic>);
      }

      throw const UploadException('Upload failed. Please try again.');
    } on DioException catch (e) {
      throw UploadException(_mapDioError(e));
    } on UploadException {
      rethrow;
    } on FormatException {
      throw const UploadException('Invalid upload response from server');
    } finally {
      if (isTempFile) {
        try {
          await processedFile.delete();
        } catch (_) {
          // Ignore temp file deletion failure
        }
      }
    }
  }

  String _mapDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    String? serverMessage;

    if (body is Map<String, dynamic>) {
      serverMessage = body['error'] as String? ?? body['message'] as String?;
    } else if (body is String) {
      serverMessage = body;
    }

    if (statusCode == 400) {
      final msg = serverMessage?.toLowerCase() ?? '';
      if (msg.contains('too large') || msg.contains('file size')) {
        return 'Image must be ${AppConfig.maxMediaSizeMB}MB or smaller';
      }
      if (msg.contains('invalid file type') || msg.contains('file type')) {
        return 'Only JPEG, PNG, GIF, and WebP images are supported';
      }
      return serverMessage ?? 'Invalid image file';
    }

    if (statusCode == 401) {
      return 'Session expired. Please log in again.';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'Upload failed. Please try again later.';
    }

    return serverMessage ?? 'Upload failed. Please try again.';
  }
}

/// Top-level function for background isolate image compression.
Future<String> compressAndResizeImageIsolate(String filePath) async {
  final file = File(filePath);
  final bytes = file.readAsBytesSync();
  img.Image? image;
  try {
    image = img.decodeImage(bytes);
  } catch (_) {
    return filePath;
  }
  if (image == null) {
    return filePath;
  }

  int originalWidth = image.width;
  int originalHeight = image.height;
  
  int longSide = originalWidth > originalHeight ? originalWidth : originalHeight;
  int shortSide = originalWidth > originalHeight ? originalHeight : originalWidth;
  
  double aspectRatio = longSide / shortSide;
  
  int targetWidth = originalWidth;
  int targetHeight = originalHeight;
  bool needsResize = false;
  
  if (aspectRatio <= 2.0) {
    // Normal aspect ratio: cap the long side to 2280
    const int maxLongSide = 2280;
    if (longSide > maxLongSide) {
      needsResize = true;
      if (originalWidth > originalHeight) {
        targetWidth = maxLongSide;
        targetHeight = (originalHeight * maxLongSide / originalWidth).round();
      } else {
        targetHeight = maxLongSide;
        targetWidth = (originalWidth * maxLongSide / originalHeight).round();
      }
    }
  } else {
    // Weird aspect ratio (e.g. panorama, banner, long screenshot):
    // Cap the short side to 1280 instead of long side to 2280
    const int maxShortSide = 1280;
    if (shortSide > maxShortSide) {
      needsResize = true;
      if (originalWidth > originalHeight) {
        // Landscape panorama
        targetHeight = maxShortSide;
        targetWidth = (originalWidth * maxShortSide / originalHeight).round();
      } else {
        // Portrait long screenshot
        targetWidth = maxShortSide;
        targetHeight = (originalHeight * maxShortSide / originalWidth).round();
      }
    }
  }
  
  img.Image processedImage = image;
  if (needsResize) {
    processedImage = img.copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
  }
  
  // Detect format based on original file extension
  final dot = filePath.lastIndexOf('.');
  final ext = dot < 0 || dot == filePath.length - 1 
      ? '' 
      : filePath.substring(dot + 1).toLowerCase();
      
  List<int> encodedBytes;
  String newExt;
  
  if (ext == 'png') {
    if (processedImage.hasAlpha) {
      encodedBytes = img.encodePng(processedImage);
      newExt = 'png';
    } else {
      encodedBytes = img.encodeJpg(processedImage, quality: 70);
      newExt = 'jpg';
    }
  } else if (ext == 'gif') {
    // Return original to keep animation intact
    return filePath;
  } else {
    encodedBytes = img.encodeJpg(processedImage, quality: 70);
    newExt = 'jpg';
  }
  
  final tempDir = Directory.systemTemp;
  final tempFile = File('${tempDir.path}/compressed_${DateTime.now().microsecondsSinceEpoch}.$newExt');
  tempFile.writeAsBytesSync(encodedBytes);
  
  return tempFile.path;
}
