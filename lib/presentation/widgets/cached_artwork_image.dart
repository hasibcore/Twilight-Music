import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/artwork_service.dart';

/// Shared network cover art renderer with HTTPS normalization, browser User-Agent headers,
/// and automatic fallback resolution (e.g. `500x500` -> `150x150` on JioSaavn CDN)
/// before rendering [fallbackWidget].
class CachedArtworkImage extends StatelessWidget {
  final String? imageUrl;
  final String? songId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallbackWidget;
  final Widget? placeholderWidget;
  final int? memCacheWidth;
  final bool disableFade;

  const CachedArtworkImage({
    super.key,
    required this.imageUrl,
    this.songId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.fallbackWidget,
    this.placeholderWidget,
    this.memCacheWidth,
    this.disableFade = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = ArtworkService.normalizeThumbnailUrl(imageUrl, songId: songId);
    if (normalized.isEmpty) {
      return SizedBox(width: width, height: height, child: fallbackWidget);
    }

    final retryFallback = ArtworkService.fallbackThumbnailUrl(normalized, songId: songId);
    final placeholder = placeholderWidget ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFF1E293B),
        );

    return CachedNetworkImage(
      imageUrl: normalized,
      // No custom httpHeaders — saavncdn/ytimg CDNs block browser UA spoofing (403).
      // CachedNetworkImage sends its own minimal headers which CDNs accept fine.
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: disableFade ? Duration.zero : const Duration(milliseconds: 160),
      fadeOutDuration: disableFade ? Duration.zero : const Duration(milliseconds: 120),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) {
        if (retryFallback != null && retryFallback.isNotEmpty && retryFallback != normalized) {
          return CachedNetworkImage(
            imageUrl: retryFallback,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: memCacheWidth,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => fallbackWidget,
          );
        }
        return fallbackWidget;
      },
    );
  }
}
