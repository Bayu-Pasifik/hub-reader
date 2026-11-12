import '../../core/utils/json.dart';
import 'series.dart';

class HomeSection {
  const HomeSection({required this.key, required this.title, required this.items});

  final String key;
  final String title;
  final List<Series> items;
}

/// Respons GET /api/v1/home: `{"data": {"<nama_section>": [SeriesResource, ...]}}`.
///
/// `continue_reading` hanya muncul bila request membawa token Sanctum dan
/// bentuknya LibraryEntryResource, jadi diabaikan. Aplikasi memakai riwayat
/// lokal untuk "Lanjutkan membaca".
class HomeSections {
  const HomeSections(this.sections);

  final List<HomeSection> sections;

  static const _titles = {
    'novels_recently_updated': 'Novel baru diperbarui',
    'novels_most_chapters': 'Novel dengan bab terbanyak',
    'novels_completed': 'Novel tamat',
    'comics_recently_updated': 'Komik baru diperbarui',
  };

  static const _ignored = {'continue_reading'};

  bool get isEmpty => sections.every((s) => s.items.isEmpty);

  factory HomeSections.fromJson(JsonMap json) {
    final data = asMap(json['data']);
    // Section yang dikenal tampil dulu sesuai urutan di HomeController,
    // section baru dari server tetap ditampilkan di bawahnya.
    final keys = [
      ..._titles.keys.where(data.containsKey),
      ...data.keys.where((k) => !_titles.containsKey(k) && !_ignored.contains(k)),
    ];
    final sections = <HomeSection>[];
    for (final key in keys) {
      final items = asList(data[key])
          .map((e) => Series.tryParse(asMap(e)))
          .whereType<Series>()
          .toList(growable: false);
      if (items.isEmpty) continue;
      sections.add(HomeSection(
        key: key,
        title: _titles[key] ?? _humanize(key),
        items: items,
      ));
    }
    return HomeSections(sections);
  }

  static String _humanize(String key) {
    final text = key.replaceAll('_', ' ');
    return text.isEmpty ? key : text[0].toUpperCase() + text.substring(1);
  }
}
