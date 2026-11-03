import 'package:flutter/material.dart';

import 'features/live/live_screen.dart';

import 'features/mappings/mappings_screen.dart';

class SmartGloveApp extends StatelessWidget {
  const SmartGloveApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Smart Glove',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
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
    LiveScreen(),
    MappingsScreen(),
    _ComingSoon('Command history'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.sensors), label: 'Live'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Mappings'),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          ],
        ),
      );
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Coming soon')),
      );
}