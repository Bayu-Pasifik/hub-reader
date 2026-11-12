import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/formatters.dart';
import '../data/models/series.dart';
import 'screens/browse_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/series_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sources/source_browse_screen.dart';
import 'screens/sources/source_manga_screen.dart';
import 'screens/sources/source_reader_screen.dart';
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

/// Rute:
///   /home, /browse, /favorites, /history, /sources → tab di bottom navigation
///   /series/:type/:id                      → detail seri
///   /read/:type/:id/:chapter               → pembaca bab
///   /settings                              → alamat server & API key
///   /source/:sid                           → jelajah satu sumber on-device
///   /source/:sid/manga?url=                → detail seri dari sumber
///   /source/:sid/read?manga=&chapter=      → pembaca bab dari sumber
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/browse', builder: (_, __) => const BrowseScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/sources', builder: (_, __) => const SourcesScreen()),
          ]),
        ],
      ),
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
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
  );
});
