import 'dart:typed_data';

/// Area isi gambar setelah tepi polos dibuang, dalam pecahan 0..1.
class ContentBounds {
  const ContentBounds(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is ContentBounds &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'ContentBounds($left, $top, $right, $bottom)';
}

int _luma(Uint8List px, int i) => px[i + 3] < 16 ? 255 : (px[i] * 299 + px[i + 1] * 587 + px[i + 2] * 114) ~/ 1000;

/// Cari tepi polos (putih atau hitam) di gambar RGBA [width]x[height].
///
/// Warna latar diambil dari keempat sudut; bila sudutnya tidak seragam
/// terang/gelap, gambar dianggap tanpa tepi. Baris/kolom dianggap isi bila
/// ada >1% sampel yang bedanya jelas dari latar (tahan terhadap noise JPEG).
/// [vertical] false = hanya kiri-kanan (mode webtoon, strip harus menyambung).
///
/// Mengembalikan null bila tidak ada yang layak dipotong.
ContentBounds? findContentBounds(Uint8List rgba, int width, int height, {bool vertical = true}) {
  if (width < 8 || height < 8 || rgba.length < width * height * 4) return null;
  int at(int x, int y) => _luma(rgba, (y * width + x) * 4);

  final corners = [at(0, 0), at(width - 1, 0), at(0, height - 1), at(width - 1, height - 1)];
  final int background;
  if (corners.every((c) => c >= 225)) {
    background = 255;
  } else if (corners.every((c) => c <= 30)) {
    background = 0;
  } else {
    return null;
  }
  const threshold = 48;
  bool content(int x, int y) => (at(x, y) - background).abs() > threshold;

  bool rowHasContent(int y) {
    final step = width > 300 ? width ~/ 300 : 1;
    var hits = 0, samples = 0;
    for (var x = 0; x < width; x += step) {
      samples++;
      if (content(x, y)) hits++;
    }
    return hits * 100 > samples;
  }

  bool columnHasContent(int x, int top, int bottom) {
    final span = bottom - top;
    final step = span > 600 ? span ~/ 600 : 1;
    var hits = 0, samples = 0;
    for (var y = top; y < bottom; y += step) {
      samples++;
      if (content(x, y)) hits++;
    }
    return hits * 100 > samples;
  }

  var top = 0, bottom = height;
  if (vertical) {
    while (top < height && !rowHasContent(top)) {
      top++;
    }
    if (top >= height) return null; // Halaman polos: biarkan apa adanya.
    while (bottom > top && !rowHasContent(bottom - 1)) {
      bottom--;
    }
  }
  var left = 0, right = width;
  while (left < width && !columnHasContent(left, top, bottom)) {
    left++;
  }
  if (left >= width) return null;
  while (right > left && !columnHasContent(right - 1, top, bottom)) {
    right--;
  }

  // Sisakan sedikit napas supaya teks tidak menempel ke tepi layar.
  final padX = (width * 0.01).round(), padY = (height * 0.01).round();
  left = (left - padX).clamp(0, width);
  right = (right + padX).clamp(0, width);
  if (vertical) {
    top = (top - padY).clamp(0, height);
    bottom = (bottom + padY).clamp(0, height);
  }

  final keptArea = (right - left) * (bottom - top);
  // Tidak sepadan (<2% terpotong) atau mencurigakan (isi <25% gambar).
  if (keptArea > width * height * 0.98 || keptArea < width * height * 0.25) return null;
  return ContentBounds(left / width, top / height, right / width, bottom / height);
}
