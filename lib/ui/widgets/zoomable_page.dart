import 'package:flutter/material.dart';

/// Matriks tujuan: kembali ke 1x bila sedang diperbesar, kalau tidak
/// perbesar dengan titik ketuk tetap berada di bawah jari.
Matrix4 zoomTarget(Matrix4 current, Offset focal, double scale) {
  if (current.getMaxScaleOnAxis() > 1.05) return Matrix4.identity();
  return Matrix4.identity()
    ..translateByDouble(-focal.dx * (scale - 1), -focal.dy * (scale - 1), 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
}

/// Halaman reader yang bisa dicubit-zoom dan, bila [doubleTapZoom] aktif,
/// diperbesar/dikembalikan dengan ketuk dua kali di titik yang diketuk.
class ZoomablePage extends StatefulWidget {
  const ZoomablePage({
    super.key,
    required this.child,
    this.doubleTapZoom = true,
    this.maxScale = 4,
    this.doubleTapScale = 2.5,
  });

  final Widget child;
  final bool doubleTapZoom;
  final double maxScale;

  /// Skala saat ketuk dua kali (dibatasi [maxScale]).
  final double doubleTapScale;

  @override
  State<ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<ZoomablePage> with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Offset _tap = Offset.zero;

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final end = zoomTarget(_controller.value, _tap, widget.doubleTapScale.clamp(1.0, widget.maxScale));
    final tween = Matrix4Tween(begin: _controller.value, end: end);
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    void tick() => _controller.value = tween.evaluate(curved);
    _anim
      ..removeListener(tick)
      ..addListener(tick)
      ..forward(from: 0).whenComplete(() => _anim.removeListener(tick));
  }

  @override
  Widget build(BuildContext context) {
    final viewer = InteractiveViewer(
      transformationController: _controller,
      minScale: 1,
      maxScale: widget.maxScale,
      child: widget.child,
    );
    if (!widget.doubleTapZoom) return viewer;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: (d) => _tap = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: viewer,
    );
  }
}
