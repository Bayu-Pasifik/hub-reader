import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';

/// Membangun ulang [builder] dari nol tiap [retry] dipanggil, sehingga gambar
/// yang gagal dimuat meminta ulang ke jaringan (kegagalan tidak di-cache).
class RetryScope extends StatefulWidget {
  const RetryScope({super.key, required this.builder});

  final Widget Function(BuildContext context, VoidCallback retry) builder;

  @override
  State<RetryScope> createState() => _RetryScopeState();
}

class _RetryScopeState extends State<RetryScope> {
  int _attempt = 0;

  void _retry() => setState(() => _attempt++);

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_attempt), child: widget.builder(context, _retry));
}

/// Tampilan gagal-muat yang bisa diketuk untuk mencoba lagi.
/// [compact] = hanya ikon (untuk sampul kecil); selain itu ikon + pesan.
class RetryPlaceholder extends StatelessWidget {
  const RetryPlaceholder({super.key, required this.onRetry, this.message, this.compact = false, this.height});

  final VoidCallback onRetry;
  final String? message;
  final bool compact;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = tr('Ketuk untuk coba lagi');
    final child = Center(
      child: compact
          ? Icon(Icons.refresh, color: scheme.onSurfaceVariant)
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(message!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 4),
                  Text(hint, textAlign: TextAlign.center, style: TextStyle(color: scheme.primary)),
                ],
              ),
            ),
    );
    return Semantics(
      button: true,
      label: hint,
      child: InkWell(
        onTap: onRetry,
        child: Container(
          height: height,
          color: scheme.surfaceContainerHighest,
          child: child,
        ),
      ),
    );
  }
}
