import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/gesture_ui.dart';
import '../../core/models/control_mode.dart';
import '../../core/models/glove_state.dart';
import '../../core/widgets/panel.dart';
import '../../state/glove_controller.dart';
import '../../state/manual_controller.dart';
import 'manual_control_panel.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GloveController>().state;
    final manualMode =
        context.watch<ManualController>().mode == ControlMode.manual;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [_SourceChip(), SizedBox(width: 16)],
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final status = Column(
                children: [
                  const _ModePanel(),
                  const SizedBox(height: 16),
                  _GesturePanel(state: s, ignored: manualMode),
                  const SizedBox(height: 16),
                  _CommandPanel(state: s),
                  const SizedBox(height: 16),
                  _SpeedPanel(state: s),
                ],
              );
              const control = ManualControlPanel();
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: status),
                              const SizedBox(width: 24),
                              const Expanded(flex: 2, child: control),
                            ],
                          )
                        : Column(
                            children: [status, const SizedBox(height: 16), control],
                          ),
                  ),
                ),
              );
            }),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip();

  @override
  Widget build(BuildContext context) => const Chip(
        avatar: Icon(Icons.science_outlined, size: 18),
        label: Text('Simulated data'),
        visualDensity: VisualDensity.compact,
      );
}

class _ModePanel extends StatelessWidget {
  const _ModePanel();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ManualController>();
    final manual = ctrl.mode == ControlMode.manual;
    return Panel(
      title: 'Control mode',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<ControlMode>(
            segments: const [
              ButtonSegment(
                value: ControlMode.gesture,
                icon: Icon(Icons.back_hand_outlined),
                label: Text('Gesture'),
              ),
              ButtonSegment(
                value: ControlMode.manual,
                icon: Icon(Icons.gamepad_outlined),
                label: Text('Manual'),
              ),
            ],
            selected: {ctrl.mode},
            onSelectionChanged: (s) => ctrl.setMode(s.first),
          ),
          const SizedBox(height: 12),
          Text(
            manual
                ? 'The car follows the arrow controls. Gestures are ignored.'
                : 'The car follows the glove. Manual controls are disabled.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GesturePanel extends StatelessWidget {
  const _GesturePanel({required this.state, required this.ignored});
  final GloveState state;
  final bool ignored;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = (state.confidence * 100).round();
    return Panel(
      title: 'Recognized gesture',
      trailing: ignored
          ? Text('Not used in manual mode', style: tt.bodySmall)
          : null,
      child: Opacity(
        opacity: ignored ? 0.45 : 1,
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(state.gesture.icon, size: 40, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.gesture.label, style: tt.headlineSmall),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: state.confidence,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Confidence $pct %', style: tt.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandPanel extends StatelessWidget {
  const _CommandPanel({required this.state});
  final GloveState state;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = state.command;
    final manual = state.mode == ControlMode.manual;
    return Panel(
      title: 'Car command',
      trailing: Text(manual ? 'Source: manual' : 'Source: glove', style: tt.bodySmall),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: c.color.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.color.shade300),
            ),
            child: Text(
              c.label,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.color.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedPanel extends StatelessWidget {
  const _SpeedPanel({required this.state});
  final GloveState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Panel(
      title: 'Speed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${state.speed}', style: tt.headlineLarge),
              const SizedBox(width: 6),
              Text('/ 255', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
              const Spacer(),
              Text('${(state.speed / 255 * 100).round()} %', style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(value: state.speed / 255, minHeight: 10),
          ),
          const SizedBox(height: 16),
          _KeyValue('Flex sensor (ADC)', '${state.flex}'),
          if (state.batteryPct != null) _KeyValue('Battery', '${state.batteryPct} %'),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium),
          Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}