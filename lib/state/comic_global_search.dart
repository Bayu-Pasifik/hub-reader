import '../sources/local/local_source.dart';
import '../sources/models.dart';
import '../sources/source.dart';
import 'source_health_provider.dart';

/// Cakupan "Cari global" komik.
sealed class ComicSearchScope {
  const ComicSearchScope();
}

/// Sumber yang dipakai di favorit atau riwayat.
class UsedSourcesScope extends ComicSearchScope {
  const UsedSourcesScope();
}

/// Semua sumber satu bahasa.
class LanguageScope extends ComicSearchScope {
  const LanguageScope(this.lang);

  final String lang;
}

/// Sumber yang dicari untuk [scope].
///
/// Sumber 18+ ikut aturan [showNsfw]; sumber mati/rusak dilewati karena
/// pencariannya hampir pasti gagal. Sumber lokal hanya ikut di cakupan
/// "dipakai" (tidak punya bahasa situs). Urutan: sehat dulu, lalu nama.
List<MangaSource> comicSearchTargets(
  List<MangaSource> sources, {
  required ComicSearchScope scope,
  required Set<String> usedIds,
  required Map<String, SourceHealth> health,
  required bool showNsfw,
}) {
  final targets = sources.where((s) {
    if (!_usable(s, health, showNsfw)) return false;
    return switch (scope) {
      UsedSourcesScope() => usedIds.contains(s.id),
      LanguageScope(:final lang) => s is! LocalSource && s.lang == lang,
    };
  }).toList()
    ..sort((a, b) {
      final r = healthRank(health[a.id]).compareTo(healthRank(health[b.id]));
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return targets;
}

/// Jumlah sumber per bahasa yang bisa dicari (tanpa sumber lokal).
Map<String, int> comicSearchLanguages(
  List<MangaSource> sources, {
  required Map<String, SourceHealth> health,
  required bool showNsfw,
}) {
  final counts = <String, int>{};
  for (final s in sources) {
    if (s is LocalSource || !_usable(s, health, showNsfw)) continue;
    counts[s.lang] = (counts[s.lang] ?? 0) + 1;
  }
  return counts;
}

bool _usable(MangaSource s, Map<String, SourceHealth> health, bool showNsfw) {
  if (!showNsfw && s.contentWarning == ContentWarning.nsfw) return false;
  final status = health[s.id]?.status;
  return status != HealthStatus.dead && status != HealthStatus.broken;
}
