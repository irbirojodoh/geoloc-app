import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';
import '../../../core/theme/theme_extensions.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/cache/image_cache_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/edit_profile_provider.dart';
import '../../widgets/user_avatar.dart';

/// Edit profile screen — old-money luxury aesthetic
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(editProfileProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _syncControllers(EditProfileState state) {
    if (_fullNameController.text != state.fullName) {
      _fullNameController.text = state.fullName;
    }
    if (_usernameController.text != state.username) {
      _usernameController.text = state.username;
    }
    if (_bioController.text != state.bio) {
      _bioController.text = state.bio;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(editProfileProvider.notifier).saveProfile();
    if (success && mounted) {
      context.pop(true);
    }
  }

  void _showDiscardDialog() {
    final state = ref.read(editProfileProvider);
    if (!state.hasChanges) {
      context.pop();
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        title: Text(
          'Discard Changes?',
          style: context.textTheme.headlineSmall,
        ),
        content: Text(
          'You have unsaved changes. Are you sure you want to discard them?',
          style: context.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep Editing',
              style: TextStyle(color: gold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(editProfileProvider.notifier).discardChanges();
              this.context.pop();
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePickerSheet({required bool isProfileImage}) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isProfileImage ? 'PROFILE PHOTO' : 'COVER PHOTO',
              style: context.sectionLabel,
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    cs.outline,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (isProfileImage) {
                  ref
                      .read(editProfileProvider.notifier)
                      .pickProfileImageFromCamera();
                } else {
                  ref
                      .read(editProfileProvider.notifier)
                      .pickCoverImageFromCamera();
                }
              },
              icon: Icon(Icons.camera_alt_outlined, size: 20, color: gold),
              label: Text(
                'Take Photo',
                style: context.body,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (isProfileImage) {
                  ref
                      .read(editProfileProvider.notifier)
                      .pickProfileImageFromGallery();
                } else {
                  ref
                      .read(editProfileProvider.notifier)
                      .pickCoverImageFromGallery();
                }
              },
              icon:
                  Icon(Icons.photo_library_outlined, size: 20, color: gold),
              label: Text(
                'Choose from Library',
                style: context.body,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: context.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileProvider);
    final gold = AppColors.gold(context);

    ref.listen<EditProfileState>(editProfileProvider, (prev, next) {
      if (prev?.isLoading == true && !next.isLoading) {
        _syncControllers(next);
      }
      if (next.error != null && prev?.error != next.error) {
        _showError(next.error!);
      }
    });

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: state.isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: gold,
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildHeader(context, state),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildCoverSection(context, state),
                            _buildFormFields(context, state),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showError(String error) {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        title: Text(
          'Error',
          style: context.textTheme.headlineSmall,
        ),
        content: Text(
          error,
          style: context.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.gold(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, EditProfileState state) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return Container(
      color: cs.surface,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.outline, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showDiscardDialog,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: cs.outline, width: 1),
                    ),
                    child: Icon(
                      Icons.close,
                      color: cs.onSurface,
                      size: 18,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Edit Profile',
                      style: context.appBarTitle,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: state.isSaving || !state.hasChanges
                      ? null
                      : _saveProfile,
                  child: state.isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: gold,
                          ),
                        )
                      : Text(
                          'Save',
                          style: context.link,
                        ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection(BuildContext context, EditProfileState state) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);
    const double coverHeight = 150;
    const double avatarSize = 100;
    const double avatarOverlap = avatarSize / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover image
        GestureDetector(
          onTap: () => _showImagePickerSheet(isProfileImage: false),
          child: Container(
            height: coverHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gold.withValues(alpha: 0.15),
                  cs.surface,
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (state.newCoverImage != null)
                  Image.file(
                    state.newCoverImage!,
                    fit: BoxFit.cover,
                  )
                else if (state.originalUser?.coverImageUrl != null)
                  CachedNetworkImage(
                    imageUrl: state.originalUser!.coverImageUrl!,
                    fit: BoxFit.cover,
                    cacheManager: PostImageCacheManager.instance,
                  ),
                // Edit overlay
                Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  child: Center(
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Profile picture
        Positioned(
          bottom: -avatarOverlap,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => _showImagePickerSheet(isProfileImage: true),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 4),
                    ),
                    child: _buildAvatar(state, avatarSize),
                  ),
                  // Camera overlay
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: coverHeight + avatarOverlap + 16),
      ],
    );
  }

  Widget _buildAvatar(EditProfileState state, double size) {
    if (state.newProfileImage != null) {
      return ClipOval(
        child: Image.file(
          state.newProfileImage!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return UserAvatar(
      imageUrl: state.originalUser?.profilePictureUrl,
      name: state.originalUser?.username ?? 'U',
      size: size,
    );
  }

  Widget _buildFormFields(BuildContext context, EditProfileState state) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 70, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name
          _buildFieldLabel('FULL NAME', gold),
          const SizedBox(height: 8),
          TextFormField(
            controller: _fullNameController,
            style: context.body,
            decoration: const InputDecoration(
              hintText: 'Enter your full name',
            ),
            onChanged:
                ref.read(editProfileProvider.notifier).updateFullName,
            validator: (value) => ref
                .read(editProfileProvider.notifier)
                .validateFullName(value ?? ''),
          ),
          const SizedBox(height: 24),

          // Username
          _buildFieldLabel('USERNAME', gold),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            style: context.body,
            decoration: InputDecoration(
              hintText: 'Enter your username',
              prefixText: '@',
              prefixStyle: context.monoCaption,
            ),
            onChanged:
                ref.read(editProfileProvider.notifier).updateUsername,
            validator: (value) => ref
                .read(editProfileProvider.notifier)
                .validateUsername(value ?? ''),
          ),
          const SizedBox(height: 24),

          // Bio
          _buildFieldLabel('BIO', gold),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 150,
            style: context.body,
            decoration: const InputDecoration(
              hintText: 'Write a short bio...',
              counterText: '',
            ),
            onChanged: ref.read(editProfileProvider.notifier).updateBio,
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () => context.push(RoutePaths.settings),
              child: Text(
                'Account & privacy settings',
                style: context.link,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Text(
      label,
      style: context.textTheme.headlineSmall,
    );
  }
}
