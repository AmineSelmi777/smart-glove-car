import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'glove_view.dart';


import '../../core/battery.dart';
import '../../core/drive_math.dart';
import '../../core/theme/axis_colors.dart';
import '../../core/widgets/panel.dart';
import '../../data/gateway.dart';
import '../../state/drive_controller.dart';
import '../../state/link_controller.dart';
import '../../state/settings_controller.dart';
import 'controls_panel.dart';
import 'drive_pad.dart';
import 'gauges.dart';
import 'wheels_view.dart';

class DriveScreen extends StatelessWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final link = context.watch<LinkController>();
    final settings = context.watch<SettingsController>();
    final drive = context.watch<DriveController>();

    final car = link.car;
    final control = deriveControl(car);
    final speed = car?.speedKmh ?? 0;
    final gears = activeGears(
      estop: (car?.estop ?? false) || drive.estop,
      reverse: control.reverse,
      boost: drive.boost,
      speedKmh: speed,
    );

    final camera = Panel(
      title: 'Car camera',
      trailing: _Pill(
        dot: link.status.car.online ? context.ax.green : context.ax.amber,
        label: link.status.car.online ? 'Real car' : (link.mode == LinkMode.demo ? 'Demo' : 'No car'),
      ),
      padding: EdgeInsets.zero,
      child: const _Placeholder(icon: Icons.videocam_outlined, text: 'Camera stream: next step (ESP32-CAM address in Settings)', ratio: 16 / 9),
    );
    final manual = Panel(title: 'Manual drive', child: const DrivePad());
    final glove = Panel(
      title: 'Glove',
      child: _GloveSummary(link: link, settings: settings),
    );
    final map = Panel(
      title: 'Map',
      padding: EdgeInsets.zero,
      child: const _Placeholder(icon: Icons.map_outlined, text: 'Trajectory map: next step', ratio: 3 / 2),
    );
    final wheels = Panel(title: 'Wheels', child: Center(child: WheelsView(rpm: car?.rpm ?? const [0, 0, 0, 0])));
    final speedPanel = Panel(
      title: 'Speed',
      trailing: Text(link.mode == LinkMode.demo ? 'Demo' : 'Car', style: TextStyle(fontSize: 12, color: context.ax.muted)),
      child: Center(
        child: SpeedGauge(
          speedKmh: speed,
          top: speedGaugeTop(settings.maxSpeedKmh),
          throttle: control.throttle,
          gears: gears,
        ),
      ),
    );
    final volts = car?.volts;
    final battery = Panel(
      title: 'Battery',
      child: Center(
        child: FuelGauge(
          percent: volts == null ? 0 : lipoPercent(volts),
          volts: volts,
          gloveVolts: link.glove?.batteryV,
          simulated: link.mode == LinkMode.demo,
        ),
      ),
    );
    final controls = Panel(title: 'Controls', child: ControlsPanel(control: control));

    return LayoutBuilder(builder: (context, box) {
      const gap = SizedBox(width: 12, height: 12);
      final Widget content;
      if (box.maxWidth >= 1000) {
        content = Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: Column(children: [camera, gap, manual])),
                gap,
                Expanded(flex: 2, child: Column(children: [glove, gap, map])),
              ],
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: wheels),
                gap,
                Expanded(child: speedPanel),
                gap,
                Expanded(child: battery),
                gap,
                Expanded(child: controls),
              ],
            ),
          ],
        );
      } else {
        content = Column(
          children: [camera, gap, glove, gap, manual, gap, speedPanel, gap, battery, gap, wheels, gap, controls, gap, map],
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1400), child: content),
        ),
      );
    });
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text, required this.ratio});
  final IconData icon;
  final String text;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    return AspectRatio(
      aspectRatio: ratio,
      child: Container(
        color: c.bg2,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.lineStrong),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.dot});
  final String label;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Icon(Icons.circle, size: 8, color: dot),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(fontSize: 12, color: c.text2)),
        ],
      ),
    );
  }
}

/// Glove readouts. The 3D glove replaces the placeholder in the next step.
class _GloveSummary extends StatelessWidget {
  const _GloveSummary({required this.link, required this.settings});
  final LinkController link;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    final g = link.glove;
    final open = g == null ? 0.0 : openness(g.flex, settings.flexOpen, settings.flexClosed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GloveView(source: link.gloveLive, flexOpen: settings.flexOpen, flexClosed: settings.flexClosed),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(label: 'Open ${(open * 100).round()}%'),
            _Pill(label: 'Roll ${(g?.roll ?? 0).round()}°'),
            _Pill(label: 'Pitch ${(g?.pitch ?? 0).round()}°'),
            if (g != null && g.gesture != 'none') _Pill(label: g.gesture, dot: c.amber),
          ],
        ),
      ],
    );
  }
}