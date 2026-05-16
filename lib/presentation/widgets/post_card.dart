import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/cache/image_cache_manager.dart';
import '../../data/models/post.dart';
import 'user_avatar.dart';

/// Material 3 post card for feed/detail contexts.
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
    final textTheme = Theme.of(context).textTheme;
    final authorName = post.author?.username ?? 'Unknown';
    final location = post.formattedLocation.trim();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onUserTap,
                    borderRadius: BorderRadius.circular(24),
                    child: UserAvatar(
                      imageUrl: post.author?.profilePictureUrl,
                      name: authorName,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                authorName,
                                style: textTheme.titleSmall?.copyWith(
                                  color: cs.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(post.createdAt),
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (headerTrailing != null) headerTrailing!,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                style: textTheme.bodyLarge,
              ),
              if (post.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildMedia(context),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  _ActionButton(
                    icon: post.isLiked
                        ? Icons.favorite
                        : Icons.favorite_outline,
                    count: post.likeCount,
                    onPressed: onLike,
                    iconColor: post.isLiked ? cs.primary : cs.onSurfaceVariant,
                    chipBackgroundColor: post.isLiked
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    chipTextColor: post.isLiked
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                    semanticLabel: 'Like post',
                  ),
                  _ActionButton(
                    icon: Icons.comment_outlined,
                    count: post.commentCount,
                    onPressed: onComment,
                    iconColor: cs.onSurfaceVariant,
                    chipBackgroundColor: cs.surfaceContainerHighest,
                    chipTextColor: cs.onSurfaceVariant,
                    semanticLabel: 'Open comments',
                  ),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    count: null,
                    onPressed: onShare,
                    iconColor: cs.onSurfaceVariant,
                    chipBackgroundColor: cs.surfaceContainerHighest,
                    chipTextColor: cs.onSurfaceVariant,
                    semanticLabel: 'Share post',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: post.mediaUrls.first,
          fit: BoxFit.cover,
          cacheManager: PostImageCacheManager.instance,
          memCacheWidth: (maxLogicalWidth * dpr).round(),
          placeholder: (context, url) => Container(
            height: 200,
            color: cs.surface,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 1),
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
      borderRadius: BorderRadius.circular(12),
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
            child: CircularProgressIndicator(strokeWidth: 1),
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
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        _buildGridImage(context, imageUrl, height),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: cs.scrim.withValues(alpha: 0.5),
              child: Center(
                child: Text(
                  '+$moreCount',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: cs.onPrimary),
                ),
              ),
            ),
          ),
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final VoidCallback? onPressed;
  final Color iconColor;
  final Color chipBackgroundColor;
  final Color chipTextColor;
  final String semanticLabel;

  const _ActionButton({
    required this.icon,
    this.count,
    this.onPressed,
    required this.iconColor,
    required this.chipBackgroundColor,
    required this.chipTextColor,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: semanticLabel,
              onPressed: onPressed,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              icon: Icon(icon, size: 21, color: iconColor),
            ),
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: chipBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: textTheme.labelSmall?.copyWith(
                    color: chipTextColor,
                  ),
                ),
              ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
