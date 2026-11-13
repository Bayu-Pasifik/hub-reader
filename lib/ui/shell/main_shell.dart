import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
