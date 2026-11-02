import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/gesture_ui.dart';
import '../../core/models/glove_state.dart';
import '../../state/glove_controller.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GloveController>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Live')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _GestureCard(state: s),
                const SizedBox(height: 12),
                _CommandCard(state: s),
                const SizedBox(height: 12),
                _SpeedCard(state: s),
              ],
            ),
    );
  }
}

class _GestureCard extends StatelessWidget {
  const _GestureCard({required this.state});
  final GloveState state;

  @override
  Widget build(BuildContext context) {
    final pct = (state.confidence * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(state.gesture.icon, size: 64),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.gesture.label,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: state.confidence),
                  const SizedBox(height: 4),
                  Text('Confidence: $pct %'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({required this.state});
  final GloveState state;

  @override
  Widget build(BuildContext context) {
    final c = state.command;
    return Card(
      child: ListTile(
        title: const Text('Car command'),
        trailing: Chip(
          label: Text(c.label),
          backgroundColor: c.color.shade100,
        ),
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.state});
  final GloveState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Speed', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${state.speed} / 255',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: state.speed / 255, minHeight: 12),
            const SizedBox(height: 8),
            Text('Flex sensor (ADC): ${state.flex}'),
          ],
        ),
      ),
    );
  }
}