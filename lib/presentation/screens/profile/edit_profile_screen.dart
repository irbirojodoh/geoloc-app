import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../widgets/auth_network_image.dart';

import '../../../core/cache/image_cache_manager.dart';
import '../../providers/edit_profile_provider.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/top_bar_backdrop.dart';
import '../../widgets/user_avatar.dart';

/// Edit profile screen.
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
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
              style: TextStyle(color: cs.primary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(editProfileProvider.notifier).discardChanges();
              this.context.pop();
            },
            child: Text(
              'Discard',
              style: TextStyle(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePickerSheet({required bool isProfileImage}) {
    final cs = Theme.of(context).colorScheme;
    showAppBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isProfileImage ? 'Profile photo' : 'Cover photo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Icon(Icons.camera_alt_outlined, color: cs.primary),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                if (isProfileImage) {
                  ref.read(editProfileProvider.notifier).pickProfileImageFromCamera();
                } else {
                  ref.read(editProfileProvider.notifier).pickCoverImageFromCamera();
                }
              },
            ),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Icon(Icons.photo_library_outlined, color: cs.primary),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(context);
                if (isProfileImage) {
                  ref.read(editProfileProvider.notifier).pickProfileImageFromGallery();
                } else {
                  ref.read(editProfileProvider.notifier).pickCoverImageFromGallery();
                }
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<EditProfileState>(editProfileProvider, (prev, next) {
      if (prev?.isLoading == true && !next.isLoading) {
        _syncControllers(next);
      }
      if (next.error != null && prev?.error != next.error) {
        _showError(next.error!);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(context, state),
      body: state.isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colorScheme.primary,
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    _buildCoverSection(context, state),
                    _buildFormFields(context, state),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, EditProfileState state) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      flexibleSpace: TopBarBackdrop(
        blurTintColor: cs.surface,
        blendColor: cs.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      leading: IconButton(
        tooltip: 'Close',
        onPressed: _showDiscardDialog,
        icon: const Icon(Icons.close),
      ),
      title: Text(
        'Edit Profile',
        style: textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            onPressed: state.isSaving || !state.hasChanges ? null : _saveProfile,
            child: state.isSaving
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: cs.onPrimary,
                    ),
                  )
                : Text(
                    'Save',
                    style: textTheme.labelLarge,
                  ),
          ),
        ),
      ],
    );
  }

  void _showError(String error) {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
              style: TextStyle(color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection(BuildContext context, EditProfileState state) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const double coverHeight = 160;
    const double avatarSize = 80;
    const double avatarOverlap = 40;

    final hasCover = state.newCoverImage != null ||
        (state.originalUser?.coverImageUrl?.trim().isNotEmpty ?? false);

    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: coverHeight,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _showImagePickerSheet(isProfileImage: false),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
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
                          AuthNetworkImage(
                            imageUrl: state.originalUser!.coverImageUrl!,
                            fit: BoxFit.cover,
                            cacheManager: PostImageCacheManager.instance,
                          )
                        else
                          Center(
                            child: Icon(
                              Icons.landscape_outlined,
                              color: cs.onSecondaryContainer,
                              size: 28,
                            ),
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                cs.scrim.withValues(alpha: 0),
                                cs.scrim.withValues(alpha: hasCover ? 0.35 : 0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _EditPhotoChip(
                    label: 'Edit cover',
                    onTap: () => _showImagePickerSheet(isProfileImage: false),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: -avatarOverlap,
                  child: GestureDetector(
                    onTap: () => _showImagePickerSheet(isProfileImage: true),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 3),
                          ),
                          child: _buildAvatar(state, avatarSize),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              color: cs.onSurfaceVariant,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 56),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Tap your photo or cover to update',
              style: textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
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

  InputDecoration _fieldDecoration(
    BuildContext context, {
    String? hintText,
    String? prefixText,
    TextStyle? prefixStyle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildFormFields(BuildContext context, EditProfileState state) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Full name'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _fullNameController,
                    style: context.body,
                    decoration: _fieldDecoration(
                      context,
                      hintText: 'Enter your full name',
                    ),
                    onChanged:
                        ref.read(editProfileProvider.notifier).updateFullName,
                    validator: (value) => ref
                        .read(editProfileProvider.notifier)
                        .validateFullName(value ?? ''),
                  ),
                  const SizedBox(height: 24),
                  _buildFieldLabel('Username'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _usernameController,
                    style: context.body,
                    decoration: _fieldDecoration(
                      context,
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
                  _buildFieldLabel('Bio'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 150,
                    style: context.body,
                    decoration: _fieldDecoration(
                      context,
                      hintText: 'Write a short bio...',
                    ),
                    onChanged: ref.read(editProfileProvider.notifier).updateBio,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: OutlinedButton.icon(
            onPressed: () => context.push(RoutePaths.settings),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Account & privacy settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EditPhotoChip extends StatelessWidget {
  const _EditPhotoChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: cs.surface.withValues(alpha: 0.92),
      elevation: 1,
      shadowColor: cs.scrim.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 15,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
