import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';

/// Tampilan error yang konsisten: ikon + judul + penjelasan + tombol aksi.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;

  /// compact = dipakai di dalam daftar (mis. gagal memuat bab), bukan layar penuh.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final apiError = toApiException(error);
    final needsSettings = apiError.kind == ApiErrorKind.notConfigured ||
        apiError.kind == ApiErrorKind.unauthorized ||
        apiError.kind == ApiErrorKind.badResponse;

    final icon = switch (apiError.kind) {
      ApiErrorKind.noConnection => Icons.wifi_off_rounded,
      ApiErrorKind.timeout => Icons.hourglass_bottom_rounded,
      ApiErrorKind.notConfigured || ApiErrorKind.unauthorized => Icons.key_off_rounded,
      ApiErrorKind.notFound => Icons.search_off_rounded,
      ApiErrorKind.rateLimited => Icons.speed_rounded,
      _ => Icons.error_outline_rounded,
    };

    return _MessageView(
      icon: icon,
      title: apiError.title,
      message: apiError.message,
      compact: compact,
      actions: [
        if (onRetry != null)
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        if (needsSettings)
          TextButton(
            onPressed: () => context.push('/settings'),
            child: const Text('Buka Pengaturan'),
          ),
      ],
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) => _MessageView(
        icon: icon,
        title: title,
        message: message,
        compact: compact,
        actions: [if (action != null) action!],
      );
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    required this.compact,
  });

  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 32 : 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner "mode offline": data yang tampil berasal dari cache.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.cachedAt});

  final DateTime cachedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Server tidak terjangkau. Menampilkan data tersimpan '
              '(${relativeTime(cachedAt)}). Tarik ke bawah untuk mencoba lagi.',
              style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Membungkus widget non-scroll agar RefreshIndicator tetap bisa ditarik.
class ScrollableFill extends StatelessWidget {
  const ScrollableFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      );
}
