import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';

/// Kecerahan baru setelah menggeser [dy] piksel (positif = ke bawah) dari [start]
/// pada area setinggi [height]. Menggeser satu tinggi penuh mengubah kecerahan
/// 1.5 skala penuh; hasil dijepit ke 0.05…1. [start] ≤ 0 (ikut sistem) dihitung 0.5.
double brightnessFromDrag(double start, double dy, double height) {
  if (height <= 0) return start <= 0 ? 0.5 : start.clamp(0.05, 1.0);
  final base = start <= 0 ? 0.5 : start;
  return (base - dy / height * 1.5).clamp(0.05, 1.0);
}

/// Strip tipis di tepi layar: geser vertikal untuk mengatur kecerahan. Ketukan
/// tetap diteruskan ke bawahnya (pindah halaman); hanya geseran vertikal yang diambil.
class BrightnessStrip extends StatefulWidget {
  const BrightnessStrip({
    super.key,
    required this.brightness,
    required this.onChanged,
    required this.onCommit,
    this.width = 44,
  });

  /// Kecerahan tersimpan (0 = ikut sistem).
  final double brightness;

  /// Dipanggil terus saat menggeser (terapkan langsung ke layar).
  final ValueChanged<double> onChanged;

  /// Dipanggil sekali saat geseran selesai (simpan ke pengaturan).
  final ValueChanged<double> onCommit;
  final double width;

  @override
  State<BrightnessStrip> createState() => _BrightnessStripState();
}

class _BrightnessStripState extends State<BrightnessStrip> {
  double _start = 0;
  double _dy = 0;
  double? _live;

  @override
  Widget build(BuildContext context) {
    final live = _live;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: widget.width,
              height: height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (_) {
                  _start = widget.brightness;
                  _dy = 0;
                },
                onVerticalDragUpdate: (d) {
                  _dy += d.delta.dy;
                  final v = brightnessFromDrag(_start, _dy, height);
                  setState(() => _live = v);
                  widget.onChanged(v);
                },
                onVerticalDragEnd: (_) {
                  final v = _live;
                  setState(() => _live = null);
                  if (v != null) widget.onCommit(v);
                },
                onVerticalDragCancel: () {
                  final v = _live;
                  setState(() => _live = null);
                  if (v != null) widget.onCommit(v);
                },
              ),
            ),
            if (live != null)
              Positioned(
                left: widget.width + 8,
                top: height / 2 - 20,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.brightness_6, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${(live * 100).round()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
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

/// Teks bantuan di pengaturan.
String brightnessGestureHint() => tr('Geser naik/turun di tepi kiri layar untuk mengatur kecerahan');
