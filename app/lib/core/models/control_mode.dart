enum ControlMode {
  gesture,
  manual;

  static ControlMode fromWire(String s) =>
      s == 'manual' ? ControlMode.manual : ControlMode.gesture;
}