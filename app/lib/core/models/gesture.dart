enum Gesture {
  openHand,
  closedHand,
  turnLeft,
  turnRight,
  unknown;

  /// Wire values are the same strings as in the Python side and CONTRATS.md.
  static Gesture fromWire(String s) => switch (s) {
        'open_hand' => Gesture.openHand,
        'closed_hand' => Gesture.closedHand,
        'turn_left' => Gesture.turnLeft,
        'turn_right' => Gesture.turnRight,
        _ => Gesture.unknown,
      };
}

enum CarCommand {
  forward,
  stop,
  turnLeft,
  turnRight;

  static CarCommand fromWire(String s) => switch (s) {
        'FORWARD' => CarCommand.forward,
        'TURN_LEFT' => CarCommand.turnLeft,
        'TURN_RIGHT' => CarCommand.turnRight,
        _ => CarCommand.stop, // unknown means stop: safe default
      };
}