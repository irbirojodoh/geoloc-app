import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/cache/image_cache_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_extensions.dart';
import '../../data/models/post.dart';
import 'user_avatar.dart';

/// Post card — old-money luxury aesthetic
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onUserTap;

  /// Placed at the end of the header row (e.g. overflow menu)
  final Widget? headerTrailing;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onUserTap,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Post by ${post.author?.username ?? 'unknown'}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: AppRadii.sharpAll,
            border: Border.all(color: cs.outline, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _buildProfileColumn(context),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _buildContentColumn(context)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildProfileColumn(BuildContext context) {
    return GestureDetector(
      onTap: onUserTap,
      child: Column(
        children: [
          UserAvatar(
            imageUrl: post.author?.profilePictureUrl,
            name: post.author?.username ?? 'U',
            size: 38,
          ),
          const SizedBox(height: 6),
          Text(
            _formatTime(post.createdAt),
            style: context.monoTimestamp,
          ),
        ],
      ),
    );
  }

  Widget _buildContentColumn(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locationName = _getLocationName();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username and location (+ optional trailing menu)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: onUserTap,
                      child: Text(
                        post.author?.username ?? 'Username',
                        style: context.username,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '·',
                      style: context.bodyMedium?.copyWith(
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      locationName,
                      style: context.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (headerTrailing != null) headerTrailing!,
          ],
        ),
        const SizedBox(height: 6),

        // Post content
        Text(
          post.content,
          style: context.postContent,
        ),

        // Media
        if (post.mediaUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMedia(context),
        ],

        // Actions
        const SizedBox(height: 10),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildMedia(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageCount = post.mediaUrls.length;

    if (imageCount == 1) {
      // For full-width single images we cap the decoded width to the screen
      // width to avoid decoding 4K source files into memory while scrolling.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final maxLogicalWidth = MediaQuery.sizeOf(context).width;
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CachedNetworkImage(
          imageUrl: post.mediaUrls.first,
          fit: BoxFit.cover,
          cacheManager: PostImageCacheManager.instance,
          memCacheWidth: (maxLogicalWidth * dpr).round(),
          placeholder: (context, url) => Container(
            height: 200,
            color: cs.surface,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 1,
                color: AppColors.gold(context),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: cs.surface,
            child: Icon(Icons.image_outlined, size: 32, color: cs.outline),
          ),
        ),
      );
    }

    if (imageCount == 2) {
      return Row(
        children: [
          Expanded(child: _buildGridImage(context, post.mediaUrls[0], 150)),
          const SizedBox(width: 4),
          Expanded(child: _buildGridImage(context, post.mediaUrls[1], 150)),
        ],
      );
    }

    if (imageCount == 3) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildGridImage(context, post.mediaUrls[0], 200),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                _buildGridImage(context, post.mediaUrls[1], 98),
                const SizedBox(height: 4),
                _buildGridImage(context, post.mediaUrls[2], 98),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildGridImage(context, post.mediaUrls[0], 100)),
            const SizedBox(width: 4),
            Expanded(child: _buildGridImage(context, post.mediaUrls[1], 100)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _buildGridImage(context, post.mediaUrls[2], 100)),
            const SizedBox(width: 4),
            Expanded(
              child: imageCount > 4
                  ? _buildOverflowImage(
                      context,
                      post.mediaUrls[3],
                      100,
                      imageCount - 4,
                    )
                  : _buildGridImage(context, post.mediaUrls[3], 100),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridImage(BuildContext context, String imageUrl, double height) {
    final cs = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        height: height,
        fit: BoxFit.cover,
        cacheManager: PostImageCacheManager.instance,
        // Decode at the cell's logical pixel height; width follows aspect.
        memCacheHeight: (height * dpr).round(),
        placeholder: (context, url) => Container(
          height: height,
          color: cs.surface,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: AppColors.gold(context),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: height,
          color: cs.surface,
          child: Icon(Icons.image_outlined, size: 24, color: cs.outline),
        ),
      ),
    );
  }

  Widget _buildOverflowImage(
    BuildContext context,
    String imageUrl,
    double height,
    int moreCount,
  ) {
    return Stack(
      children: [
        _buildGridImage(context, imageUrl, height),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Text(
                  '+$moreCount',
                  style: context.monoOverlay,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final muted = AppColors.textMuted(context);

    return Row(
      children: [
        _ActionButton(
          icon: post.isLiked ? Icons.favorite : Icons.favorite_outline,
          iconColor: post.isLiked ? AppColors.error : muted,
          label: post.likeCount > 0 ? post.likeCount.toString() : '',
          onTap: onLike,
        ),
        const SizedBox(width: 20),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          iconColor: muted,
          label: post.commentCount > 0 ? post.commentCount.toString() : '',
          onTap: onComment,
        ),
        const SizedBox(width: 20),
        _ActionButton(
          icon: Icons.share_outlined,
          iconColor: muted,
          onTap: onShare,
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w';
    return timeago.format(dateTime, locale: 'en_short');
  }

  String _getLocationName() {
    if (post.formattedLocation.isNotEmpty) return post.formattedLocation;
    if (post.geohash.isNotEmpty) return 'Nearby location';
    return 'Unknown location';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String? label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.iconColor,
    this.label,
    this.onTap,
  });

  String get _semanticLabel {
    if (icon == Icons.favorite || icon == Icons.favorite_outline) {
      return 'Like${label != null && label!.isNotEmpty ? ", $label likes" : ""}';
    }
    if (icon == Icons.chat_bubble_outline) {
      return 'Comment${label != null && label!.isNotEmpty ? ", $label comments" : ""}';
    }
    if (icon == Icons.share_outlined) return 'Share';
    return 'Action';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AppTapTarget.materialMinimum,
            minHeight: AppTapTarget.materialMinimum,
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: iconColor),
                if (label != null && label!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(label!, style: context.monoCaption),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
