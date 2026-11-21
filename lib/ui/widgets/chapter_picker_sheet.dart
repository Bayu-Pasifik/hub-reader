import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';

/// Satu baris di daftar bab pada reader.
typedef ChapterPickerEntry = ({String id, String title, bool read, bool bookmarked});

/// Lembar bawah berisi daftar bab; ketuk satu bab untuk pindah tanpa keluar
/// dari reader. Bab yang sedang dibaca disorot dan daftar langsung menggulir
/// ke posisinya.
Future<void> showChapterPickerSheet(
  BuildContext context, {
  required List<ChapterPickerEntry> chapters,
  required String currentId,
  required void Function(String id) onSelect,
  String? subtitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ChapterPicker(
      chapters: chapters,
      currentId: currentId,
      subtitle: subtitle,
      onSelect: (id) {
        Navigator.pop(ctx);
        if (id != currentId) onSelect(id);
      },
    ),
  );
}

class _ChapterPicker extends StatefulWidget {
  const _ChapterPicker({required this.chapters, required this.currentId, required this.onSelect, this.subtitle});

  final List<ChapterPickerEntry> chapters;
  final String currentId;
  final String? subtitle;
  final void Function(String id) onSelect;

  @override
  State<_ChapterPicker> createState() => _ChapterPickerState();
}

class _ChapterPickerState extends State<_ChapterPicker> {
  static const _rowHeight = 56.0;
  late final ScrollController _scroll;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final i = widget.chapters.indexWhere((c) => c.id == widget.currentId);
    // Bab saat ini ditaruh sedikit di bawah tepi atas daftar.
    _scroll = ScrollController(initialScrollOffset: i <= 1 ? 0 : (i - 1) * _rowHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? widget.chapters : [for (final c in widget.chapters) if (c.title.toLowerCase().contains(q)) c];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Daftar bab'), style: theme.textTheme.titleMedium),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('${widget.chapters.length}', style: theme.textTheme.labelLarge),
                ],
              ),
            ),
            if (widget.chapters.length > 12)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: tr('Cari bab'),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text(tr('Tidak ada')))
                  : ListView.builder(
                      // Controller hanya dipakai tanpa filter, supaya posisi awal tidak aneh.
                      controller: q.isEmpty ? _scroll : null,
                      itemExtent: _rowHeight,
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final c = shown[i];
                        final current = c.id == widget.currentId;
                        return ListTile(
                          selected: current,
                          selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                          title: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: current ? FontWeight.w800 : null,
                              color: c.read && !current ? theme.disabledColor : null,
                            ),
                          ),
                          leading: current ? const Icon(Icons.auto_stories) : null,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (c.bookmarked) const Icon(Icons.bookmark, size: 18),
                            if (c.read && !current) const Icon(Icons.check, size: 18),
                          ]),
                          onTap: () => widget.onSelect(c.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
