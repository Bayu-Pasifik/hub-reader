import 'dart:io';
import '../../../core/i18n/strings.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/download.dart';
import '../../../novels/epub_writer.dart';
import '../../../novels/local_epub.dart';
import '../../../novels/novel_models.dart';
import '../../../state/download_providers.dart';
import '../../../state/novel_providers.dart';

/// Ekspor novel ke file EPUB: pilih cakupan bab, ambil isinya (dari unduhan
/// bila ada, kalau tidak dari situs), lalu simpan lewat dialog sistem.
Future<void> exportNovelEpub(
  BuildContext context,
  WidgetRef ref, {
  required String pluginId,
  required String path,
  required NovelDetails details,
}) async {
  void snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  // Semua bab, termasuk plugin yang daftar babnya berhalaman.
  var chapters = details.chapters;
  if (details.totalPages > 1) {
    try {
      chapters = [
        for (var p = 1; p <= details.totalPages; p++)
          ...await ref.read(novelChapterPageProvider((pluginId: pluginId, path: path, page: p)).future),
      ];
    } catch (e) {
      if (context.mounted) snack('Gagal memuat daftar bab: $e');
      return;
    }
  }
  if (!context.mounted) return;
  if (chapters.isEmpty) {
    snack('Novel ini belum punya bab.');
    return;
  }
  final index = ref.read(downloadIndexProvider);
  final libraryId = novelLibraryId(pluginId);
  final downloaded = chapters.where((c) => index.containsKey(chapterKey(libraryId, c.path))).toList();
  final local = pluginId == LocalNovelSource.pluginId;

  final scope = await showDialog<List<NovelChapter>>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(tr('Ekspor ke EPUB')),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, chapters),
          child: ListTile(
            title: Text('Semua bab (${chapters.length})'),
            subtitle: Text(local || downloaded.length == chapters.length
                ? 'Tanpa internet'
                : 'Bab yang belum diunduh diambil dari situs'),
          ),
        ),
        if (!local && downloaded.isNotEmpty && downloaded.length < chapters.length)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, downloaded),
            child: ListTile(
              title: Text('Hanya yang sudah diunduh (${downloaded.length})'),
              subtitle: Text(tr('Tanpa internet')),
            ),
          ),
      ],
    ),
  );
  if (scope == null || !context.mounted) return;

  // Urutan EPUB: bab pertama dulu, apa pun urutan dari plugin.
  final ordered = [...scope];
  final numbers = ordered.map((c) => c.number).toList();
  if (numbers.every((n) => n != null) && numbers.length > 1 && numbers.first! > numbers.last!) {
    ordered.setAll(0, ordered.reversed.toList());
  }

  final progress = ValueNotifier<int>(0);
  var cancelled = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(tr('Mengekspor…')),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, done, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: done / ordered.length),
              const SizedBox(height: 12),
              Text('Bab $done dari ${ordered.length}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.of(dialogContext).pop();
            },
            child: Text(tr('Batal')),
          ),
        ],
      ),
    ),
  );

  final out = <EpubChapter>[];
  final failed = <String>[];
  for (final c in ordered) {
    if (cancelled) break;
    try {
      final html = await ref.read(novelChapterProvider((pluginId: pluginId, path: c.path)).future);
      out.add(EpubChapter(title: c.name, html: html));
    } catch (_) {
      failed.add(c.name);
    }
    progress.value++;
  }

  Uint8List? cover;
  final coverUrl = details.cover;
  if (!cancelled && coverUrl != null) {
    try {
      if (coverUrl.startsWith('http')) {
        final source = ref.read(loadedNovelSourceProvider(pluginId));
        final res = await Dio().get<List<int>>(
          coverUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: source?.imageHeaders,
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
        if (res.data != null) cover = Uint8List.fromList(res.data!);
      } else {
        cover = await File(coverUrl).readAsBytes();
      }
    } catch (_) {
      cover = null; // sampul opsional
    }
  }

  if (!cancelled && context.mounted) Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  if (cancelled || !context.mounted) return;
  if (out.isEmpty) {
    snack('Tidak ada bab yang berhasil dimuat.');
    return;
  }

  final lang = ref.read(loadedNovelSourceProvider(pluginId))?.lang ?? 'id';
  final bytes = EpubWriter(
    title: details.name,
    author: details.author,
    description: details.summary,
    subjects: details.genres,
    language: RegExp(r'^[a-z]{2,3}(-[A-Za-z]+)?$').hasMatch(lang) ? lang : 'id',
    cover: cover,
    chapters: out,
    identifier: 'urn:hub-reader:$pluginId:$path',
  ).build();
  final name = '${details.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim()}.epub';
  try {
    final saved = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/epub+zip',
      dialogTitle: 'Simpan EPUB',
    );
    if (!context.mounted || saved == null) return;
    snack(failed.isEmpty
        ? 'EPUB disimpan: $name (${out.length} bab)'
        : 'EPUB disimpan: ${out.length} bab, ${failed.length} bab gagal dimuat dan dilewati');
  } catch (e) {
    if (context.mounted) snack('Gagal menyimpan: $e');
  }
}
