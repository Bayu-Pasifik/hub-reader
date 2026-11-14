import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Animasi Lottie bawaan (assets/lottie). Warna disesuaikan ke tema aplikasi.
enum AppAnimation {
  loading('assets/lottie/loading.json'),
  empty('assets/lottie/empty.json'),
  error('assets/lottie/error.json'),
  heart('assets/lottie/heart.json'),
  sync('assets/lottie/sync.json'),
  success('assets/lottie/success.json'),
  search('assets/lottie/search.json');

  const AppAnimation(this.asset);
  final String asset;
}

class AppLottie extends StatelessWidget {
  const AppLottie(this.animation,
      {super.key, this.size = 120, this.repeat = true});

  final AppAnimation animation;
  final double size;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Lottie.asset(
      animation.asset,
      width: size,
      height: size,
      repeat: repeat,
      animate: !reduce,
      delegates: LottieDelegates(values: [
        ValueDelegate.color(const ['**', 'Fill 1', '**'], value: color),
        ValueDelegate.strokeColor(const ['**', 'Stroke 1', '**'], value: color),
      ]),
      errorBuilder: (_, __, ___) => Icon(Icons.inbox_outlined, size: size / 2),
    );
  }
}

/// Ikon favorit yang meletup (animasi Lottie) saat baru difavoritkan.
class FavoriteIcon extends StatefulWidget {
  const FavoriteIcon({super.key, required this.isFavorite});

  final bool isFavorite;

  @override
  State<FavoriteIcon> createState() => _FavoriteIconState();
}

class _FavoriteIconState extends State<FavoriteIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800), // 24 frame @ 30 fps
  );

  @override
  void didUpdateWidget(FavoriteIcon old) {
    super.didUpdateWidget(old);
    if (widget.isFavorite &&
        !old.isFavorite &&
        !MediaQuery.of(context).disableAnimations) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final playing = _c.isAnimating;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: playing ? 0 : 1,
              child: Icon(
                widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: widget.isFavorite ? color : null,
              ),
            ),
            Offstage(
              offstage: !playing,
              child: SizedBox(
                width: 24,
                height: 24,
                child: OverflowBox(
                  maxWidth: 64,
                  maxHeight: 64,
                  child: Lottie.asset(
                    AppAnimation.heart.asset,
                    controller: _c,
                    width: 64,
                    height: 64,
                    delegates: LottieDelegates(values: [
                      ValueDelegate.color(const ['**', 'Fill 1', '**'],
                          value: color),
                      ValueDelegate.strokeColor(const ['**', 'Stroke 1', '**'],
                          value: color),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Indikator memuat layar penuh dengan animasi Lottie.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Center(child: AppLottie(AppAnimation.loading, size: size));
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.animation,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final AppAnimation? animation;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) => _MessageView(
        icon: icon,
        animation: animation ?? (compact ? null : AppAnimation.empty),
        title: title,
        message: message,
        compact: compact,
        actions: [if (action != null) action!],
      );
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.animation,
    required this.title,
    required this.message,
    required this.actions,
    required this.compact,
  });

  final IconData icon;
  final AppAnimation? animation;
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
            if (animation != null)
              AppLottie(animation!, size: compact ? 80 : 140)
            else
              Icon(icon,
                  size: compact ? 32 : 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
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
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: actions),
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
    return const LoadingView(size: 56);
  }
}
