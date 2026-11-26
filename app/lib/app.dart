import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/axis_colors.dart';
import 'data/gateway.dart';
import 'features/drive/drive_screen.dart';
import 'features/history/history_screen.dart';
import 'features/link/link_screen.dart';
import 'features/mappings/mappings_screen.dart';
import 'state/link_controller.dart';
import 'state/settings_controller.dart';

class SmartGloveApp extends StatelessWidget {
  const SmartGloveApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AXIS Gesture drive console',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: context.watch<SettingsController>().themeMode,
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
    DriveScreen(),
    LinkScreen(),
    MappingsScreen(),
    HistoryScreen(),
  ];

  static const _items = [
    (label: 'Drive', icon: Icons.speed_outlined),
    (label: 'Diagnostics', icon: Icons.monitor_heart_outlined),
    (label: 'Mappings', icon: Icons.tune),
    (label: 'History', icon: Icons.history),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 800;
      return Scaffold(
        body: Column(
          children: [
            _TopBar(
              wide: wide,
              index: _index,
              labels: [for (final i in _items) i.label],
              onSelect: (i) => setState(() => _index = i),
            ),
            Expanded(child: IndexedStack(index: _index, children: _pages)),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final i in _items) NavigationDestination(icon: Icon(i.icon), label: i.label),
                ],
              ),
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide, required this.index, required this.labels, required this.onSelect});
  final bool wide;
  final int index;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    final link = context.watch<LinkController>();
    final settings = context.watch<SettingsController>();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: c.bg2, border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Icon(Icons.change_history_rounded, color: c.amber),
          const SizedBox(width: 8),
          Text('AXIS', style: axisDisplay(size: 18, color: c.text)),
          if (wide) ...[
            const SizedBox(width: 10),
            Text('Gesture drive console', style: TextStyle(fontSize: 11.5, color: c.muted)),
            const SizedBox(width: 28),
            for (var i = 0; i < labels.length; i++)
              _Tab(label: labels[i], selected: i == index, onTap: () => onSelect(i)),
          ],
          const Spacer(),
          _Chip(label: 'Gateway', color: _linkColor(c, link.link), compact: !wide),
          _Chip(label: 'Glove', color: link.status.glove.online ? c.green : c.lineStrong, compact: !wide),
          _Chip(label: 'Car', color: link.status.car.online ? c.green : c.lineStrong, compact: !wide),
          IconButton(
            tooltip: 'Theme',
            icon: Icon(settings.themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: settings.toggleTheme,
          ),
        ],
      ),
    );
  }

  Color _linkColor(AxisColors c, LinkState s) => switch (s) {
        LinkState.connected => c.green,
        LinkState.connecting => c.amber,
        LinkState.disconnected => c.red,
      };
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? c.amber : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c.text : c.text2,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.compact});
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: c.text2)),
          ],
        ],
      ),
    );
  }
}