import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';

/// Genre dalam satu baris yang bisa digeser, supaya header detail tidak
/// memakan separuh layar saat genre banyak.
class GenreChips extends StatelessWidget {
  const GenreChips({super.key, required this.genres, this.onTap});

  final List<String> genres;

  /// Dipanggil saat genre diketuk (mis. cari seri bergenre sama). Null = chip biasa.
  final void Function(String genre)? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Center(
          child: onTap == null
              ? Chip(label: Text(genres[i]), visualDensity: VisualDensity.compact)
              : ActionChip(
                  label: Text(genres[i]),
                  visualDensity: VisualDensity.compact,
                  tooltip: trp('Cari genre {name}', {'name': genres[i]}),
                  onPressed: () => onTap!(genres[i]),
                ),
        ),
      ),
    );
  }
}

/// Deskripsi yang terpotong di [maxLines] baris, dengan tombol "Selengkapnya"
/// hanya bila teks memang terpotong.
class ExpandableDescription extends StatefulWidget {
  const ExpandableDescription({super.key, required this.text, this.maxLines = 4});

  final String text;
  final int maxLines;

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        final text = Text(
          widget.text,
          maxLines: _expanded ? null : widget.maxLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        );
        if (!overflows) return text;
        return Semantics(
          button: true,
          expanded: _expanded,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    _expanded ? tr('Ciutkan') : tr('Selengkapnya'),
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
