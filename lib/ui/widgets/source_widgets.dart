import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../sources/models.dart';
import '../../sources/source_exception.dart';
import '../router.dart';
import 'state_views.dart';

/// Sampul 3:4 dari situs sumber, dengan header (Referer) milik sumber.
class SourceCover extends StatelessWidget {
  const SourceCover({super.key, required this.url, required this.headers, this.width});

  final String? url;
  final Map<String, String> headers;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget box(IconData icon) => Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(icon, color: scheme.onSurfaceVariant),
        );

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: url == null
              ? box(Icons.image_outlined)
              // Sumber lokal: path file di perangkat.
              : !url!.startsWith('http')
                  ? Image.file(
                      File(url!),
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                      errorBuilder: (_, __, ___) => box(Icons.broken_image_outlined),
                    )
                  : CachedNetworkImage(
                  imageUrl: url!,
                  httpHeaders: headers,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => box(Icons.image_outlined),
                  errorWidget: (_, __, ___) => box(Icons.broken_image_outlined),
                ),
        ),
      ),
    );
  }
}

class SourceMangaCard extends StatelessWidget {
  const SourceMangaCard({super.key, required this.manga, required this.headers, this.onTap});

  final SourceManga manga;
  final Map<String, String> headers;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SourceCover(url: manga.thumbnailUrl, headers: headers),
          const SizedBox(height: 6),
          Text(
            manga.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Error dari situs sumber.
class SourceErrorView extends StatelessWidget {
  const SourceErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
    this.verifyUrl,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  /// Halaman yang dibuka di WebView bila situs diblokir Cloudflare.
  final String? verifyUrl;

  Future<void> _verify(BuildContext context, String url) async {
    final ok = await context.push<bool>(sourceWebViewLocation(url));
    if (ok == true) onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    final e = toSourceException(error);
    final verifyTarget =
        e.kind == SourceErrorKind.cloudflare ? (e.url?.toString() ?? verifyUrl) : null;
    return EmptyView(
      compact: compact,
      animation: AppAnimation.error,
      icon: switch (e.kind) {
        SourceErrorKind.noConnection => Icons.wifi_off_rounded,
        SourceErrorKind.timeout => Icons.hourglass_bottom_rounded,
        SourceErrorKind.cloudflare => Icons.shield_outlined,
        SourceErrorKind.notFound => Icons.search_off_rounded,
        SourceErrorKind.rateLimited => Icons.speed_rounded,
        SourceErrorKind.parse => Icons.code_off_rounded,
        _ => Icons.error_outline_rounded,
      },
      title: e.title,
      message: e.message,
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (verifyTarget != null)
            FilledButton.icon(
              onPressed: () => _verify(context, verifyTarget),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Buka di WebView'),
            ),
          if (onRetry != null)
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
        ],
      ),
    );
  }
}

class ContentWarningChip extends StatelessWidget {
  const ContentWarningChip({super.key, required this.warning});

  final ContentWarning warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (warning) {
      ContentWarning.safe => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      ContentWarning.mixed => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      ContentWarning.nsfw => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(warning.label, style: TextStyle(color: fg, fontSize: 11.5)),
    );
  }
}
