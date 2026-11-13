import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/novels/novel_browse_screen.dart';
import 'screens/novels/novel_detail_screen.dart';
import 'screens/novels/novel_global_search_screen.dart';
import 'screens/novels/novel_reader_screen.dart';
import 'screens/novels/novel_sources_screen.dart';
import 'screens/sources/downloads_screen.dart';
import 'screens/app_settings_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/migrate_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/updates_screen.dart';
import 'screens/sources/source_browse_screen.dart';
import 'screens/sources/source_favorites_screen.dart';
import 'screens/sources/source_history_screen.dart';
import 'screens/sources/source_manga_screen.dart';
import 'screens/sources/source_reader_screen.dart';
import 'screens/sources/source_webview_screen.dart';
import 'screens/sources/sources_screen.dart';
import 'shell/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

String sourceBrowseLocation(String sourceId) => '/source/${Uri.encodeComponent(sourceId)}';

String sourceMangaLocation(String sourceId, String mangaUrl) => Uri(
      path: '/source/${Uri.encodeComponent(sourceId)}/manga',
      queryParameters: {'url': mangaUrl},
    ).toString();

String sourceReaderLocation(String sourceId, String mangaUrl, String chapterUrl) => Uri(
      path: '/source/${Uri.encodeComponent(sourceId)}/read',
      queryParameters: {'manga': mangaUrl, 'chapter': chapterUrl},
    ).toString();

String novelBrowseLocation(String pluginId) => '/novel/${Uri.encodeComponent(pluginId)}';

String novelDetailLocation(String pluginId, String path) => Uri(
      path: '/novel/${Uri.encodeComponent(pluginId)}/info',
      queryParameters: {'path': path},
    ).toString();

String novelReaderLocation(String pluginId, String novelPath, String chapterPath, {int page = 1}) => Uri(
      path: '/novel/${Uri.encodeComponent(pluginId)}/read',
      queryParameters: {'novel': novelPath, 'chapter': chapterPath, if (page > 1) 'page': '$page'},
    ).toString();

String novelGlobalSearchLocation([String query = '']) =>
    Uri(path: '/novel-search', queryParameters: query.isEmpty ? null : {'q': query}).toString();

String migrateLocation(String sourceId, String url, String title) =>
    Uri(path: '/migrate', queryParameters: {'source': sourceId, 'url': url, 'title': title}).toString();

/// [storagePluginId]: plugin novel yang membaca `localStorage` situs; isi
/// storage WebView disalin ke plugin saat layar ditutup.
String sourceWebViewLocation(String url, {String? storagePluginId}) => Uri(
      path: '/webview',
      queryParameters: {'url': url, if (storagePluginId != null) 'plugin': storagePluginId},
    ).toString();

/// Rute:
///   /sources, /favorites, /history         → tab (sumber on-device)
///   /source/:sid                           → jelajah satu sumber on-device
///   /source/:sid/manga?url=                → detail seri dari sumber
///   /source/:sid/read?manga=&chapter=      → pembaca bab dari sumber
///   /novels                                → tab sumber novel (plugin LNReader)
///   /novel/:pid, /novel/:pid/info?path=,   → jelajah, detail, pembaca novel
///   /novel/:pid/read?novel=&chapter=&page=
final routerProvider = Provider<GoRouter>((ref) {
  final tabs = <ShellTab>[
    const ShellTab('/sources', Icons.extension_outlined, Icons.extension, 'Komik'),
    const ShellTab('/novels', Icons.menu_book_outlined, Icons.menu_book, 'Novel'),
    const ShellTab('/favorites', Icons.favorite_outline, Icons.favorite, 'Favorit'),
    const ShellTab('/history', Icons.history_outlined, Icons.history, 'Riwayat'),
  ];

  Widget tabScreen(String path) => switch (path) {
        '/favorites' => const SourceFavoritesScreen(),
        '/history' => const SourceHistoryScreen(),
        '/novels' => const NovelSourcesScreen(),
        _ => const SourcesScreen(),
      };

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/sources',
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
      GoRoute(
        path: '/migrate',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => MigrateScreen(
          sourceId: state.uri.queryParameters['source'] ?? '',
          url: state.uri.queryParameters['url'] ?? '',
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(
        path: '/app-settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const AppSettingsScreen(),
      ),
      GoRoute(
        path: '/backup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const BackupScreen(),
      ),
      GoRoute(
        path: '/stats',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const StatsScreen(),
      ),
      GoRoute(
        path: '/updates',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const UpdatesScreen(),
      ),
      GoRoute(
        path: '/downloads',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/webview',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => SourceWebViewScreen(
          url: state.uri.queryParameters['url'] ?? '',
          storagePluginId: state.uri.queryParameters['plugin'],
        ),
      ),
      GoRoute(
        path: '/novel-search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => NovelGlobalSearchScreen(initialQuery: state.uri.queryParameters['q'] ?? ''),
      ),
      GoRoute(
        path: '/novel/:pid',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => NovelBrowseScreen(pluginId: state.pathParameters['pid'] ?? ''),
        routes: [
          GoRoute(
            path: 'info',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) => NovelDetailScreen(
              pluginId: state.pathParameters['pid'] ?? '',
              path: state.uri.queryParameters['path'] ?? '',
            ),
          ),
          GoRoute(
            path: 'read',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, state) => NovelReaderScreen(
              pluginId: state.pathParameters['pid'] ?? '',
              novelPath: state.uri.queryParameters['novel'] ?? '',
              chapterPath: state.uri.queryParameters['chapter'] ?? '',
              page: int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 1,
            ),
          ),
        ],
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
