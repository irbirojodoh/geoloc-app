import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../data/models/user.dart';
import '../../services/auth_service.dart';
import '../../services/upload_service.dart';
import 'auth_provider.dart';

/// Edit profile state
class EditProfileState {
  final User? originalUser;
  final String fullName;
  final String username;
  final String bio;
  final File? newProfileImage;
  final File? newCoverImage;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool saveSuccess;

  const EditProfileState({
    this.originalUser,
    this.fullName = '',
    this.username = '',
    this.bio = '',
    this.newProfileImage,
    this.newCoverImage,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.saveSuccess = false,
  });

  bool get hasChanges {
    if (originalUser == null) return false;
    return fullName != (originalUser!.fullName ?? '') ||
        username != originalUser!.username ||
        bio != (originalUser!.bio ?? '') ||
        newProfileImage != null ||
        newCoverImage != null;
  }

  EditProfileState copyWith({
    User? originalUser,
    String? fullName,
    String? username,
    String? bio,
    File? newProfileImage,
    File? newCoverImage,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool? saveSuccess,
    bool clearProfileImage = false,
    bool clearCoverImage = false,
    bool clearError = false,
  }) {
    return EditProfileState(
      originalUser: originalUser ?? this.originalUser,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      newProfileImage:
          clearProfileImage ? null : (newProfileImage ?? this.newProfileImage),
      newCoverImage:
          clearCoverImage ? null : (newCoverImage ?? this.newCoverImage),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }
}

/// Edit profile provider
final editProfileProvider =
    StateNotifierProvider<EditProfileNotifier, EditProfileState>((ref) {
  return EditProfileNotifier(
    ref.watch(authServiceProvider),
    ref.watch(uploadServiceProvider),
    ref,
  );
});

/// Edit profile state notifier
class EditProfileNotifier extends StateNotifier<EditProfileState> {
  final AuthService _authService;
  final UploadService _uploadService;
  final Ref _ref;
  final ImagePicker _picker = ImagePicker();

  EditProfileNotifier(this._authService, this._uploadService, this._ref)
      : super(const EditProfileState());

  /// Load current user profile for editing
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        state = state.copyWith(
          originalUser: user,
          fullName: user.fullName ?? '',
          username: user.username,
          bio: user.bio ?? '',
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load profile',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load profile: $e',
      );
    }
  }

  /// Update full name
  void updateFullName(String value) {
    state = state.copyWith(fullName: value, clearError: true);
  }

  /// Update username
  void updateUsername(String value) {
    state = state.copyWith(username: value, clearError: true);
  }

  /// Update bio
  void updateBio(String value) {
    state = state.copyWith(bio: value, clearError: true);
  }

  /// Pick profile image from gallery
  Future<void> pickProfileImageFromGallery() async {
    await _pickProfileImage(ImageSource.gallery);
  }

  /// Pick profile image from camera
  Future<void> pickProfileImageFromCamera() async {
    await _pickProfileImage(ImageSource.camera);
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Crop to square
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressQuality: 85,
          maxWidth: 500,
          maxHeight: 500,
          uiSettings: [
            IOSUiSettings(
              title: 'Crop Profile Photo',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          final file = File(croppedFile.path);
          try {
            _uploadService.validateImageFile(file);
            state = state.copyWith(newProfileImage: file);
          } on UploadException catch (e) {
            state = state.copyWith(error: e.message);
          }
        }
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick image');
    }
  }

  /// Pick cover image from gallery
  Future<void> pickCoverImageFromGallery() async {
    await _pickCoverImage(ImageSource.gallery);
  }

  /// Pick cover image from camera
  Future<void> pickCoverImageFromCamera() async {
    await _pickCoverImage(ImageSource.camera);
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Crop to 16:9 ratio
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
          compressQuality: 85,
          maxWidth: 1280,
          maxHeight: 720,
          uiSettings: [
            IOSUiSettings(
              title: 'Crop Cover Photo',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          final file = File(croppedFile.path);
          try {
            _uploadService.validateImageFile(file);
            state = state.copyWith(newCoverImage: file);
          } on UploadException catch (e) {
            state = state.copyWith(error: e.message);
          }
        }
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick image');
    }
  }

  /// Remove selected profile image
  void removeProfileImage() {
    state = state.copyWith(clearProfileImage: true);
  }

  /// Remove selected cover image
  void removeCoverImage() {
    state = state.copyWith(clearCoverImage: true);
  }

  /// Save profile changes
  Future<bool> saveProfile() async {
    if (!state.hasChanges) return true;

    state = state.copyWith(isSaving: true, clearError: true, saveSuccess: false);
    HapticFeedback.mediumImpact();

    try {
      String? avatarKey;
      String? coverKey;

      if (state.newProfileImage != null) {
        final result =
            await _uploadService.uploadAvatar(state.newProfileImage!);
        avatarKey = result.key;
      }

      if (state.newCoverImage != null) {
        final result = await _uploadService.uploadCover(state.newCoverImage!);
        coverKey = result.key;
      }

      final hasTextChanges =
          state.fullName != (state.originalUser?.fullName ?? '') ||
              state.username != state.originalUser?.username ||
              state.bio != (state.originalUser?.bio ?? '');

      if (hasTextChanges || avatarKey != null || coverKey != null) {
        await _ref.read(authStateProvider.notifier).updateProfile(
              fullName: state.fullName != (state.originalUser?.fullName ?? '')
                  ? state.fullName
                  : null,
              username: state.username != state.originalUser?.username
                  ? state.username
                  : null,
              bio: state.bio != (state.originalUser?.bio ?? '')
                  ? state.bio
                  : null,
              avatarKey: avatarKey,
              coverKey: coverKey,
            );
      }

      // Refresh profile from API so resolved R2 URLs are current
      final refreshedUser = await _authService.getCurrentUser();
      if (refreshedUser != null) {
        _ref.read(authStateProvider.notifier).updateUser(refreshedUser);
        state = state.copyWith(originalUser: refreshedUser);
      }

      state = state.copyWith(
        isSaving: false,
        saveSuccess: true,
        clearProfileImage: true,
        clearCoverImage: true,
      );

      HapticFeedback.heavyImpact();
      return true;
    } on UploadException catch (e) {
      state = state.copyWith(isSaving: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save profile: $e',
      );
      return false;
    }
  }

  /// Discard all changes
  void discardChanges() {
    if (state.originalUser != null) {
      state = EditProfileState(
        originalUser: state.originalUser,
        fullName: state.originalUser!.fullName ?? '',
        username: state.originalUser!.username,
        bio: state.originalUser!.bio ?? '',
      );
    }
  }

  /// Validate username format
  String? validateUsername(String value) {
    if (value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    if (value.length > 30) return 'Username must be less than 30 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  /// Validate full name format
  String? validateFullName(String value) {
    if (value.isEmpty) return 'Full name is required';
    if (value.length > 50) return 'Full name must be less than 50 characters';
    return null;
  }
}
