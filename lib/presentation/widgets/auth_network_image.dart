import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

/// Reusable widget for loading network images with authenticated headers.
/// Useful for R2-proxied storage media, but falls back gracefully.
class AuthNetworkImage extends ConsumerWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BaseCacheManager? cacheManager;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const AuthNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.cacheManager,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenAsync = ref.watch(accessTokenProvider);

    return tokenAsync.when(
      data: (token) {
        final headers = <String, String>{};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }

        return CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          cacheManager: cacheManager,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          httpHeaders: headers,
          placeholder: placeholder,
          errorWidget: errorWidget,
        );
      },
      loading: () => placeholder != null
          ? placeholder!(context, imageUrl)
          : _buildDefaultPlaceholder(context),
      error: (error, stackTrace) => errorWidget != null
          ? errorWidget!(context, imageUrl, error)
          : _buildDefaultErrorWidget(context),
    );
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: (width != null && width! < 40) ? 16 : 24,
          color: cs.outline,
        ),
      ),
    );
  }
}
