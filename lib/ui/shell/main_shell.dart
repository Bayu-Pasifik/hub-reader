import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell, required this.tabs});

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
