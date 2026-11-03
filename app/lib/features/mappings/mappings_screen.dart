import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/gesture_ui.dart';
import '../../core/models/gesture.dart';
import '../../state/config_controller.dart';

class MappingsScreen extends StatelessWidget {
  const MappingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ConfigController>();
    final cfg = ctrl.config;
    final editable = Gesture.values.where((g) => g != Gesture.unknown);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture mappings'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restore),
            onPressed: ctrl.reset,
          ),
        ],
      ),
      body: !ctrl.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final g in editable)
                  _MappingTile(
                    gesture: g,
                    command: cfg.commandFor(g),
                    onChanged: (c) => ctrl.setMapping(g, c),
                  ),
                const _LockedTile(),
                const SizedBox(height: 12),
                _ThresholdCard(
                  value: cfg.confidenceThreshold,
                  onCommit: ctrl.setThreshold,
                ),
                const SizedBox(height: 12),
                const _SafetyNote(),
              ],
            ),
    );
  }
}

class _MappingTile extends StatelessWidget {
  const _MappingTile({
    required this.gesture,
    required this.command,
    required this.onChanged,
  });

  final Gesture gesture;
  final CarCommand command;
  final ValueChanged<CarCommand> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(gesture.icon, size: 32),
        title: Text(gesture.label),
        trailing: DropdownButton<CarCommand>(
          value: command,
          underline: const SizedBox.shrink(),
          onChanged: (c) {
            if (c != null) onChanged(c);
          },
          items: [
            for (final c in CarCommand.values)
              DropdownMenuItem(value: c, child: Text(c.label)),
          ],
        ),
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  const _LockedTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Gesture.unknown.icon, size: 32),
        title: const Text('Unknown gesture'),
        subtitle: const Text('Always STOP (safety, not editable)'),
        trailing: const Icon(Icons.lock_outline),
      ),
    );
  }
}

class _ThresholdCard extends StatefulWidget {
  const _ThresholdCard({required this.value, required this.onCommit});

  final double value;
  final ValueChanged<double> onCommit;

  @override
  State<_ThresholdCard> createState() => _ThresholdCardState();
}

class _ThresholdCardState extends State<_ThresholdCard> {
  double? _dragging; // value shown while the thumb is moving

  @override
  Widget build(BuildContext context) {
    final v = _dragging ?? widget.value;
    final pct = (v * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confidence threshold',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Below $pct % the car stops, whatever the gesture.'),
            Slider(
              value: v,
              min: 0.5,
              max: 0.95,
              divisions: 9,
              label: '$pct %',
              onChanged: (x) => setState(() => _dragging = x),
              onChangeEnd: (x) {
                setState(() => _dragging = null);
                widget.onCommit((x * 100).round() / 100);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fixed safety rules: unknown gesture, low confidence or a lost '
                'glove always mean STOP.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}