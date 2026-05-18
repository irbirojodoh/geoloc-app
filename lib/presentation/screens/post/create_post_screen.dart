import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/create_post_provider.dart';
import '../../providers/location_provider.dart';
import '../../../core/cache/image_cache_manager.dart';
import '../../../data/models/user.dart';

/// Create post screen.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  late final AnimationController _shakeController;

  static const int _warnCharThreshold = 290;
  bool _didShow290Alert = false;
  bool _didShow300Alert = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _showCharAlert(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1200),
        ),
      );
  }

  void _onContentChanged(String value) {
    final notifier = ref.read(createPostProvider.notifier);
    final previousLength = ref.read(createPostProvider).content.length;
    notifier.setContent(value);
    final currentLength = ref.read(createPostProvider).content.length;

    if (currentLength >= kCreatePostMaxContentLength) {
      if (!_didShow300Alert || previousLength < kCreatePostMaxContentLength) {
        _showCharAlert('You reached $kCreatePostMaxContentLength characters');
        _didShow300Alert = true;
      }
    } else if (previousLength < _warnCharThreshold &&
        currentLength >= _warnCharThreshold) {
      if (!_didShow290Alert) {
        _showCharAlert('Approaching limit: $currentLength/$kCreatePostMaxContentLength');
        _didShow290Alert = true;
      }
    }

    if (currentLength < _warnCharThreshold) {
      _didShow290Alert = false;
    }
    if (currentLength < kCreatePostMaxContentLength) {
      _didShow300Alert = false;
    }
  }

  void _onMaxLengthRejected() {
    if (!_shakeController.isAnimating) {
      _shakeController.forward(from: 0);
    }
  }

  Future<void> _submitPost() async {
    final success = await ref.read(createPostProvider.notifier).submitPost();
    if (success && mounted) {
      HapticFeedback.mediumImpact();
      context.pop(true);
    }
  }

  void _showMediaPicker() {
    final createPostState = ref.read(createPostProvider);
    if (createPostState.mediaFiles.length >= kCreatePostMaxMediaCount) {
      _showError('You can upload up to $kCreatePostMaxMediaCount images');
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add media',
              style: textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(Icons.camera_alt_outlined, size: 20, color: cs.primary),
              title: Text(
                'Take photo',
                style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(createPostProvider.notifier).pickImageFromCamera();
              },
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: cs.primary,
              ),
              title: Text(
                'Choose from gallery',
                style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(createPostProvider.notifier).pickImageFromGallery();
              },
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: textTheme.bodyMedium,
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(context, createPostState),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputSection(
                    context,
                    currentUser,
                    locationState: locationState,
                    createPostState: createPostState,
                  ),
                  if (createPostState.mediaFiles.isNotEmpty)
                    _buildMediaPreview(context, createPostState.mediaFiles),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomToolbar(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, CreatePostState state) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      backgroundColor: cs.surface.withValues(alpha: 0.88),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'Create Post',
        style: textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        tooltip: 'Close',
        onPressed: () => context.pop(),
        icon: const Icon(Icons.close),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            onPressed: state.canSubmit ? _submitPost : null,
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
                    'Post',
                    style: textTheme.labelLarge,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection(
    BuildContext context,
    User? currentUser, {
    required LocationState locationState,
    required CreatePostState createPostState,
  }) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentLength = createPostState.content.length;
    final isAtMaxLength = currentLength >= kCreatePostMaxContentLength;
    final showLocationTag =
        locationState.isLoading ||
        createPostState.isLoadingAddress ||
        locationState.hasLocation ||
        createPostState.locationName != null;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offsetX = math.sin(_shakeController.value * math.pi * 8) * 6;
        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: child,
        );
      },
      child: Card(
        margin: const EdgeInsets.all(12),
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isAtMaxLength ? cs.error : cs.outlineVariant,
            width: isAtMaxLength ? 1.4 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.outlineVariant, width: 1),
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
                      onChanged: _onContentChanged,
                      cursorColor: cs.primary,
                      maxLines: null,
                      minLines: 5,
                      inputFormatters: [
                        _MaxLengthWithFeedbackFormatter(
                          maxLength: kCreatePostMaxContentLength,
                          onRejected: _onMaxLengthRejected,
                        ),
                      ],
                      style: textTheme.bodyLarge,
                      decoration: InputDecoration(
                        filled: false,
                        hintText: "What's happening in your area?",
                        hintStyle: textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: showLocationTag
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 8),
                            child: _buildInlineLocationTag(
                              context,
                              locationState: locationState,
                              createPostState: createPostState,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: Text(
                      '$currentLength/$kCreatePostMaxContentLength',
                      style: textTheme.bodySmall?.copyWith(
                        color: isAtMaxLength ? cs.error : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context, List<File> mediaFiles) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        borderRadius: BorderRadius.circular(12),
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
                        top: 6,
                        right: 6,
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
                              shape: BoxShape.circle,
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

  Widget _buildInlineLocationTag(
    BuildContext context, {
    required LocationState locationState,
    required CreatePostState createPostState,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
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
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else if (locationState.hasLocation && createPostState.locationName != null)
          Expanded(
            child: Text(
              createPostState.locationName!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else if (locationState.hasLocation)
          Text(
            'Location available',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          GestureDetector(
            onTap: () {
              ref.read(locationStateProvider.notifier).requestPermission();
            },
            child: Text(
              'Enable location',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              IconButton(
                onPressed: _showMediaPicker,
                tooltip: 'Pick image from gallery',
                icon: const Icon(Icons.photo_outlined),
                color: cs.primary,
              ),
              IconButton(
                onPressed: () {
                  ref.read(createPostProvider.notifier).pickImageFromCamera();
                },
                tooltip: 'Take a photo',
                icon: const Icon(Icons.camera_alt_outlined),
                color: cs.primary,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Error',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
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

class _MaxLengthWithFeedbackFormatter extends TextInputFormatter {
  _MaxLengthWithFeedbackFormatter({
    required this.maxLength,
    required this.onRejected,
  });

  final int maxLength;
  final VoidCallback onRejected;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxLength) {
      return newValue;
    }
    onRejected();
    return oldValue;
  }
}
