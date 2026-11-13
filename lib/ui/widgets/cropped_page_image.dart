import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/image_borders.dart';
import '../../state/reader_settings_provider.dart';

/// Halaman komik dengan tepi polos dipotong.
///
/// Deteksi tepi memakai salinan kecil gambar (lebar ≤256 px) di isolate,
/// lalu gambar asli digambar dengan `drawImageRect`. Hasil deteksi disimpan
/// per URL supaya gulir balik tidak menghitung ulang.
class CroppedPageImage extends StatefulWidget {
  const CroppedPageImage({
    super.key,
    required this.cacheKey,
    required this.image,
    required this.vertical,
    required this.placeholder,
    required this.error,
  });

  /// Kunci cache hasil deteksi (URL atau path halaman).
  final String cacheKey;
  final ImageProvider image;

  /// false = hanya potong kiri-kanan (mode webtoon).
  final bool vertical;
  final WidgetBuilder placeholder;
  final WidgetBuilder error;

  @override
  State<CroppedPageImage> createState() => _CroppedPageImageState();
}

class _CroppedPageImageState extends State<CroppedPageImage> {
  static final _bounds = <String, ContentBounds?>{};
  static const _maxCached = 300;

  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;
  ContentBounds? _crop;
  bool _measured = false;
  bool _failed = false;

  String get _key => '${widget.vertical ? 'v' : 'h'}|${widget.cacheKey}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(CroppedPageImage old) {
    super.didUpdateWidget(old);
    if (old.cacheKey != widget.cacheKey || old.vertical != widget.vertical) {
      _measured = false;
      _crop = null;
      _resolve();
    }
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key && _listener != null) return;
    _detach();
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return info.dispose();
        setState(() {
          _info?.dispose();
          _info = info;
          _failed = false;
        });
        _measure();
      },
      onError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
    );
    _stream = stream..addListener(_listener!);
  }

  Future<void> _measure() async {
    final key = _key;
    if (_bounds.containsKey(key)) {
      setState(() {
        _crop = _bounds[key];
        _measured = true;
      });
      return;
    }
    ContentBounds? found;
    try {
      found = await _detect(widget.image, widget.vertical);
    } on Object {
      found = null;
    }
    _bounds[key] = found;
    while (_bounds.length > _maxCached) {
      _bounds.remove(_bounds.keys.first);
    }
    if (!mounted || key != _key) return;
    setState(() {
      _crop = found;
      _measured = true;
    });
  }

  static Future<ContentBounds?> _detect(ImageProvider provider, bool vertical) async {
    final small = ResizeImage(provider, width: 256, height: 4096, policy: ResizeImagePolicy.fit);
    final completer = Completer<ui.Image>();
    final stream = small.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image.clone());
        info.dispose();
      },
      onError: (e, s) {
        stream.removeListener(listener);
        completer.completeError(e, s);
      },
    );
    stream.addListener(listener);
    final image = await completer.future;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final w = image.width, h = image.height;
      final bytes = data.buffer.asUint8List();
      return await compute((_) => findContentBounds(bytes, w, h, vertical: vertical), null);
    } finally {
      image.dispose();
    }
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.error(context);
    final info = _info;
    if (info == null || !_measured) return widget.placeholder(context);
    final image = info.image;
    final crop = _crop ?? const ContentBounds(0, 0, 1, 1);
    final src = Rect.fromLTRB(
      crop.left * image.width,
      crop.top * image.height,
      crop.right * image.width,
      crop.bottom * image.height,
    );
    return AspectRatio(
      aspectRatio: src.width / src.height,
      child: CustomPaint(painter: _CropPainter(image, src)),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.src);

  final ui.Image image;
  final Rect src;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      src,
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.image != image || old.src != src;
}

/// Matriks warna untuk filter halaman (abu-abu, balik warna).
List<double>? readerColorMatrix(ReaderDisplay display) {
  if (!display.grayscale && !display.invert) return null;
  var m = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0,
  ];
  if (display.grayscale) {
    m = <double>[
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
  if (display.invert) {
    m = [
      for (var row = 0; row < 4; row++)
        for (var col = 0; col < 5; col++)
          row == 3
              ? m[row * 5 + col]
              : col == 4
                  ? 255 - m[row * 5 + col]
                  : -m[row * 5 + col],
    ];
  }
  return m;
}

/// Bungkus isi reader dengan filter warna + lapisan redup.
Widget applyReaderFilters(ReaderDisplay display, Widget child) {
  var out = child;
  final matrix = readerColorMatrix(display);
  if (matrix != null) out = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: out);
  if (display.dim > 0) {
    out = Stack(
      fit: StackFit.passthrough,
      children: [
        out,
        Positioned.fill(
          child: IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: display.dim))),
        ),
      ],
    );
  }
  return out;
}
