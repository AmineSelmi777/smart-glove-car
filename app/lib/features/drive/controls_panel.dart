import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/drive_math.dart';
import '../../core/theme/axis_colors.dart';
import '../../state/drive_controller.dart';

class ControlsPanel extends StatelessWidget {
  const ControlsPanel({super.key, required this.control});
  final DerivedControl control;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    final drive = context.watch<DriveController>();
    final arrow = control.steer > 0.02 ? '→ ' : (control.steer < -0.02 ? '← ' : '');
    return Column(
      children: [
        _BarRow(
          label: 'Throttle',
          value: '${(control.throttle * 100).round()}%',
          child: _BarTrack(value: control.throttle, color: control.reverse ? c.cyan : c.amber),
        ),
        _BarRow(
          label: 'Steering',
          value: '$arrow${(control.steer.abs() * 100).round()}',
          child: _BarTrack(value: control.steer, color: c.cyan, centered: true),
        ),
        _BarRow(
          label: 'Left / right motors',
          value: '${(control.left * 100).round()} / ${(control.right * 100).round()}',
          child: Row(
            children: [
              Expanded(child: _BarTrack(value: control.left, color: c.green, centered: true)),
              const SizedBox(width: 6),
              Expanded(child: _BarTrack(value: control.right, color: c.green, centered: true)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: drive.estop ? c.red : c.red.withAlpha(36),
              foregroundColor: drive.estop ? Colors.white : c.red,
              side: BorderSide(color: c.red),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: drive.toggleEstop,
            child: Text(drive.estop ? 'RELEASE' : 'STOP', style: axisDisplay(size: 15)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Toggle(icon: Icons.bolt, label: 'Boost', active: drive.boost, onTap: drive.toggleBoost)),
            const SizedBox(width: 8),
            Expanded(
              child: _Toggle(icon: Icons.lightbulb_outline, label: 'Lights', active: drive.lights, onTap: drive.toggleLights),
            ),
          ],
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

    @override
  Widget build(BuildContext context) {
    final c = context.ax;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: active ? c.amber : c.text2,
        backgroundColor: active ? c.amber.withAlpha(36) : Colors.transparent,
        side: BorderSide(color: active ? c.amber : c.lineStrong),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.label, required this.value, required this.child});
  final String label, value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12.5, color: c.text2)),
              Text(value, style: axisDisplay(size: 13)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _BarTrack extends StatelessWidget {
  const _BarTrack({required this.value, required this.color, this.centered = false});
  final double value;
  final Color color;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final v = value < -1 ? -1.0 : (value > 1 ? 1.0 : value);
      final left = centered ? (v < 0 ? w / 2 + v * w / 2 : w / 2) : 0.0;
      final width = centered ? v.abs() * w / 2 : (v < 0 ? 0.0 : v * w);
      return SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            if (centered)
              Positioned(left: w / 2 - 0.5, top: 0, bottom: 0, width: 1, child: ColoredBox(color: c.lineStrong)),
            Positioned(
              left: left,
              top: 0,
              bottom: 0,
              width: width,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ],
        ),
      );
    });
  }
}