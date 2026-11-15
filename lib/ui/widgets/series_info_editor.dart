import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../state/series_overrides.dart';
import '../../state/source_library_providers.dart';

/// Dialog ubah info seri: judul, penulis, deskripsi, dan sampul dari galeri/file.
/// Kolom yang sama dengan data situs (atau dikosongkan) kembali mengikuti situs.
/// [siteTitle]/[siteAuthor]/[siteDescription] adalah data asli dari situs.
Future<void> editSeriesInfo(
  BuildContext context,
  WidgetRef ref,
  SourceItemKey series, {
  required String siteTitle,
  String? siteAuthor,
  String? siteDescription,
}) async {
  final notifier = ref.read(seriesOverridesProvider.notifier);
  final current = ref.read(seriesOverrideProvider(series)) ?? const SeriesOverride();

  final result = await showDialog<_Result>(
    context: context,
    builder: (_) => _SeriesInfoDialog(
      current: current,
      siteTitle: siteTitle,
      siteAuthor: siteAuthor,
      siteDescription: siteDescription,
    ),
  );
  if (result == null) return;

  if (result.reset) {
    await notifier.set(series, const SeriesOverride());
    return;
  }
  // Sama dengan data situs = tidak ada override untuk kolom itu.
  String? diff(String text, String? site) => (text.isEmpty || text == (site ?? '').trim()) ? null : text;
  var cover = result.clearCover ? null : current.coverPath;
  if (result.newBytes != null) cover = await notifier.storeCover(series, result.newBytes!, result.newName);
  await notifier.set(
    series,
    SeriesOverride(
      title: diff(result.title, siteTitle),
      author: diff(result.author, siteAuthor),
      description: diff(result.description, siteDescription),
      coverPath: cover,
    ),
  );
}

class _Result {
  const _Result({
    this.reset = false,
    this.title = '',
    this.author = '',
    this.description = '',
    this.newBytes,
    this.newName = '',
    this.clearCover = false,
  });

  final bool reset;
  final String title;
  final String author;
  final String description;
  final Uint8List? newBytes;
  final String newName;
  final bool clearCover;
}

class _SeriesInfoDialog extends StatefulWidget {
  const _SeriesInfoDialog({
    required this.current,
    required this.siteTitle,
    required this.siteAuthor,
    required this.siteDescription,
  });

  final SeriesOverride current;
  final String siteTitle;
  final String? siteAuthor;
  final String? siteDescription;

  @override
  State<_SeriesInfoDialog> createState() => _SeriesInfoDialogState();
}

class _SeriesInfoDialogState extends State<_SeriesInfoDialog> {
  // Controller dimiliki state dialog ini, jadi baru dibuang setelah animasi tutup selesai.
  late final _title = TextEditingController(text: widget.current.title ?? widget.siteTitle);
  late final _author = TextEditingController(text: widget.current.author ?? widget.siteAuthor ?? '');
  late final _description = TextEditingController(text: widget.current.description ?? widget.siteDescription ?? '');
  Uint8List? _newBytes;
  String _newName = '';
  bool _clearCover = false;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await FilePicker.pickFiles(dialogTitle: tr('Pilih sampul'), type: FileType.image);
    if (picked.isEmpty) return;
    final bytes = await picked.first.xFile.readAsBytes();
    if (!mounted) return;
    // Batas wajar supaya salinan sampul tidak membengkak.
    if (bytes.length > 8 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Gambar terlalu besar (maks. 8 MB)'))));
      return;
    }
    setState(() {
      _newBytes = bytes;
      _newName = picked.first.name;
      _clearCover = false;
    });
  }

  Widget _preview(BuildContext context) {
    final saved = _clearCover ? null : widget.current.usableCover;
    if (_newBytes != null) return Image.memory(_newBytes!, fit: BoxFit.cover, cacheWidth: 240);
    if (saved != null) return Image.file(File(saved), fit: BoxFit.cover, cacheWidth: 240);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.image_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomCover = _newBytes != null || (widget.current.usableCover != null && !_clearCover);
    return AlertDialog(
      title: Text(tr('Ubah info seri')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: tr('Judul'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _author,
              decoration: InputDecoration(labelText: tr('Penulis'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: tr('Deskripsi'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 72,
                  child: ClipRRect(borderRadius: BorderRadius.circular(6), child: _preview(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(tr('Pilih sampul')),
                        onPressed: _pickCover,
                      ),
                      if (hasCustomCover)
                        TextButton(
                          onPressed: () => setState(() {
                            _newBytes = null;
                            _clearCover = true;
                          }),
                          child: Text(tr('Pakai sampul situs')),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
        TextButton(
          onPressed: () => Navigator.pop(context, const _Result(reset: true)),
          child: Text(tr('Setel ulang')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _Result(
              title: _title.text.trim(),
              author: _author.text.trim(),
              description: _description.text.trim(),
              newBytes: _newBytes,
              newName: _newName,
              clearCover: _clearCover,
            ),
          ),
          child: Text(tr('Simpan')),
        ),
      ],
    );
  }
}
