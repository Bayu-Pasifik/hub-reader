import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/models/download.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/scanlator.dart';
import 'package:shared_preferences/shared_preferences.dart';

SourceChapter ch(String name, {String? group}) => SourceChapter(url: 'u/$name', name: name, scanlator: group);

void main() {
  test('group comes from the field first, then a [Group] name prefix', () {
    expect(chapterGroup(ch('Ch 1', group: 'Alpha')), 'Alpha');
    expect(chapterGroup(ch('[Beta] Ch 2')), 'Beta');
    expect(chapterGroup(ch('[Beta] Ch 2', group: 'Alpha')), 'Alpha');
    expect(chapterGroup(ch('Ch 3 [not a prefix]')), isNull);
    expect(chapterGroup(ch('Ch 4', group: '  ')), isNull);
  });

  test('counts are sorted by size and skip ungrouped chapters', () {
    final counts = groupCounts([ch('[B] 1'), ch('[A] 2'), ch('[A] 3'), ch('4')]);
    expect(counts.keys.toList(), ['A', 'B']);
    expect(counts['A'], 2);
  });

  test('hidden groups filter chapters but ungrouped chapters always show', () {
    final a = ch('[A] 1');
    final b = ch('[B] 2');
    final none = ch('3');
    expect([a, b, none].where((c) => chapterVisible(c, {'A'})), [b, none]);
    expect([a, b, none].where((c) => chapterVisible(c, {})), [a, b, none]);
  });

  test('hidden groups persist per series', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ScanlatorFilter.write(prefs, 's|one', {'A', 'B'});
    expect(ScanlatorFilter.read(prefs, 's|one'), {'A', 'B'});
    expect(ScanlatorFilter.read(prefs, 's|two'), isEmpty);
    await ScanlatorFilter.write(prefs, 's|one', {});
    expect(ScanlatorFilter.read(prefs, 's|one'), isEmpty);
  });

  test('download task keeps the scanlator through save and restore', () {
    final task = DownloadTask(
      sourceId: 's',
      mangaUrl: 'm',
      mangaTitle: 'T',
      chapter: ch('Ch 1', group: 'Alpha'),
    );
    expect(DownloadTask.tryParse(task.toJson())!.chapter.scanlator, 'Alpha');
  });
}
