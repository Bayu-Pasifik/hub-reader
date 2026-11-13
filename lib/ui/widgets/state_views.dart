import 'package:flutter/material.dart';

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

/// Spinner di ujung daftar berhalaman. Ikut memicu [onShown] setiap kali
/// dibangun (artinya sudah dekat layar), supaya halaman berikutnya tetap
/// dimuat walau isi belum cukup panjang untuk digulir (layar lebar/tablet).
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({super.key, required this.onShown});

  final VoidCallback onShown;

  @override
  Widget build(BuildContext context) {
    // Ditunda: provider tidak boleh diubah saat build.
    Future.microtask(onShown);
    return const Center(child: CircularProgressIndicator());
  }
}
