import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';

/// Dialog catatan untuk satu sorotan. Mengembalikan teks catatan (kosong =
/// hapus catatan) atau null bila dibatalkan.
Future<String?> askHighlightNote(BuildContext context, {required String quote, String initial = ''}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _HighlightNoteDialog(quote: quote, initial: initial),
    );

class _HighlightNoteDialog extends StatefulWidget {
  const _HighlightNoteDialog({required this.quote, required this.initial});

  final String quote;
  final String initial;

  @override
  State<_HighlightNoteDialog> createState() => _HighlightNoteDialogState();
}

class _HighlightNoteDialogState extends State<_HighlightNoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(tr('Catatan sorotan')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.quote,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr('Tulis catatan…')),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initial.isNotEmpty)
          TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(tr('Hapus catatan'))),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(tr('Simpan'))),
      ],
    );
  }
}
