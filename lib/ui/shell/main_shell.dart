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

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // Cek bab baru favorit sebentar setelah aplikasi dibuka (bila sudah waktunya).
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) ref.read(libraryUpdatesProvider.notifier).maybeAutoCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final unseen = ref.watch(libraryUpdatesProvider.select((s) => s.unseen));
    final incognito = ref.watch(appSettingsProvider.select((s) => s.incognito));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (incognito)
            Material(
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
            ),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            ),
            destinations: [
              for (final tab in widget.tabs)
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: tab.path == '/favorites' && unseen > 0,
                    label: Text('$unseen'),
                    child: Icon(tab.icon),
                  ),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
