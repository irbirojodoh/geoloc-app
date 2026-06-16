import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../services/upload_service.dart';
import 'location_provider.dart';

const int kCreatePostMaxContentLength = 300;
const int kCreatePostMaxMediaCount = 4;

/// Create post state
class CreatePostState {
  final String content;
  final List<File> mediaFiles;
  final bool isSubmitting;
  final bool isSuccess;
  final String? error;
  final String? locationName;
  final bool isLoadingAddress;
  final int? uploadingMediaIndex;
  final double uploadProgress;

  const CreatePostState({
    this.content = '',
    this.mediaFiles = const [],
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
    this.locationName,
    this.isLoadingAddress = false,
    this.uploadingMediaIndex,
    this.uploadProgress = 0,
  });

  CreatePostState copyWith({
    String? content,
    List<File>? mediaFiles,
    bool? isSubmitting,
    bool? isSuccess,
    String? error,
    String? locationName,
    bool? isLoadingAddress,
    int? uploadingMediaIndex,
    double? uploadProgress,
    bool clearUploadProgress = false,
  }) {
    return CreatePostState(
      content: content ?? this.content,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      locationName: locationName ?? this.locationName,
      isLoadingAddress: isLoadingAddress ?? this.isLoadingAddress,
      uploadingMediaIndex: clearUploadProgress
          ? null
          : (uploadingMediaIndex ?? this.uploadingMediaIndex),
      uploadProgress: clearUploadProgress
          ? 0
          : (uploadProgress ?? this.uploadProgress),
    );
  }

  bool get canSubmit => content.trim().isNotEmpty && !isSubmitting;
}

/// Create post notifier
class CreatePostNotifier extends StateNotifier<CreatePostState> {
  final ApiClient _apiClient;
  final UploadService _uploadService;
  final Ref _ref;
  final ImagePicker _imagePicker = ImagePicker();

  CreatePostNotifier(this._apiClient, this._uploadService, this._ref)
    : super(const CreatePostState());

  /// Update post content
  void setContent(String content) {
    final nextContent = content.length > kCreatePostMaxContentLength
        ? content.substring(0, kCreatePostMaxContentLength)
        : content;
    state = state.copyWith(content: nextContent, error: null);
  }

  /// Fetch address from coordinates
  Future<void> fetchAddress(double latitude, double longitude) async {
    if (state.isLoadingAddress) return;

    state = state.copyWith(isLoadingAddress: true);

    try {
      final response = await _apiClient.get(
        ApiEndpoints.getAddress,
        queryParameters: {'lat': latitude, 'lng': longitude},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final locationName = data['location_name'] as String?;
        final address = data['address'] as Map<String, dynamic>?;

        String displayName;
        if (address != null) {
          final village =
              address['village'] as String? ??
              address['city_district'] as String? ??
              locationName ??
              '';
          final city = address['city'] as String? ?? '';
          final stateName = address['state'] as String? ?? '';

          final secondPart = city.isNotEmpty ? city : stateName;
          displayName = secondPart.isNotEmpty
              ? '$village, $secondPart'
              : village;
        } else {
          displayName = locationName ?? 'Unknown location';
        }

        state = state.copyWith(
          locationName: displayName,
          isLoadingAddress: false,
        );
      } else {
        state = state.copyWith(isLoadingAddress: false);
      }
    } catch (e) {
      state = state.copyWith(isLoadingAddress: false);
    }
  }

  String? _validatePickedFile(File file) {
    try {
      _uploadService.validateImageFile(file);
      return null;
    } on UploadException catch (e) {
      return e.message;
    }
  }

  /// Pick image from gallery
  Future<void> pickImageFromGallery() async {
    final remainingSlots = kCreatePostMaxMediaCount - state.mediaFiles.length;
    if (remainingSlots <= 0) {
      state = state.copyWith(
        error: 'You can upload up to $kCreatePostMaxMediaCount images',
      );
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      final validFiles = <File>[];
      String? validationError;

      for (final xFile in images) {
        if (validFiles.length >= remainingSlots) break;
        final file = File(xFile.path);
        final error = _validatePickedFile(file);
        if (error != null) {
          validationError = error;
          continue;
        }
        validFiles.add(file);
      }

      if (validFiles.isEmpty) {
        state = state.copyWith(
          error: validationError ?? 'No valid images selected',
        );
        return;
      }

      state = state.copyWith(
        mediaFiles: [...state.mediaFiles, ...validFiles],
        error: validationError ??
            (images.length > validFiles.length
                ? 'Only $kCreatePostMaxMediaCount images are allowed'
                : null),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick images');
    }
  }

  /// Pick image from camera
  Future<void> pickImageFromCamera() async {
    if (state.mediaFiles.length >= kCreatePostMaxMediaCount) {
      state = state.copyWith(
        error: 'You can upload up to $kCreatePostMaxMediaCount images',
      );
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final validationError = _validatePickedFile(file);
        if (validationError != null) {
          state = state.copyWith(error: validationError);
          return;
        }

        state = state.copyWith(
          mediaFiles: [...state.mediaFiles, file],
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to capture image');
    }
  }

  /// Remove media at index
  void removeMedia(int index) {
    if (index >= 0 && index < state.mediaFiles.length) {
      final newFiles = List<File>.from(state.mediaFiles);
      newFiles.removeAt(index);
      state = state.copyWith(mediaFiles: newFiles);
    }
  }

  /// Submit post
  Future<bool> submitPost() async {
    if (!state.canSubmit) return false;
    if (state.content.trim().length > kCreatePostMaxContentLength) {
      state = state.copyWith(
        error: 'Post must be at most $kCreatePostMaxContentLength characters',
      );
      return false;
    }

    final locationState = _ref.read(locationStateProvider);
    if (!locationState.hasLocation) {
      state = state.copyWith(error: 'Location is required to create a post');
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      error: null,
      clearUploadProgress: true,
    );

    try {
      final mediaKeys = <String>[];

      for (var i = 0; i < state.mediaFiles.length; i++) {
        final file = state.mediaFiles[i];
        state = state.copyWith(
          uploadingMediaIndex: i,
          uploadProgress: 0,
        );

        final result = await _uploadService.uploadPostMedia(
          file,
          onSendProgress: (sent, total) {
            if (total > 0) {
              state = state.copyWith(uploadProgress: sent / total);
            }
          },
        );
        mediaKeys.add(result.key);
      }

      state = state.copyWith(clearUploadProgress: true);

      final response = await _apiClient.post(
        ApiEndpoints.createPost,
        data: {
          'content': state.content.trim(),
          'latitude': locationState.latitude,
          'longitude': locationState.longitude,
          if (mediaKeys.isNotEmpty) 'media_keys': mediaKeys,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(isSubmitting: false, isSuccess: true);
        return true;
      } else {
        state = state.copyWith(
          isSubmitting: false,
          error: 'Failed to create post',
        );
        return false;
      }
    } on UploadException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        clearUploadProgress: true,
        error: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        clearUploadProgress: true,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const CreatePostState();
  }
}

/// Create post provider
final createPostProvider =
    StateNotifierProvider.autoDispose<CreatePostNotifier, CreatePostState>((
      ref,
    ) {
      final apiClient = ref.read(apiClientProvider);
      final uploadService = ref.read(uploadServiceProvider);
      return CreatePostNotifier(apiClient, uploadService, ref);
    });
