import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/bookmarks_provider.dart';
import '../../state/source_library_providers.dart';

/// Dialog ubah catatan seri. Teks kosong menghapus catatan.
Future<void> editSeriesNote(BuildContext context, WidgetRef ref, SourceItemKey series) async {
  final controller = TextEditingController(text: ref.read(seriesNoteProvider(series)) ?? '');
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Catatan'),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Mis. berhenti di arc turnamen, lanjut baca versi novel…',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        if (controller.text.isNotEmpty)
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Hapus')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Simpan')),
      ],
    ),
  );
  controller.dispose();
  if (value != null) await ref.read(seriesNotesProvider.notifier).set(series, value);
}

/// Kartu catatan di header detail seri; tidak tampil bila kosong.
class SeriesNoteCard extends ConsumerWidget {
  const SeriesNoteCard({super.key, required this.series});

  final SourceItemKey series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(seriesNoteProvider(series));
    if (note == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => editSeriesNote(context, ref, series),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 20, color: scheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(note, style: TextStyle(color: scheme.onSecondaryContainer)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ikon kecil penanda bab ber-bookmark di daftar bab.
class ChapterBookmarkIcon extends StatelessWidget {
  const ChapterBookmarkIcon({super.key});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.bookmark, size: 18, color: Theme.of(context).colorScheme.primary, semanticLabel: 'Ditandai');
}
