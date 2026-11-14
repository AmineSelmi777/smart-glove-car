import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/gesture_ui.dart';
import '../../core/models/control_mode.dart';
import '../../core/models/gesture.dart';
import '../../core/widgets/panel.dart';
import '../../state/manual_controller.dart';

class ManualControlPanel extends StatefulWidget {
  const ManualControlPanel({super.key});

  @override
  State<ManualControlPanel> createState() => _ManualControlPanelState();
}

class _ManualControlPanelState extends State<ManualControlPanel>
    with WidgetsBindingObserver {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Window hidden or inactive: never keep driving.
    if (state != AppLifecycleState.resumed) {
      context.read<ManualController>().release();
    }
  }

  static CarCommand? _commandFor(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return CarCommand.forward;
    if (key == LogicalKeyboardKey.arrowLeft) return CarCommand.turnLeft;
    if (key == LogicalKeyboardKey.arrowRight) return CarCommand.turnRight;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.arrowDown) {
      return CarCommand.stop;
    }
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final command = _commandFor(event.logicalKey);
    if (command == null) return KeyEventResult.ignored;
    final ctrl = context.read<ManualController>();
    if (event is KeyDownEvent) {
      ctrl.press(
        command,
        stillHeld: () =>
            HardwareKeyboard.instance.isLogicalKeyPressed(event.logicalKey),
      );
    }
    if (event is KeyUpEvent) ctrl.release();
    return KeyEventResult.handled; // key repeats are swallowed, the controller refreshes by itself
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ManualController>();
    final enabled = ctrl.mode == ControlMode.manual;
    final tt = Theme.of(context).textTheme;

    Widget pad(IconData icon, String label, CarCommand command) => _PadButton(
          icon: icon,
          label: label,
          command: command,
          enabled: enabled,
          pressed: ctrl.pressed == command,
          onDown: () {
            _focus.requestFocus();
            ctrl.press(command);
          },
          onUp: ctrl.release,
        );

    const gap = SizedBox(width: 8, height: 8);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      onFocusChange: (hasFocus) {
        if (!hasFocus) context.read<ManualController>().release();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focus.requestFocus,
        child: Panel(
          title: 'Manual control',
          trailing: _StateTag(active: enabled),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: _PadButton.size),
                  gap,
                  pad(Icons.keyboard_arrow_up, 'Forward', CarCommand.forward),
                  gap,
                  const SizedBox(width: _PadButton.size),
                ],
              ),
              gap,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pad(Icons.keyboard_arrow_left, 'Turn left', CarCommand.turnLeft),
                  gap,
                  pad(Icons.stop_rounded, 'Stop', CarCommand.stop),
                  gap,
                  pad(Icons.keyboard_arrow_right, 'Turn right', CarCommand.turnRight),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Manual speed', style: tt.labelLarge),
                  const Spacer(),
                  Text('${ctrl.speed} / 255', style: tt.labelLarge),
                ],
              ),
              Slider(
                value: ctrl.speed.toDouble(),
                min: 0,
                max: 255,
                divisions: 51,
                label: '${ctrl.speed}',
                onChanged: enabled ? (v) => ctrl.setSpeed(v.round()) : null,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ctrl.emergencyStop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Car stopped. Manual control engaged.'),
                    ),
                  );
                },
                icon: const Icon(Icons.stop_circle),
                label: const Text('EMERGENCY STOP'),
              ),
              const SizedBox(height: 12),
              Text(
                enabled
                    ? 'Hold an arrow to move, release to stop. Keyboard: arrow keys to drive, Space to stop.'
                    : 'Switch to Manual mode to enable the controls.',
                style: tt.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.icon,
    required this.label,
    required this.command,
    required this.enabled,
    required this.pressed,
    required this.onDown,
    required this.onUp,
  });

  static const double size = 76;

  final IconData icon;
  final String label;
  final CarCommand command;
  final bool enabled;
  final bool pressed;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = command.color;

    final Color background;
    final Color border;
    final Color foreground;
    if (!enabled) {
      background = cs.surfaceContainerHighest;
      border = cs.outlineVariant;
      foreground = cs.onSurface.withAlpha(90);
    } else if (pressed) {
      background = accent.shade700;
      border = accent.shade900;
      foreground = Colors.white;
    } else {
      background = cs.surface;
      border = cs.outline;
      foreground = accent.shade700;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => onDown() : null,
        onTapUp: enabled ? (_) => onUp() : null,
        onTapCancel: enabled ? onUp : null, // finger or pointer dragged away: stop
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: pressed ? 2 : 1),
          ),
          child: Icon(icon, size: 40, color: foreground),
        ),
      ),
    );
  }
}

class _StateTag extends StatelessWidget {
  const _StateTag({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade100 : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        active ? 'ACTIVE' : 'DISABLED',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: active ? Colors.green.shade900 : cs.onSurfaceVariant,
            ),
      ),
    );
  }
}