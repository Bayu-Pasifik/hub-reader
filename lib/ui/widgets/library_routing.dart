import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/core_providers.dart';
import '../../state/novel_providers.dart';
import '../../state/source_providers.dart';
import '../router.dart';

/// Info tampilan & rute untuk item favorit/riwayat: komik (sumber on-device)
/// atau novel (plugin LNReader, id berawalan `lnr:`).
class LibrarySourceInfo {
  const LibrarySourceInfo({
    required this.name,
    required this.imageHeaders,
    required this.isNovel,
    required this.detailLocation,
    required this.readerLocation,
  });

  final String name;
  final Map<String, String> imageHeaders;
  final bool isNovel;
  final String Function(String url) detailLocation;
  final String Function(String url, String chapterUrl) readerLocation;
}

LibrarySourceInfo librarySourceInfo(WidgetRef ref, String sourceId) {
  if (isNovelSourceId(sourceId)) {
    final pluginId = pluginIdOf(sourceId);
    final loaded = ref.watch(loadedNovelSourceProvider(pluginId));
    final info = ref.watch(novelManifestProvider).valueOrNull?.byId(pluginId);
    return LibrarySourceInfo(
      name: loaded?.name ?? info?.name ?? pluginId,
      imageHeaders: loaded?.imageHeaders ?? const {},
      isNovel: true,
      detailLocation: (url) => novelDetailLocation(pluginId, url),
      readerLocation: (url, chapter) => novelReaderLocation(
        pluginId,
        url,
        chapter,
        page: ref.read(sharedPreferencesProvider).getInt('novels.page.$pluginId|$url') ?? 1,
      ),
    );
  }
  final source = ref.watch(sourceProvider(sourceId));
  return LibrarySourceInfo(
    name: source?.name ?? sourceId,
    imageHeaders: source?.imageHeaders() ?? const {},
    isNovel: false,
    detailLocation: (url) => sourceMangaLocation(sourceId, url),
    readerLocation: (url, chapter) => sourceReaderLocation(sourceId, url, chapter),
  );
}
