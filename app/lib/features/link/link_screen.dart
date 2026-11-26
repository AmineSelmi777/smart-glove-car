import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/battery.dart';
import '../../core/calibration.dart';
import '../../core/drive_math.dart';
import '../../core/models/gateway_models.dart';
import '../../core/widgets/panel.dart';
import '../../data/gateway.dart';
import '../../state/link_controller.dart';
import '../../state/settings_controller.dart';

class LinkScreen extends StatelessWidget {
  const LinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final link = context.watch<LinkController>();
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Gateway link')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _ConnectionPanel(
                  key: ValueKey('${link.mode}:${link.host}:${link.port}:${link.secure}'),
                  link: link,
                ),
                const SizedBox(height: 16),
                _DevicesPanel(link: link),
                const SizedBox(height: 16),
                _GlovePanel(data: link.glove),
                const SizedBox(height: 16),
                _CalibrationPanel(link: link, settings: settings),
                const SizedBox(height: 16),
                _CarPanel(data: link.car),
                const SizedBox(height: 16),
                _EventsPanel(events: link.events),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionPanel extends StatefulWidget {
  const _ConnectionPanel({super.key, required this.link});
  final LinkController link;

  @override
  State<_ConnectionPanel> createState() => _ConnectionPanelState();
}

class _ConnectionPanelState extends State<_ConnectionPanel> {
  late final TextEditingController _host = TextEditingController(text: widget.link.host);
  late final TextEditingController _port = TextEditingController(text: '${widget.link.port}');
  late bool _secure = widget.link.secure;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _connect() => widget.link.apply(
        mode: LinkMode.gateway,
        host: _host.text.trim().isEmpty ? 'localhost' : _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 8080,
        secure: _secure,
      );

  Future<void> _testRest() async {
    final messenger = ScaffoldMessenger.of(context);
    final api = widget.link.api;
    if (api == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Demo mode has no REST API.')));
      return;
    }
    try {
      final ok = await api.health();
      messenger.showSnackBar(SnackBar(content: Text(ok ? 'REST /api/health: OK' : 'REST answered, not OK')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('REST failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final real = link.mode == LinkMode.gateway;
    final tt = Theme.of(context).textTheme;
    return Panel(
      title: 'Connection',
      trailing: _LinkChip(state: link.link, latencyMs: link.latencyMs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<LinkMode>(
            segments: const [
              ButtonSegment(value: LinkMode.demo, icon: Icon(Icons.science_outlined), label: Text('Demo', maxLines: 1, softWrap: false)),
              ButtonSegment(value: LinkMode.gateway, icon: Icon(Icons.hub_outlined), label: Text('Gateway', maxLines: 1, softWrap: false)),
            ],
            selected: {link.mode},
            onSelectionChanged: (s) {
              if (s.first == LinkMode.demo) {
                link.apply(mode: LinkMode.demo);
              } else {
                _connect();
              }
            },
          ),
          const SizedBox(height: 16),
          if (real) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _host,
                    decoration: const InputDecoration(labelText: 'Gateway address', hintText: '192.168.1.10'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Port'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Secure connection (https / wss)'),
              subtitle: const Text('Needs TLS on the gateway'),
              value: _secure,
              onChanged: (v) => setState(() => _secure = v),
            ),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(onPressed: _connect, icon: const Icon(Icons.power_settings_new), label: const Text('Connect')),
                OutlinedButton.icon(onPressed: _testRest, icon: const Icon(Icons.network_check), label: const Text('Test REST')),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'On a phone or an emulator, use the PC address printed by the gateway (not localhost) '
              'and allow Node.js through the Windows firewall (TCP 8080).',
              style: tt.bodySmall,
            ),
          ] else
            Text('Simulated glove and car, no server needed.', style: tt.bodySmall),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.state, required this.latencyMs});
  final LinkState state;
  final int? latencyMs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      LinkState.connected => ('Connected${latencyMs != null ? ' · $latencyMs ms' : ''}', Colors.green),
      LinkState.connecting => ('Connecting', Colors.orange),
      LinkState.disconnected => ('Disconnected', Colors.red),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.circle, size: 12, color: color),
      label: Text(label),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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

class _DevicesPanel extends StatelessWidget {
  const _DevicesPanel({required this.link});
  final LinkController link;

  String _describe(DeviceInfo d) =>
      d.online ? 'online · ${d.rate} packets/s${d.address != null ? ' · ${d.address}' : ''}' : 'offline';

  @override
  Widget build(BuildContext context) => Panel(
        title: 'Devices',
        child: Column(
          children: [
            _Row('Glove ESP32', _describe(link.status.glove)),
            _Row('Car ESP32', _describe(link.status.car)),
            if (link.status.ips.isNotEmpty) _Row('Gateway addresses', link.status.ips.join(', ')),
          ],
        ),
      );
}

class _GlovePanel extends StatelessWidget {
  const _GlovePanel({required this.data});
  final GloveData? data;

  @override
  Widget build(BuildContext context) {
    final g = data;
    return Panel(
      title: 'Glove telemetry',
      child: g == null
          ? const Text('No glove data yet')
          : Column(
              children: [
                _Row('Flex (ADC)', '${g.flex}'),
                _Row('Roll / pitch / yaw', '${g.roll.toStringAsFixed(1)}° / ${g.pitch.toStringAsFixed(1)}° / ${g.yaw.toStringAsFixed(1)}°'),
                _Row('Gyro x / y / z', '${g.gx.toStringAsFixed(0)} / ${g.gy.toStringAsFixed(0)} / ${g.gz.toStringAsFixed(0)} °/s'),
                _Row('Gesture', '${g.gesture} (${(g.confidence * 100).round()} %)'),
                if (g.batteryV != null) _Row('Battery', '${g.batteryV!.toStringAsFixed(2)} V'),
              ],
            ),
    );
  }
}

class _CarPanel extends StatelessWidget {
  const _CarPanel({required this.data});
  final CarData? data;

  @override
  Widget build(BuildContext context) {
    final c = data;
    return Panel(
      title: 'Car telemetry',
      child: c == null
          ? const Text('No car data yet')
          : Column(
              children: [
                _Row('Speed', '${c.speedKmh.toStringAsFixed(1)} km/h'),
                _Row('Motors rpm FL / FR / RL / RR', c.rpm.join(' / ')),
                _Row('Motor power (0-255)', c.pwm.join(' / ')),
                if (c.volts != null)
                  _Row('Battery', '${c.volts!.toStringAsFixed(2)} V · ${lipoPercent(c.volts!).round()} %'),
                if (c.rssi != null) _Row('Wi-Fi signal', '${c.rssi} dBm'),
                _Row('Lights', c.lights ? 'on' : 'off'),
                _Row('Emergency stop', c.estop ? 'ACTIVE' : 'off'),
              ],
            ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({required this.events});
  final List<GatewayEvent> events;

  Color _color(String level) => switch (level) {
        'ok' => Colors.green,
        'warn' => Colors.orange,
        'error' => Colors.red,
        _ => Colors.blueGrey,
      };

  String _hms(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final shown = events.take(25).toList();
    return Panel(
      title: 'Live events',
      child: shown.isEmpty
          ? const Text('No events yet')
          : Column(
              children: [
                for (final e in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: _color(e.level)),
                        const SizedBox(width: 10),
                        Text(_hms(e.ts), style: tt.bodySmall),
                        const SizedBox(width: 12),
                        SizedBox(width: 56, child: Text(e.source, style: tt.bodySmall)),
                        Expanded(
                          child: Text(
                            e.message.isEmpty ? e.code : '${e.code} · ${e.message}',
                            style: tt.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CalibrationPanel extends StatefulWidget {
  const _CalibrationPanel({required this.link, required this.settings});
  final LinkController link;
  final SettingsController settings;

  @override
  State<_CalibrationPanel> createState() => _CalibrationPanelState();
}

class _CalibrationPanelState extends State<_CalibrationPanel> {
  bool _busy = false;
  String? _msg;

  Future<void> _capture(bool open) async {
    setState(() {
      _busy = true;
      _msg = open ? 'Hold your hand open...' : 'Make a fist and hold...';
    });
    final v = await captureFlex(widget.link.gloveLive);
    if (!mounted) return;
    if (v == null) {
      setState(() {
        _busy = false;
        _msg = 'No glove data. Check the link first.';
      });
      return;
    }
    await widget.settings.setFlexCalibration(open: open ? v : null, closed: open ? null : v);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = '${open ? 'Open' : 'Fist'} captured: $v';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Panel(
      title: 'Flex calibration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<GloveData?>(
            valueListenable: widget.link.gloveLive,
            builder: (context, g, _) {
              final o = g == null ? 0.0 : openness(g.flex, s.flexOpen, s.flexClosed);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row('Live flex', g == null ? '-' : '${g.flex}'),
                  _Row('Calibrated open / fist', '${s.flexOpen} / ${s.flexClosed}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: o, minHeight: 8),
                  const SizedBox(height: 4),
                  Text('Openness ${(o * 100).round()} %'),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _busy ? null : () => _capture(true), child: const Text('Capture open hand')),
              FilledButton(onPressed: _busy ? null : () => _capture(false), child: const Text('Capture fist')),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => s.setFlexCalibration(
                          open: SettingsController.defaultFlexOpen,
                          closed: SettingsController.defaultFlexClosed,
                        ),
                child: const Text('Reset'),
              ),
            ],
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!)),
        ],
      ),
    );
  }
}
