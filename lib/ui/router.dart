import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/utils/formatters.dart';
import '../data/models/series.dart';
import 'screens/browse_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/series_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sources/source_browse_screen.dart';
import 'screens/sources/source_favorites_screen.dart';
import 'screens/sources/source_history_screen.dart';
import 'screens/sources/source_manga_screen.dart';
import 'screens/sources/source_reader_screen.dart';
import 'screens/sources/source_webview_screen.dart';
import 'screens/sources/sources_screen.dart';
import 'shell/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

String seriesLocation(SeriesType type, int id) => '/series/${type.name}/$id';

String readerLocation(SeriesType type, int id, double chapterNumber) =>
    '/read/${type.name}/$id/${formatChapterNumber(chapterNumber)}';

String sourceBrowseLocation(String sourceId) => '/source/${Uri.encodeComponent(sourceId)}';

String sourceMangaLocation(String sourceId, String mangaUrl) => Uri(
      path: '/source/${Uri.encodeComponent(sourceId)}/manga',
      queryParameters: {'url': mangaUrl},
    ).toString();

String sourceReaderLocation(String sourceId, String mangaUrl, String chapterUrl) => Uri(
      path: '/source/${Uri.encodeComponent(sourceId)}/read',
      queryParameters: {'manga': mangaUrl, 'chapter': chapterUrl},
    ).toString();

String sourceWebViewLocation(String url) =>
    Uri(path: '/webview', queryParameters: {'url': url}).toString();

/// Rute:
///   /sources, /favorites, /history         → tab (sumber on-device)
///   /home, /browse                         → tab scraper-hub (hanya bila
///                                            AppConfig.enableScraperHub)
///   /series/:type/:id, /read/..., /settings → layar scraper-hub (idem)
///   /source/:sid                           → jelajah satu sumber on-device
///   /source/:sid/manga?url=                → detail seri dari sumber
///   /source/:sid/read?manga=&chapter=      → pembaca bab dari sumber
final routerProvider = Provider<GoRouter>((ref) {
  const hub = AppConfig.enableScraperHub;
  final tabs = <ShellTab>[
    if (hub) ...const [
      ShellTab('/home', Icons.home_outlined, Icons.home, 'Beranda'),
      ShellTab('/browse', Icons.explore_outlined, Icons.explore, 'Jelajah'),
    ],
    const ShellTab('/sources', Icons.extension_outlined, Icons.extension, 'Sumber'),
    const ShellTab('/favorites', Icons.favorite_outline, Icons.favorite, 'Favorit'),
    const ShellTab('/history', Icons.history_outlined, Icons.history, 'Riwayat'),
  ];

  Widget tabScreen(String path) => switch (path) {
        '/home' => const HomeScreen(),
        '/browse' => const BrowseScreen(),
        '/favorites' => const SourceFavoritesScreen(),
        '/history' => const SourceHistoryScreen(),
        _ => const SourcesScreen(),
      };

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: hub ? '/home' : '/sources',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell, tabs: tabs),
        branches: [
          for (final tab in tabs)
            StatefulShellBranch(routes: [
              GoRoute(path: tab.path, builder: (_, __) => tabScreen(tab.path)),
            ]),
        ],
      ),
      if (hub) ...[
        GoRoute(
          path: '/series/:type/:id',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, state) => SeriesDetailScreen(
            type: SeriesType.fromApi(state.pathParameters['type']),
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: '/read/:type/:id/:chapter',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, state) => ReaderScreen(
            type: SeriesType.fromApi(state.pathParameters['type']),
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            initialChapter: double.tryParse(state.pathParameters['chapter'] ?? '') ?? 1,
          ),
        ),
        GoRoute(
          path: '/settings',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
      GoRoute(
        path: '/webview',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => SourceWebViewScreen(url: state.uri.queryParameters['url'] ?? ''),
      ),
      GoRoute(
        path: '/source/:sid',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => SourceBrowseScreen(sourceId: state.pathParameters['sid'] ?? ''),
        routes: [
          GoRoute(
            path: 'manga',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) => SourceMangaScreen(
              sourceId: state.pathParameters['sid'] ?? '',
              url: state.uri.queryParameters['url'] ?? '',
            ),
          ),
          GoRoute(
            path: 'read',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) => SourceReaderScreen(
              sourceId: state.pathParameters['sid'] ?? '',
              mangaUrl: state.uri.queryParameters['manga'] ?? '',
              chapterUrl: state.uri.queryParameters['chapter'] ?? '',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
  );
});
