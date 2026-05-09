import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache/image_cache_manager.dart';
import '../../core/theme/theme_extensions.dart';

/// User avatar — old-money luxury aesthetic
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    this.showBorder = false,
    this.onTap,
  });

  Color _backgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallbackPalette = <Color>[
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
      colorScheme.surfaceContainerHighest,
      colorScheme.surfaceContainerHigh,
      colorScheme.surfaceContainer,
    ];
    final index = name.isEmpty
        ? 0
        : name.codeUnitAt(0) % fallbackPalette.length;
    return fallbackPalette[index];
  }

  String _initials() {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: colorScheme.primary, width: 1.5)
            : null,
      ),
      child: imageUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheManager: AvatarCacheManager.instance,
                // Decode at the rendered logical pixel size to keep memory low.
                memCacheWidth:
                    (size * MediaQuery.devicePixelRatioOf(context)).round(),
                memCacheHeight:
                    (size * MediaQuery.devicePixelRatioOf(context)).round(),
                placeholder: (context, url) => _buildFallback(context),
                errorWidget: (context, url, error) => _buildFallback(context),
              ),
            )
          : _buildFallback(context),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initials(),
          style: context.textTheme.headlineMedium?.copyWith(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
