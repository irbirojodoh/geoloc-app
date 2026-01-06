import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../data/models/post.dart';
import 'user_avatar.dart';

// ============================================================================

/// Post card widget for displaying a post in the feed (Figma design)
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Match login screen card background colors
          color: CupertinoDynamicColor.resolve(
            const CupertinoDynamicColor.withBrightness(
              color: Color(0xFFFFFFFF), // Light mode: White
              darkColor: Color(0xFF1C1C1E), // Dark mode: iOS dark card
            ),
            context,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoDynamicColor.resolve(
                const CupertinoDynamicColor.withBrightness(
                  color: Color(0x0D000000), // Light mode: subtle shadow
                  darkColor: Color(0x33000000), // Dark mode: stronger shadow
                ),
                context,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: Profile avatar and time
            _buildProfileColumn(context),
            const SizedBox(width: 10),
            // Right column: Username, location, and content
            Expanded(child: _buildContentColumn(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileColumn(BuildContext context) {
    return GestureDetector(
      onTap: onUserTap,
      child: Column(
        children: [
          // Profile avatar
          UserAvatar(
            imageUrl: post.author?.profilePictureUrl,
            name: post.author?.username ?? 'U',
            size: 40,
          ),
          const SizedBox(height: 6),
          // Time ago
          Text(
            _formatTime(post.createdAt),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username and location row
        _buildUsernameLocationRow(context),
        const SizedBox(height: 1),
        // Post content
        _buildPostContent(context),
        // Media (if any)
        if (post.mediaUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildMedia(context),
        ],
        // Action buttons (optional - commented out to match Figma exactly)
        const SizedBox(height: 8),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildUsernameLocationRow(BuildContext context) {
    final locationName = _getLocationName();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        children: [
          // Username
          GestureDetector(
            onTap: onUserTap,
            child: Text(
              post.author?.username ?? 'Username',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ),
              ),
            ),
          ),
          // Separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '·',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
            ),
          ),
          // Location
          Flexible(
            child: Text(
              locationName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 7, top: 4),
      child: Text(
        post.content,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        ),
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    if (post.mediaUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: post.mediaUrls.first,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 150,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.systemGrey5,
              context,
            ),
            child: const Center(child: CupertinoActivityIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            height: 150,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.systemGrey5,
              context,
            ),
            child: const Center(child: Icon(CupertinoIcons.photo, size: 32)),
          ),
        ),
      );
    }

    // Multiple images - horizontal scroll
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: post.mediaUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index < post.mediaUrls.length - 1 ? 8 : 0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrls[index],
                fit: BoxFit.cover,
                width: 150,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 02),
      child: Row(
        children: [
          // Like button
          _ActionButton(
            icon: post.isLiked
                ? CupertinoIcons.heart_fill
                : CupertinoIcons.heart,
            iconColor: post.isLiked ? CupertinoColors.systemRed : iconColor,
            label: post.likeCount > 0 ? post.likeCount.toString() : '',
            onTap: onLike,
          ),
          const SizedBox(width: 20),
          // Comment button
          _ActionButton(
            icon: CupertinoIcons.chat_bubble,
            iconColor: iconColor,
            label: post.commentCount > 0 ? post.commentCount.toString() : '',
            onTap: onComment,
          ),
          const SizedBox(width: 20),
          // Share button
          _ActionButton(
            icon: CupertinoIcons.share,
            iconColor: iconColor,
            onTap: onShare,
          ),
        ],
      ),
    );
  }

  /// Format time for display (e.g., "2h", "1d", "3w")
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w';
    } else {
      return timeago.format(dateTime, locale: 'en_short');
    }
  }

  /// Get location name from address or fallback
  String _getLocationName() {
    // Use the formatted location from address (e.g., "Pondok Cina, Depok")
    if (post.formattedLocation.isNotEmpty) {
      return post.formattedLocation;
    }
    // Fallback to placeholder if no address data
    if (post.geohash.isNotEmpty) {
      return 'Nearby location';
    }
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.secondaryLabel,
                    context,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
