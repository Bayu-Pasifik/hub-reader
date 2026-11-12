import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chapter.dart';
import '../data/models/chapter_content.dart';
import '../data/models/filter_options.dart';
import '../data/models/home_sections.dart';
import '../data/models/series.dart';
import '../data/repositories/catalog_repository.dart';
import 'core_providers.dart';

/// Kunci family. Record Dart punya equality struktural, jadi aman dipakai
/// sebagai parameter provider.
typedef SeriesRef = ({SeriesType type, int id});
typedef ChapterRef = ({SeriesType type, int id, double number});

final homeProvider = FutureProvider.autoDispose<Fetched<HomeSections>>(
  (ref) => ref.watch(catalogRepositoryProvider).home(),
);

final filterOptionsProvider = FutureProvider<Fetched<FilterOptions>>(
  (ref) => ref.watch(catalogRepositoryProvider).filterOptions(),
);

final seriesDetailProvider =
    FutureProvider.autoDispose.family<Fetched<Series>, SeriesRef>(
  (ref, r) => ref.watch(catalogRepositoryProvider).series(r.type, r.id),
);

final chaptersProvider =
    FutureProvider.autoDispose.family<Fetched<List<Chapter>>, SeriesRef>(
  (ref, r) => ref.watch(catalogRepositoryProvider).chapters(r.type, r.id),
);

final chapterContentProvider =
    FutureProvider.autoDispose.family<ChapterContent?, ChapterRef>(
  (ref, r) => ref.watch(catalogRepositoryProvider).chapterContent(r.type, r.id, r.number),
);
