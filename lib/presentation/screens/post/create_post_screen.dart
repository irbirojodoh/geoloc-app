import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/create_post_provider.dart';
import '../../providers/location_provider.dart';
import '../../../core/cache/image_cache_manager.dart';
import '../../../data/models/user.dart';

// ============================================================================
// Dynamic Colors for Light/Dark Mode Adaptation
// ============================================================================

const _cardBackgroundStart = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF0F4F8),
  darkColor: Color(0xFF2C2C2E),
);

const _cardBackgroundEnd = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFFFFFF),
  darkColor: Color(0xFF1C1C1E),
);

/// Create post screen
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
    // Auto-focus the text field
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

  Color _resolveColor(
    BuildContext context,
    CupertinoDynamicColor dynamicColor,
  ) {
    return CupertinoDynamicColor.resolve(dynamicColor, context);
  }

  Future<void> _submitPost() async {
    final success = await ref.read(createPostProvider.notifier).submitPost();
    if (success && mounted) {
      HapticFeedback.mediumImpact();
      context.pop(true); // Return true to indicate success
    }
  }

  void _showMediaPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ref.read(createPostProvider.notifier).pickImageFromCamera();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.camera, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Take Photo',
                  style: GoogleFonts.plusJakartaSans(fontSize: 17),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ref.read(createPostProvider.notifier).pickImageFromGallery();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.photo, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Choose from Gallery',
                  style: GoogleFonts.plusJakartaSans(fontSize: 17),
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createPostState = ref.watch(createPostProvider);
    final currentUser = ref.watch(currentUserProvider);
    final locationState = ref.watch(locationStateProvider);

    final backgroundColor = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: CupertinoColors.systemGrey6,
        darkColor: CupertinoColors.darkBackgroundGray,
      ),
      context,
    );

    // Listen for content changes
    ref.listen<CreatePostState>(createPostProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        _showError(next.error!);
      }
    });

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // Header
            _buildHeader(context, createPostState),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User avatar and text input
                    _buildInputSection(context, currentUser),
                    // Media preview
                    if (createPostState.mediaFiles.isNotEmpty)
                      _buildMediaPreview(context, createPostState.mediaFiles),
                    // Location
                    _buildLocationSection(context, locationState),
                  ],
                ),
              ),
            ),
            // Bottom toolbar
            _buildBottomToolbar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CreatePostState state) {
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.14, 0.67],
          colors: [
            _resolveColor(context, _cardBackgroundStart),
            _resolveColor(context, _cardBackgroundEnd),
          ],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Close button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.systemGrey5,
                        context,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                ),
                const Spacer(),
                // Title
                Text(
                  'Create Post',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const Spacer(),
                // Post button
                GestureDetector(
                  onTap: state.canSubmit ? _submitPost : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: state.canSubmit
                          ? CupertinoColors.systemBlue
                          : CupertinoDynamicColor.resolve(
                              CupertinoColors.systemGrey4,
                              context,
                            ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            ),
                          )
                        : Text(
                            'Post',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
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
    final textColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final placeholderColor = CupertinoDynamicColor.resolve(
      CupertinoColors.placeholderText,
      context,
    );
    final inputBackgroundColor = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: CupertinoColors.white,
        darkColor: Color(0xFF1C1C1E),
      ),
      context,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inputBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.separator,
            context,
          ),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemGrey5,
                context,
              ),
            ),
            child: currentUser?.profilePictureUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: currentUser!.profilePictureUrl!,
                      fit: BoxFit.cover,
                      cacheManager: AvatarCacheManager.instance,
                      placeholder: (context, url) =>
                          const Center(child: CupertinoActivityIndicator()),
                      errorWidget: (context, url, error) => Icon(
                        CupertinoIcons.person_fill,
                        size: 24,
                        color: placeholderColor,
                      ),
                    ),
                  )
                : Icon(
                    CupertinoIcons.person_fill,
                    size: 24,
                    color: placeholderColor,
                  ),
          ),
          const SizedBox(width: 12),
          // Text input
          Expanded(
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              onChanged: (value) {
                ref.read(createPostProvider.notifier).setContent(value);
              },
              cursorColor: CupertinoDynamicColor.resolve(
                CupertinoColors.systemBlue,
                context,
              ),
              maxLines: null,
              minLines: 5,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: textColor,
              ),
              decoration: InputDecoration(
                filled: false,
                hintText: "What's happening in your area?",
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
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
    return Container(
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
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          mediaFiles[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Remove button
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
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              size: 14,
                              color: Colors.white,
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
    final secondaryColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    final createPostState = ref.watch(createPostProvider);

    // Trigger address fetch when location becomes available
    ref.listen<LocationState>(locationStateProvider, (prev, next) {
      if (next.hasLocation && prev?.position != next.position) {
        ref
            .read(createPostProvider.notifier)
            .fetchAddress(next.latitude!, next.longitude!);
      }
    });

    // Fetch address on first load if location is available
    if (locationState.hasLocation &&
        createPostState.locationName == null &&
        !createPostState.isLoadingAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(createPostProvider.notifier)
            .fetchAddress(locationState.latitude!, locationState.longitude!);
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.location_fill,
            size: 16,
            color: CupertinoColors.systemBlue,
          ),
          const SizedBox(width: 6),
          if (locationState.isLoading || createPostState.isLoadingAddress)
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CupertinoActivityIndicator(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Getting location...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: secondaryColor,
                  ),
                ),
              ],
            )
          else if (locationState.hasLocation &&
              createPostState.locationName != null)
            Expanded(
              child: Text(
                createPostState.locationName!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: secondaryColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (locationState.hasLocation)
            Text(
              'Location available',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: secondaryColor,
              ),
            )
          else
            GestureDetector(
              onTap: () {
                ref.read(locationStateProvider.notifier).requestPermission();
              },
              child: Text(
                'Enable location',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    final borderColor = CupertinoDynamicColor.resolve(
      CupertinoColors.separator,
      context,
    );
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // Add media button
          GestureDetector(
            onTap: _showMediaPicker,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemGrey5,
                  context,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(CupertinoIcons.photo, size: 20, color: iconColor),
            ),
          ),
          const SizedBox(width: 12),
          // Camera button
          GestureDetector(
            onTap: () {
              ref.read(createPostProvider.notifier).pickImageFromCamera();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemGrey5,
                  context,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(CupertinoIcons.camera, size: 20, color: iconColor),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
