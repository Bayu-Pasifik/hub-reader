import 'package:flutter/widgets.dart';

/// Membangun ulang seluruh aplikasi (termasuk ProviderScope) tanpa keluar,
/// mis. setelah memulihkan cadangan supaya semua provider membaca data baru.
class AppRestart extends StatefulWidget {
  const AppRestart({super.key, required this.builder, this.onRestart});

  final WidgetBuilder builder;

  /// Dipanggil sebelum membangun ulang (mis. memuat ulang cookie).
  final VoidCallback? onRestart;

  static void restart(BuildContext context) => context.findAncestorStateOfType<_AppRestartState>()?._restart();

  @override
  State<AppRestart> createState() => _AppRestartState();
}

class _AppRestartState extends State<AppRestart> {
  Key _key = UniqueKey();

  void _restart() {
    widget.onRestart?.call();
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.builder(context));
}
