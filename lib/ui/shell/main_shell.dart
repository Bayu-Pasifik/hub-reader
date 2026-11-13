import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_settings_provider.dart';
import '../../state/library_updates_provider.dart';

/// Satu tab di bottom navigation.
class ShellTab {
  const ShellTab(this.path, this.icon, this.selectedIcon, this.label);

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Kerangka dengan bottom navigation. IndexedStack dari go_router menjaga
/// state tiap tab (posisi scroll, hasil pencarian) saat berpindah tab.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell, required this.tabs});

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cek bab baru favorit sebentar setelah aplikasi dibuka (bila sudah waktunya).
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) ref.read(libraryUpdatesProvider.notifier).maybeAutoCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(libraryUpdatesProvider.notifier).reload();
  }

  /// Lebar minimum (dp) untuk rail navigasi di samping (tablet / lipat / landscape).
  static const railBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final unseen = ref.watch(libraryUpdatesProvider.select((s) => s.unseen));
    final incognito = ref.watch(appSettingsProvider.select((s) => s.incognito));
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;

    void select(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);
    Widget icon(ShellTab tab) => Badge(
          isLabelVisible: tab.path == '/favorites' && unseen > 0,
          label: Text('$unseen'),
          child: Icon(tab.icon),
        );

    final banner = !incognito
        ? null
        : Material(
            color: scheme.tertiaryContainer,
            child: InkWell(
              onTap: () => ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(incognito: false)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_off, size: 14, color: scheme.onTertiaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      'Mode samaran · ketuk untuk mematikan',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  ],
                ),
              ),
            ),
          );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: select,
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.85,
                destinations: [
                  for (final tab in widget.tabs)
                    NavigationRailDestination(
                      icon: icon(tab),
                      selectedIcon: Icon(tab.selectedIcon),
                      label: Text(tab.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  if (banner != null) SafeArea(bottom: false, child: banner),
                  Expanded(child: shell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (banner != null) banner,
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: select,
            destinations: [
              for (final tab in widget.tabs)
                NavigationDestination(icon: icon(tab), selectedIcon: Icon(tab.selectedIcon), label: tab.label),
            ],
          ),
        ],
      ),
    );
  }
}
