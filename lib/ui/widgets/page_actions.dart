import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/strings.dart';
import '../../core/platform/media_bridge.dart';
import '../../state/series_overrides.dart';
import '../../state/source_library_providers.dart';

/// Jenis gambar dari byte awalnya (PNG, JPEG, GIF, WebP); selain itu dianggap JPEG.
({String ext, String mime}) sniffImage(List<int> b) {
  bool at(int i, List<int> sig) => b.length >= i + sig.length && [for (var k = 0; k < sig.length; k++) b[i + k]].toString() == sig.toString();
  if (at(0, const [0x89, 0x50, 0x4E, 0x47])) return (ext: 'png', mime: 'image/png');
  if (at(0, const [0x47, 0x49, 0x46])) return (ext: 'gif', mime: 'image/gif');
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) && at(8, const [0x57, 0x45, 0x42, 0x50])) return (ext: 'webp', mime: 'image/webp');
  return (ext: 'jpg', mime: 'image/jpeg');
}

/// Nama berkas aman dari nama bab + nomor halaman: tanpa karakter terlarang, maks. 80 karakter.
String pageFileName(String chapterName, int page, String ext) {
  final base = chapterName.replaceAll(RegExp(r'[\/:*?"<>|\x00-\x1f]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final clipped = base.length > 80 ? base.substring(0, 80).trim() : base;
  final p = page.toString().padLeft(3, '0');
  return '${clipped.isEmpty ? 'page' : clipped}_p$p.$ext';
}

/// Byte gambar halaman: file unduhan, atau dari cache gambar (tanpa unduh ulang bila sudah tampil).
Future<Uint8List> loadPageBytes(String url, Map<String, String> headers) async {
  if (!url.startsWith('http')) return File(url).readAsBytes();
  final file = await DefaultCacheManager().getSingleFile(url, headers: headers);
  return file.readAsBytes();
}

/// Menu tekan lama pada halaman komik: simpan ke galeri, bagikan, atau jadikan sampul seri.
Future<void> showPageActions(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  required Map<String, String> headers,
  required int page,
  required String chapterName,
  required SourceItemKey series,
}) {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> run(Future<void> Function(Uint8List bytes, ({String ext, String mime}) kind) action) async {
    try {
      final bytes = await loadPageBytes(url, headers);
      await action(bytes, sniffImage(bytes));
    } catch (e) {
      say(trp('Gagal: {e}', {'e': e}));
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(trp('Halaman {n}', {'n': page + 1}), style: Theme.of(sheet).textTheme.titleMedium),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(tr('Simpan ke galeri')),
            onTap: () {
              Navigator.pop(sheet);
              run((bytes, kind) async {
                final name = pageFileName(chapterName, page + 1, kind.ext);
                final uri = await MediaBridge.saveImage(bytes, name, kind.mime);
                if (uri != null) {
                  say(tr('Disimpan di Pictures/Hub Reader'));
                } else {
                  // Android 9 ke bawah: dialog simpan sistem.
                  final saved = await FilePicker.saveFile(fileName: name, bytes: bytes, dialogTitle: tr('Simpan ke galeri'));
                  if (saved != null) say(tr('Gambar disimpan'));
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(tr('Bagikan halaman')),
            onTap: () {
              Navigator.pop(sheet);
              run((bytes, kind) async {
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/${pageFileName(chapterName, page + 1, kind.ext)}');
                await file.writeAsBytes(bytes, flush: true);
                await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: kind.mime)]));
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(tr('Jadikan sampul seri')),
            onTap: () {
              Navigator.pop(sheet);
              run((bytes, kind) async {
                final notifier = ref.read(seriesOverridesProvider.notifier);
                final path = await notifier.storeCover(series, bytes, 'page.${kind.ext}');
                final current = ref.read(seriesOverrideProvider(series)) ?? const SeriesOverride();
                await notifier.set(series, current.copyWith(coverPath: () => path));
                say(tr('Sampul seri diganti'));
              });
            },
          ),
        ],
      ),
    ),
  );
}
