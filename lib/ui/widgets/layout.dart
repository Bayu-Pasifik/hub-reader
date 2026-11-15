import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lebar minimum (dp) untuk tata letak dua panel di layar lebar
/// (tablet, HP lipat, landscape): info seri di kiri, daftar bab di kanan.
const twoPaneBreakpoint = 840.0;

/// Lebar maksimum isi teks bacaan supaya baris tidak terlalu panjang.
const readableTextWidth = 720.0;

/// Tinggi baris chip filter yang ikut skala font sistem (tinggi tetap 52 membuat
/// chip terpotong di skala font besar).
double chipRowHeight(BuildContext context) => math.max(52, MediaQuery.textScalerOf(context).scale(40) + 12);

/// Grid kartu sampul + judul yang tinggi selnya ikut skala font sistem.
///
/// Sama dengan `SliverGridDelegateWithMaxCrossAxisExtent` + `childAspectRatio`,
/// tetapi bagian teks di bawah sampul ([textBlockHeight], pada font 1x) membesar
/// mengikuti [textScale]. Dengan rasio tetap, judul dua baris meluap di font besar.
class TextScaledGridDelegate extends SliverGridDelegate {
  const TextScaledGridDelegate({
    this.maxCrossAxisExtent = 160,
    this.aspectRatio = 0.56,
    this.spacing = 12,
    this.textBlockHeight = 62,
    this.textScale = 1,
  });

  final double maxCrossAxisExtent;
  final double aspectRatio;
  final double spacing;
  final double textBlockHeight;
  final double textScale;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final columns = math.max(1, (constraints.crossAxisExtent / (maxCrossAxisExtent + spacing)).ceil());
    final cellWidth = (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;
    final extra = textBlockHeight * (textScale.clamp(1.0, 3.0) - 1);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      mainAxisExtent: cellWidth / aspectRatio + extra,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(TextScaledGridDelegate old) =>
      old.maxCrossAxisExtent != maxCrossAxisExtent ||
      old.aspectRatio != aspectRatio ||
      old.spacing != spacing ||
      old.textBlockHeight != textBlockHeight ||
      old.textScale != textScale;
}
