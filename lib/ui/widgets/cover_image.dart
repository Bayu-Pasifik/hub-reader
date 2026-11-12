import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/media_url.dart';
import '../../state/core_providers.dart';

/// Sampul rasio 3:4 (sama dengan thumbnail 300x400 dari CoverThumbnailer).
class CoverImage extends ConsumerWidget {
  const CoverImage({super.key, required this.url, this.width, this.borderRadius = 8});

  final String? url;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = resolveMediaUrl(url, ref.watch(apiOriginProvider));
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
    );

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: resolved == null
              ? placeholder
              : CachedNetworkImage(
                  imageUrl: resolved,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                  ),
                ),
        ),
      ),
    );
  }
}
