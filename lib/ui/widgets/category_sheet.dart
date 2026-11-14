import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/source_library.dart';
import '../../state/source_library_providers.dart';

/// Pilih kategori untuk satu favorit ([key] = `SourceLibraryItem.key`).
Future<void> showCategorySheet(BuildContext context, String key) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => CategorySheet(itemKey: key),
    );

class CategorySheet extends ConsumerWidget {
  const CategorySheet({super.key, required this.itemKey});

  final String itemKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(libraryCategoriesProvider);
    final current = ref.watch(sourceFavoritesProvider.select(
      (list) => list.where((f) => f.item.key == itemKey).firstOrNull?.categories ?? const <String>[],
    ));
    final favorites = ref.read(sourceFavoritesProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(tr('Kategori'), style: Theme.of(context).textTheme.titleMedium),
            ),
            if (categories.isEmpty)
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text(tr('Belum ada kategori')),
                subtitle: Text(tr('Buat kategori di bawah untuk mengelompokkan favorit.')),
              ),
            for (final c in categories)
              CheckboxListTile(
                title: Text(c),
                value: current.contains(c),
                onChanged: (v) => favorites.setCategories(
                  itemKey,
                  v == true ? [...current, c] : current.where((x) => x != c).toList(),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(tr('Kategori baru')),
              onTap: () async {
                final name = await askCategoryName(context, title: tr('Kategori baru'));
                if (name == null) return;
                if (await ref.read(libraryCategoriesProvider.notifier).add(name)) {
                  await favorites.setCategories(itemKey, [...current, name.trim()]);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> askCategoryName(BuildContext context, {required String title, String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: tr('Nama kategori')),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(tr('Simpan'))),
      ],
    ),
  );
}

/// Bila [item] mirip favorit yang sudah ada (judul sama, sumber lain), tanya
/// dulu. Mengembalikan true bila boleh lanjut menambahkan.
Future<bool> confirmAddDuplicateFavorite(BuildContext context, WidgetRef ref, SourceLibraryItem item) async {
  final dup = findDuplicateFavorite(ref.read(sourceFavoritesProvider), item);
  if (dup == null) return true;
  final source = dup.item.sourceId.replaceFirst('lnr:', '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Judul sudah ada di favorit')),
      content: Text('"${dup.item.title}" sudah ada di favorit dari sumber $source. Tetap tambahkan dari sumber ini?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Batal'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Tambahkan'))),
      ],
    ),
  );
  return ok == true;
}
