import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_url.dart';
import '../../services/media_service.dart';

/// Loads network images for Geoloc media (presigned R2 GET URLs and external URLs).
///
/// Presigned R2 URLs must not include a Bearer token. On load failure (e.g. 403
/// after expiry), refreshes via [MediaService.signUrl] using [mediaKey] or by
/// parsing the key from the URL.
class AuthNetworkImage extends ConsumerStatefulWidget {
  final String imageUrl;
  final String? mediaKey;
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
    this.mediaKey,
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
  ConsumerState<AuthNetworkImage> createState() => _AuthNetworkImageState();
}

class _AuthNetworkImageState extends ConsumerState<AuthNetworkImage> {
  late String _currentUrl;
  bool _refreshAttempted = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.imageUrl;
    if (_currentUrl.isNotEmpty) {
      _seedUrlCache(_currentUrl);
    } else if (widget.mediaKey != null) {
      _resolveFromKey();
    }
  }

  @override
  void didUpdateWidget(AuthNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.mediaKey != widget.mediaKey) {
      if (_shouldKeepCurrentUrl(oldWidget)) {
        return;
      }

      _currentUrl = widget.imageUrl;
      _refreshAttempted = false;
      _isRefreshing = false;
      if (_currentUrl.isNotEmpty) {
        _seedUrlCache(_currentUrl);
      } else if (widget.mediaKey != null) {
        _resolveFromKey();
      }
    }
  }

  bool _shouldKeepCurrentUrl(AuthNetworkImage oldWidget) {
    if (_currentUrl.isEmpty || _refreshAttempted) return false;

    final oldKey =
        oldWidget.mediaKey ?? MediaUrl.parseKeyFromUrl(oldWidget.imageUrl);
    final newKey =
        widget.mediaKey ?? MediaUrl.parseKeyFromUrl(widget.imageUrl);

    if (oldKey != null && oldKey == newKey) {
      return true;
    }

    if (oldWidget.imageUrl == widget.imageUrl) {
      return true;
    }

    return false;
  }

  void _seedUrlCache(String url) {
    if (MediaUrl.isPresignedR2Url(url)) {
      ref.read(mediaServiceProvider).cache.seedFromPresignedUrl(url);
    }
  }

  String? get _effectiveKey =>
      widget.mediaKey ?? MediaUrl.parseKeyFromUrl(_currentUrl);

  Future<void> _resolveFromKey() async {
    final key = widget.mediaKey;
    if (key == null) return;

    final cached = ref.read(mediaServiceProvider).getCachedUrl(key);
    if (cached != null) {
      if (mounted) setState(() => _currentUrl = cached);
      return;
    }

    if (mounted) setState(() => _isRefreshing = true);

    try {
      final signed = await ref.read(mediaServiceProvider).signUrl(key);
      if (!mounted) return;
      setState(() {
        _currentUrl = signed.url;
        _isRefreshing = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _refreshExpiredUrl(String failedUrl) async {
    if (_refreshAttempted || _isRefreshing) return;

    final key = _effectiveKey ?? MediaUrl.parseKeyFromUrl(failedUrl);
    if (key == null) return;

    _refreshAttempted = true;
    setState(() => _isRefreshing = true);

    try {
      final signed = await ref.read(mediaServiceProvider).signUrl(key);
      if (!mounted || signed.url == _currentUrl) return;
      setState(() {
        _currentUrl = signed.url;
        _isRefreshing = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRefreshing || _currentUrl.isEmpty) {
      if (_currentUrl.isEmpty && widget.mediaKey == null) {
        return widget.errorWidget != null
            ? widget.errorWidget!(context, widget.imageUrl, null)
            : _buildDefaultErrorWidget(context);
      }
      return widget.placeholder != null
          ? widget.placeholder!(context, _currentUrl)
          : _buildDefaultPlaceholder(context);
    }

    return CachedNetworkImage(
      imageUrl: _currentUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheManager: widget.cacheManager,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      placeholder: widget.placeholder,
      errorWidget: (context, url, error) {
        final canRefresh = _effectiveKey != null ||
            MediaUrl.isPresignedR2Url(url);
        if (!_refreshAttempted && canRefresh) {
          _refreshExpiredUrl(url);
          return widget.placeholder != null
              ? widget.placeholder!(context, url)
              : _buildDefaultPlaceholder(context);
        }
        return widget.errorWidget != null
            ? widget.errorWidget!(context, url, error)
            : _buildDefaultErrorWidget(context);
      },
    );
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: widget.width,
      height: widget.height,
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
      width: widget.width,
      height: widget.height,
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: (widget.width != null && widget.width! < 40) ? 16 : 24,
          color: cs.outline,
        ),
      ),
    );
  }
}
