import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
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
  final String? locationName; // e.g., "Kukusan, Depok"
  final bool isLoadingAddress;

  const CreatePostState({
    this.content = '',
    this.mediaFiles = const [],
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
    this.locationName,
    this.isLoadingAddress = false,
  });

  CreatePostState copyWith({
    String? content,
    List<File>? mediaFiles,
    bool? isSubmitting,
    bool? isSuccess,
    String? error,
    String? locationName,
    bool? isLoadingAddress,
  }) {
    return CreatePostState(
      content: content ?? this.content,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      locationName: locationName ?? this.locationName,
      isLoadingAddress: isLoadingAddress ?? this.isLoadingAddress,
    );
  }

  /// Check if post can be submitted
  bool get canSubmit => content.trim().isNotEmpty && !isSubmitting;
}

/// Create post notifier
class CreatePostNotifier extends StateNotifier<CreatePostState> {
  final ApiClient _apiClient;
  final Ref _ref;
  final ImagePicker _imagePicker = ImagePicker();

  CreatePostNotifier(this._apiClient, this._ref)
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

        // Format: "Village, City" or just location_name
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

      if (images.isNotEmpty) {
        final selectedFiles = images.map((xFile) => File(xFile.path)).toList();
        final limitedFiles = selectedFiles.take(remainingSlots).toList();
        state = state.copyWith(
          mediaFiles: [...state.mediaFiles, ...limitedFiles],
          error: selectedFiles.length > limitedFiles.length
              ? 'Only $kCreatePostMaxMediaCount images are allowed'
              : null,
        );
      }
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
        state = state.copyWith(
          mediaFiles: [...state.mediaFiles, File(image.path)],
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

    // Get current location
    final locationState = _ref.read(locationStateProvider);
    if (!locationState.hasLocation) {
      state = state.copyWith(error: 'Location is required to create a post');
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      // Upload media files first if any
      List<String> mediaUrls = [];
      for (final file in state.mediaFiles) {
        final uploadResponse = await _apiClient.uploadFile(
          ApiEndpoints.uploadPostMedia,
          filePath: file.path,
          fieldName: 'file',
        );

        if (uploadResponse.statusCode == 200 ||
            uploadResponse.statusCode == 201) {
          final data = uploadResponse.data as Map<String, dynamic>;
          final url = data['url'] as String? ?? data['media_url'] as String?;
          if (url != null) {
            mediaUrls.add(url);
          }
        }
      }

      // Create post
      final response = await _apiClient.post(
        ApiEndpoints.createPost,
        data: {
          'content': state.content.trim(),
          'latitude': locationState.latitude,
          'longitude': locationState.longitude,
          if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
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
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
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
      return CreatePostNotifier(apiClient, ref);
    });
