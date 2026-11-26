import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/gesture.dart';
import '../../core/theme/axis_colors.dart';
import '../../state/drive_controller.dart';

class DrivePad extends StatefulWidget {
  const DrivePad({super.key});

  @override
  State<DrivePad> createState() => _DrivePadState();
}

class _DrivePadState extends State<DrivePad> with WidgetsBindingObserver {
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
    if (state != AppLifecycleState.resumed) context.read<DriveController>().release();
  }

  static CarCommand? _commandFor(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) return CarCommand.forward;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) return CarCommand.turnLeft;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) return CarCommand.turnRight;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.arrowDown) return CarCommand.stop;
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final drive = context.read<DriveController>();
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyB) {
        drive.toggleBoost();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyL) {
        drive.toggleLights();
        return KeyEventResult.handled;
      }
    }
    final command = _commandFor(event.logicalKey);
    if (command == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      drive.press(
        command,
        stillHeld: () => HardwareKeyboard.instance.isLogicalKeyPressed(event.logicalKey),
      );
    }
    if (event is KeyUpEvent) drive.release();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final drive = context.watch<DriveController>();
    final c = context.ax;

    Widget pad(IconData icon, String label, CarCommand command, Color accent) => _PadButton(
          icon: icon,
          label: label,
          accent: accent,
          disabled: drive.estop,
          pressed: drive.pressed == command,
          onDown: () {
            _focus.requestFocus();
            drive.press(command);
          },
          onUp: drive.release,
        );

    const gap = SizedBox(width: 8, height: 8);
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      onFocusChange: (has) {
        if (!has) context.read<DriveController>().release();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focus.requestFocus,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: _PadButton.size),
                gap,
                pad(Icons.keyboard_arrow_up, 'Forward', CarCommand.forward, c.green),
                gap,
                const SizedBox(width: _PadButton.size),
              ],
            ),
            gap,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                pad(Icons.keyboard_arrow_left, 'Turn left', CarCommand.turnLeft, c.cyan),
                gap,
                pad(Icons.stop_rounded, 'Stop', CarCommand.stop, c.red),
                gap,
                pad(Icons.keyboard_arrow_right, 'Turn right', CarCommand.turnRight, c.cyan),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Speed', style: TextStyle(fontSize: 12.5, color: c.text2)),
                const Spacer(),
                Text('${(drive.speed * 100).round()} %', style: axisDisplay(size: 13)),
              ],
            ),
            Slider(
              value: drive.speed,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: drive.setSpeed,
            ),
            Text(
              'Hold to move, release to stop. Keys: arrows or W A D, Space stop, B boost, L lights.',
              style: TextStyle(fontSize: 11.5, color: c.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.disabled,
    required this.pressed,
    required this.onDown,
    required this.onUp,
  });

  static const double size = 68;

  final IconData icon;
  final String label;
  final Color accent;
  final bool disabled, pressed;
  final VoidCallback onDown, onUp;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    final Color background;
    final Color border;
    final Color foreground;
    if (disabled) {
      background = c.surface3;
      border = c.line;
      foreground = c.muted;
    } else if (pressed) {
      background = accent;
      border = accent;
      foreground = const Color(0xFF0B1220);
    } else {
      background = c.surface2;
      border = c.lineStrong;
      foreground = accent;
    }
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => onDown(),
        onTapUp: disabled ? null : (_) => onUp(),
        onTapCancel: disabled ? null : onUp, // pointer dragged away: stop
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: pressed ? 2 : 1),
          ),
          child: Icon(icon, size: 38, color: foreground),
        ),
      ),
    );
  }
}