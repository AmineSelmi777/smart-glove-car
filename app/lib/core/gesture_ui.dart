import 'package:flutter/material.dart';
import 'models/gesture.dart';

extension GestureUi on Gesture {
  String get label => switch (this) {
        Gesture.openHand => 'Open hand',
        Gesture.closedHand => 'Closed hand',
        Gesture.turnLeft => 'Turn left',
        Gesture.turnRight => 'Turn right',
        Gesture.unknown => 'Unknown',
      };

  IconData get icon => switch (this) {
        Gesture.openHand => Icons.front_hand,
        Gesture.closedHand => Icons.sports_mma,
        Gesture.turnLeft => Icons.turn_left,
        Gesture.turnRight => Icons.turn_right,
        Gesture.unknown => Icons.help_outline,
      };
}

extension CarCommandUi on CarCommand {
  String get label => switch (this) {
        CarCommand.forward => 'FORWARD',
        CarCommand.stop => 'STOP',
        CarCommand.turnLeft => 'TURN LEFT',
        CarCommand.turnRight => 'TURN RIGHT',
      };

  MaterialColor get color => switch (this) {
        CarCommand.forward => Colors.green,
        CarCommand.stop => Colors.red,
        CarCommand.turnLeft => Colors.orange,
        CarCommand.turnRight => Colors.orange,
      };
}