import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../config/app_config.dart';
import '../core/media/media_content_type.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/presigned_upload_url.dart';
import '../data/models/upload_result.dart';
import 'media_service.dart';

/// Provider for UploadService
final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(
    ref.watch(apiClientProvider),
    ref.watch(mediaServiceProvider),
  );
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

/// Plain Dio client for direct R2 PUT — no API auth interceptor.
final Dio _r2UploadClient = Dio(
  BaseOptions(
    connectTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(minutes: 10),
    receiveTimeout: const Duration(minutes: 2),
  ),
);

/// Service for R2 media uploads.
///
/// Uses Pattern B (presigned PUT to R2) by default; falls back to Pattern A
/// (server-side multipart) when the presigned flow fails.
class UploadService {
  final ApiClient _apiClient;
  final MediaService _mediaService;

  UploadService(this._apiClient, this._mediaService);

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

  /// Upload avatar image. Returns R2 key and optional preview URL.
  Future<UploadResult> uploadAvatar(File imageFile) async {
    validateImageFile(imageFile);
    return _uploadFile(imageFile, folder: 'avatars');
  }

  /// Upload cover image. Returns R2 key and optional preview URL.
  Future<UploadResult> uploadCover(File imageFile) async {
    validateImageFile(imageFile);
    return _uploadFile(imageFile, folder: 'covers');
  }

  /// Upload a single post media image. Returns R2 key and optional preview URL.
  Future<UploadResult> uploadPostMedia(
    File file, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    validateImageFile(file);
    return _uploadFile(
      file,
      folder: 'posts',
      onSendProgress: onSendProgress,
    );
  }

  /// Delete an owned R2 object by key.
  Future<void> deleteMedia(String key) async {
    await _mediaService.deleteObject(key);
  }

  Future<UploadResult> _uploadFile(
    File file, {
    required String folder,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    File processedFile = file;
    var isTempFile = false;

    try {
      final processedPath =
          await compute(compressAndResizeImageIsolate, file.path);
      if (processedPath != file.path) {
        processedFile = File(processedPath);
        isTempFile = true;
      }
    } catch (_) {
      processedFile = file;
      isTempFile = false;
    }

    try {
      return await _uploadDirectToR2(
        processedFile,
        folder: folder,
        onSendProgress: onSendProgress,
      );
    } on UploadException {
      rethrow;
    } catch (_) {
      return _uploadViaApi(
        processedFile,
        folder: folder,
        onSendProgress: onSendProgress,
      );
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

  /// Pattern B — presigned PUT directly to R2.
  Future<UploadResult> _uploadDirectToR2(
    File file, {
    required String folder,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final contentType = MediaContentType.forPath(file.path);
    final filename = MediaContentType.filenameFromPath(file.path);

    final presigned = await _requestPresignedUploadUrl(
      folder: folder,
      contentType: contentType,
      filename: filename,
    );

    final bytes = await file.readAsBytes();
    await putToR2(
      presigned.uploadUrl,
      bytes,
      contentType,
      onSendProgress: onSendProgress,
    );

    return _resultFromKey(presigned.key);
  }

  /// Pattern A fallback — server-side multipart upload.
  Future<UploadResult> _uploadViaApi(
    File file, {
    required String folder,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final endpoint = switch (folder) {
      'avatars' => ApiEndpoints.uploadAvatar,
      'covers' => ApiEndpoints.uploadCover,
      _ => ApiEndpoints.uploadPostMedia,
    };

    final response = await _apiClient.uploadFile(
      endpoint,
      filePath: file.path,
      fieldName: 'file',
      onSendProgress: onSendProgress,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return UploadResult.fromJson(response.data as Map<String, dynamic>);
    }

    throw const UploadException('Upload failed. Please try again.');
  }

  Future<PresignedUploadUrl> _requestPresignedUploadUrl({
    required String folder,
    required String contentType,
    required String filename,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mediaUploadUrl,
        data: {
          'folder': folder,
          'content_type': contentType,
          'filename': filename,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PresignedUploadUrl.fromJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw const UploadException('Could not prepare upload. Please try again.');
    } on DioException catch (e) {
      throw UploadException(_mapDioError(e));
    } on FormatException {
      throw const UploadException('Invalid upload URL response from server');
    }
  }

  /// PUT raw bytes to R2 using a presigned URL (no JWT).
  static Future<void> putToR2(
    String uploadUrl,
    Uint8List bytes,
    String contentType, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      await _r2UploadClient.put<void>(
        uploadUrl,
        data: bytes,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {'Content-Type': contentType},
          contentType: contentType,
        ),
      );
    } on DioException catch (e) {
      throw UploadException(_mapDioErrorStatic(e));
    }
  }

  Future<UploadResult> _resultFromKey(String key) async {
    try {
      final signed = await _mediaService.signUrl(key);
      return UploadResult(key: key, url: signed.url);
    } catch (_) {
      return UploadResult(key: key, url: '');
    }
  }

  String _mapDioError(DioException e) => _mapDioErrorStatic(e);

  static String _mapDioErrorStatic(DioException e) {
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

  int longSide =
      originalWidth > originalHeight ? originalWidth : originalHeight;
  int shortSide =
      originalWidth > originalHeight ? originalHeight : originalWidth;

  double aspectRatio = longSide / shortSide;

  int targetWidth = originalWidth;
  int targetHeight = originalHeight;
  bool needsResize = false;

  if (aspectRatio <= 2.0) {
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
    const int maxShortSide = 1280;
    if (shortSide > maxShortSide) {
      needsResize = true;
      if (originalWidth > originalHeight) {
        targetHeight = maxShortSide;
        targetWidth = (originalWidth * maxShortSide / originalHeight).round();
      } else {
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
    return filePath;
  } else {
    encodedBytes = img.encodeJpg(processedImage, quality: 70);
    newExt = 'jpg';
  }

  final tempDir = Directory.systemTemp;
  final tempFile = File(
    '${tempDir.path}/compressed_${DateTime.now().microsecondsSinceEpoch}.$newExt',
  );
  tempFile.writeAsBytesSync(encodedBytes);

  return tempFile.path;
}
