import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/gesture_ui.dart';
import '../../core/models/command_record.dart';
import '../../core/models/gesture.dart';
import '../../core/models/glove_state.dart';
import '../../state/glove_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  CarCommand? _filter; // null means all commands

  Widget _chip(String label, CarCommand? value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GloveController>();
    final records = _filter == null
        ? ctrl.history
        : ctrl.history.where((r) => r.command == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Command history'),
        actions: [
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_outline),
            onPressed: ctrl.history.isEmpty ? null : ctrl.clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _SpeedChart(states: ctrl.recent),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _chip('All', null),
                for (final c in CarCommand.values) _chip(c.label, c),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: records.isEmpty
                ? const Center(child: Text('No commands yet'))
                : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _RecordTile(records[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpeedChart extends StatelessWidget {
  const _SpeedChart({required this.states});
  final List<GloveState> states;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final spots = [
      for (var i = 0; i < states.length; i++)
        FlSpot(i.toDouble(), states[i].speed.toDouble()),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Speed (last ${states.length} samples)',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: spots.length < 2
                  ? const Center(child: Text('Waiting for data'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 255,
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: false,
                            color: color,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                                show: true, color: color.withAlpha(40)),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile(this.r);
  final CommandRecord r;

  String _hms(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (r.confidence * 100).round();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: r.command.color.shade100,
        child: Icon(r.gesture.icon, color: r.command.color.shade800),
      ),
      title: Text(r.command.label),
      subtitle: Text('${r.gesture.label} · $pct % · speed ${r.speed}'),
      trailing: Text(_hms(r.ts)),
    );
  }
}