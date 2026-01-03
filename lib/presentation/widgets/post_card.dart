import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../data/models/post.dart';
import 'user_avatar.dart';

/// Post card widget for displaying a post in the feed
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onUserTap;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              _buildAuthorRow(theme),

              const SizedBox(height: 12),

              // Content
              Text(post.content, style: theme.textTheme.bodyLarge),

              // Media
              if (post.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMedia(theme),
              ],

              const SizedBox(height: 12),

              // Location info
              _buildLocationInfo(theme),

              const SizedBox(height: 12),

              // Action buttons
              _buildActionButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorRow(ThemeData theme) {
    return GestureDetector(
      onTap: onUserTap,
      child: Row(
        children: [
          UserAvatar(
            imageUrl: post.author?.profilePictureUrl,
            name: post.author?.username ?? 'U',
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.author?.fullName ??
                          post.author?.username ??
                          'Unknown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (post.author?.username != null)
                      Text(
                        '@${post.author!.username}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                Text(
                  timeago.format(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              // TODO: Show post options menu
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(ThemeData theme) {
    if (post.mediaUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: post.mediaUrls.first,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.error)),
          ),
        ),
      );
    }

    // Multiple images - show grid
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: post.mediaUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index < post.mediaUrls.length - 1 ? 8 : 0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrls[index],
                fit: BoxFit.cover,
                width: 200,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationInfo(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          'Posted nearby',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text('•', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Text(
          post.geohash.substring(0, 3) + '...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        // Like button
        _ActionButton(
          icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
          iconColor: post.isLiked ? Colors.red : null,
          label: post.likeCount > 0 ? post.likeCount.toString() : '',
          onTap: onLike,
        ),
        const SizedBox(width: 24),

        // Comment button
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: post.commentCount > 0 ? post.commentCount.toString() : '',
          onTap: onComment,
        ),
        const SizedBox(width: 24),

        // Share button
        _ActionButton(icon: Icons.share_outlined, onTap: onShare),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? theme.colorScheme.onSurfaceVariant,
            ),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
