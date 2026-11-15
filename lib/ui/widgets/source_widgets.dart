import 'dart:io';
import '../../core/i18n/strings.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../core/net/image_cache.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../sources/models.dart';
import '../../core/update/app_update.dart';
import '../../sources/source_exception.dart';
import '../../sources/source_report.dart';
import '../router.dart';
import 'state_views.dart';

/// Sampul 3:4 dari situs sumber, dengan header (Referer) milik sumber.
class SourceCover extends StatelessWidget {
  const SourceCover({super.key, required this.url, required this.headers, this.width, this.heroTag});

  /// Tag Hero (lihat `coverHeroTag`); null = tanpa animasi terbang ke layar detail.
  final String? heroTag;

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

    final cover = SizedBox(
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
                  : CachedNetworkImage(cacheManager: AppImageCache.instance, 
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
    return heroTag == null ? cover : Hero(tag: heroTag!, child: cover);
  }
}

class SourceMangaCard extends StatelessWidget {
  const SourceMangaCard({super.key, required this.manga, required this.headers, this.onTap, this.heroTag});

  final SourceManga manga;
  final Map<String, String> headers;
  final VoidCallback? onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SourceCover(url: manga.thumbnailUrl, headers: headers, heroTag: heroTag),
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
    this.reportSource,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  /// Halaman yang dibuka di WebView bila situs diblokir Cloudflare.
  final String? verifyUrl;

  /// Sumber yang bisa dilaporkan bila errornya bukan masalah jaringan pengguna.
  final SourceReportTarget? reportSource;

  Future<void> _report(BuildContext context, SourceReportTarget source, SourceException e) async {
    final uri = buildSourceReportUri(source, e, appVersion: await AppUpdate.currentVersion());
    final ok = await AppUpdate.open(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('Tidak ada browser untuk membuka laporan'))));
    }
  }

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
      animation: e.kind == SourceErrorKind.noConnection ? AppAnimation.noInternet : AppAnimation.error,
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
              label: Text(tr('Buka di WebView')),
            ),
          if (onRetry != null)
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(tr('Coba lagi')),
            ),
          if (reportSource != null && isReportable(e.kind))
            TextButton.icon(
              onPressed: () => _report(context, reportSource!, e),
              icon: const Icon(Icons.bug_report_outlined),
              label: Text(tr('Laporkan sumber ini')),
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
