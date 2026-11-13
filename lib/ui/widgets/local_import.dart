import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../sources/local/local_source.dart';
import '../router.dart';

/// Nama seri awal dari nama file: buang ekstensi dan penanda bab
/// ("Solo Leveling - Chapter 12.cbz" → "Solo Leveling").
String guessSeriesName(List<String> fileNames) {
  if (fileNames.isEmpty) return '';
  String clean(String name) {
    final dot = name.lastIndexOf('.');
    var s = dot > 0 ? name.substring(0, dot) : name;
    s = s.replaceAll('_', ' ');
    s = s.replaceFirst(
        RegExp(r'[\s\-–—:#,]*(?:vol(?:ume)?|ch(?:apter)?|bab|ep(?:isode)?|c|v)?\.?\s*\d+(?:[.,]\d+)?.*$', caseSensitive: false),
        '');
    return s.trim();
  }

  final names = fileNames.map(clean).where((s) => s.isNotEmpty).toList();
  if (names.isEmpty) return '';
  // Awalan bersama dari semua nama (per kata).
  var prefix = names.first.split(' ');
  for (final n in names.skip(1)) {
    final words = n.split(' ');
    var i = 0;
    while (i < prefix.length && i < words.length && prefix[i].toLowerCase() == words[i].toLowerCase()) {
      i++;
    }
    prefix = prefix.sublist(0, i);
  }
  final common = prefix.join(' ').trim();
  return common.isNotEmpty ? common : names.first;
}

/// Pilih CBZ/ZIP, tanya nama seri, salin ke folder lokal, lalu buka serinya.
Future<void> importLocalFiles(BuildContext context) async {
  final List<PlatformFile> picked;
  try {
    picked = await FilePicker.pickFiles(
      dialogTitle: 'Pilih komik (CBZ/ZIP)',
      type: FileType.custom,
      allowedExtensions: const ['cbz', 'zip'],
    );
  } catch (e) {
    if (context.mounted) _snack(context, 'Gagal membuka pemilih file: $e');
    return;
  }
  final files = picked.where((f) => LocalSource.isArchive(f.name)).toList();
  if (!context.mounted) return;
  if (files.isEmpty) {
    if (picked.isNotEmpty) _snack(context, 'Hanya file .cbz atau .zip yang bisa diimpor.');
    return;
  }

  final controller = TextEditingController(text: guessSeriesName([for (final f in files) f.name]));
  final series = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Impor ${files.length} file'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Satu file = satu bab. File disalin ke folder seri di bawah ini.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Judul seri', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Impor'),
        ),
      ],
    ),
  );
  if (series == null || series.isEmpty || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text('Menyalin…')]),
      ),
    ),
  );
  String? url;
  Object? error;
  try {
    url = await LocalSource.importFiles(series, [
      for (final f in files) (name: f.name, saveTo: f.xFile.saveTo),
    ]);
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  if (url == null) {
    _snack(context, 'Impor gagal: $error');
    return;
  }
  _snack(context, '${files.length} file diimpor ke "$series"');
  context.push(sourceMangaLocation(LocalSource.sourceId, url));
}

void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
