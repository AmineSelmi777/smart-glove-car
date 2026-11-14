import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/history/history_screen.dart';
import 'features/mappings/mappings_screen.dart';

class SmartGloveApp extends StatelessWidget {
  const SmartGloveApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Smart Glove Control',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardScreen(),
    MappingsScreen(),
    HistoryScreen(),
  ];

  static const _items = [
    (label: 'Dashboard', icon: Icons.dashboard_outlined, selected: Icons.dashboard),
    (label: 'Mappings', icon: Icons.tune, selected: Icons.tune),
    (label: 'History', icon: Icons.history, selected: Icons.history),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps each tab alive (history filter, scroll position).
    final body = IndexedStack(index: _index, children: _pages);

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 800) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Icon(Icons.sensors,
                      size: 28, color: Theme.of(context).colorScheme.primary),
                ),
                destinations: [
                  for (final i in _items)
                    NavigationRailDestination(
                      icon: Icon(i.icon),
                      selectedIcon: Icon(i.selected),
                      label: Text(i.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      }
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final i in _items)
              NavigationDestination(
                icon: Icon(i.icon),
                selectedIcon: Icon(i.selected),
                label: i.label,
              ),
          ],
        ),
      );
    });
  }
}