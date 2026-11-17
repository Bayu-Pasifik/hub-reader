import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:hub_reader/ui/widgets/continue_reading.dart';

SourceHistoryEntry _h(String id, int minute) => SourceHistoryEntry(
      item: SourceLibraryItem(sourceId: 's', url: 'u$id', title: 'T$id'),
      chapterUrl: 'c$id',
      chapterName: 'Bab $id',
      readAt: DateTime(2026, 11, 17, 10, minute),
    );

void main() {
  test('terbaru dulu dan dibatasi', () {
    final picked = ContinueReadingStrip.pick([_h('a', 1), _h('b', 9), _h('c', 5)], limit: 2);
    expect(picked.map((e) => e.item.title), ['Tb', 'Tc']);
  });

  test('riwayat kosong menghasilkan daftar kosong', () {
    expect(ContinueReadingStrip.pick(const []), isEmpty);
  });
}
