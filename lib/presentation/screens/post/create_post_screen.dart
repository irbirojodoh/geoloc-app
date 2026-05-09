import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extensions.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/create_post_provider.dart';
import '../../providers/location_provider.dart';
import '../../../core/cache/image_cache_manager.dart';
import '../../../data/models/user.dart';

/// Create post screen — old-money luxury aesthetic
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final success = await ref.read(createPostProvider.notifier).submitPost();
    if (success && mounted) {
      HapticFeedback.mediumImpact();
      context.pop(true);
    }
  }

  void _showMediaPicker() {
    final cs = Theme.of(context).colorScheme;

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
              'ADD MEDIA',
              style: context.sectionLabel,
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.surface.withValues(alpha: 0),
                    cs.outline,
                    cs.surface.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(createPostProvider.notifier).pickImageFromCamera();
              },
              icon: Icon(Icons.camera_alt_outlined, size: 20, color: cs.primary),
              label: Text(
                'Take Photo',
                style: context.body,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(createPostProvider.notifier).pickImageFromGallery();
              },
              icon: Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: cs.primary,
              ),
              label: Text(
                'Choose from Gallery',
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
    final createPostState = ref.watch(createPostProvider);
    final currentUser = ref.watch(currentUserProvider);
    final locationState = ref.watch(locationStateProvider);

    ref.listen<CreatePostState>(createPostProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        _showError(next.error!);
      }
    });

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, createPostState),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputSection(context, currentUser),
                    if (createPostState.mediaFiles.isNotEmpty)
                      _buildMediaPreview(context, createPostState.mediaFiles),
                    _buildLocationSection(context, locationState),
                  ],
                ),
              ),
            ),
            _buildBottomToolbar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CreatePostState state) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.outline, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: cs.outline, width: 1),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Create Post',
                  style: context.appBarTitle,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: state.canSubmit ? _submitPost : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: state.canSubmit
                          ? cs.primary
                          : cs.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: state.isSubmitting
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: cs.onPrimary,
                            ),
                          )
                        : Text(
                            'POST',
                            style: context.caption,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(BuildContext context, User? currentUser) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: cs.outline, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.outline, width: 1),
            ),
            child: currentUser?.profilePictureUrl != null
                ? ClipOval(
                    child: Builder(
                      builder: (context) {
                        final dpr = MediaQuery.devicePixelRatioOf(context);
                        return CachedNetworkImage(
                          imageUrl: currentUser!.profilePictureUrl!,
                          fit: BoxFit.cover,
                          cacheManager: AvatarCacheManager.instance,
                          memCacheWidth: (44 * dpr).round(),
                          memCacheHeight: (44 * dpr).round(),
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              color: cs.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.person_outlined,
                            size: 24,
                            color: cs.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.person_outlined,
                    size: 24,
                    color: cs.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              onChanged: (value) {
                ref.read(createPostProvider.notifier).setContent(value);
              },
              cursorColor: cs.primary,
              maxLines: null,
              minLines: 5,
              style: context.body,
              decoration: InputDecoration(
                filled: false,
                hintText: "What's happening in your area?",
                hintStyle: context.body,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context, List<File> mediaFiles) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: mediaFiles.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < mediaFiles.length - 1 ? 8 : 0,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Image.file(
                          mediaFiles[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          // Decode at 120pt thumbnail size, not full source.
                          cacheWidth:
                              (120 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          cacheHeight:
                              (120 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            ref
                                .read(createPostProvider.notifier)
                                .removeMedia(index);
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: colorScheme.scrim.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    LocationState locationState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final createPostState = ref.watch(createPostProvider);

    ref.listen<LocationState>(locationStateProvider, (prev, next) {
      if (next.hasLocation && prev?.position != next.position) {
        ref
            .read(createPostProvider.notifier)
            .fetchAddress(next.latitude!, next.longitude!);
      }
    });

    if (locationState.hasLocation &&
        createPostState.locationName == null &&
        !createPostState.isLoadingAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(createPostProvider.notifier)
            .fetchAddress(locationState.latitude!, locationState.longitude!);
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          if (locationState.isLoading || createPostState.isLoadingAddress)
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Getting location...',
                  style: context.monoSmall,
                ),
              ],
            )
          else if (locationState.hasLocation &&
              createPostState.locationName != null)
            Expanded(
              child: Text(
                createPostState.locationName!,
                style: context.monoSmall,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (locationState.hasLocation)
            Text(
              'Location available',
              style: context.monoSmall,
            )
          else
            GestureDetector(
              onTap: () {
                ref.read(locationStateProvider.notifier).requestPermission();
              },
              child: Text(
                'Enable location',
                style: context.sheetItem.copyWith(color: colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showMediaPicker,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: cs.outline, width: 1),
              ),
              child: Icon(Icons.photo_outlined, size: 20, color: cs.primary),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              ref.read(createPostProvider.notifier).pickImageFromCamera();
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: cs.outline, width: 1),
              ),
              child: Icon(Icons.camera_alt_outlined, size: 20, color: cs.primary),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  void _showError(String message) {
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
          message,
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
}
