int flexToSpeed(
  int flex, {
  int open = 3200,
  int closed = 3900,
  double lo = 0.10,
  double hi = 0.90,
  int vmax = 255,
}) {
  final span = closed - open;
  if (span == 0) return 0;
  final bend = ((flex - open) / span).clamp(0.0, 1.0);
  final openness = 1.0 - bend;
  final x = ((openness - lo) / (hi - lo)).clamp(0.0, 1.0);
  return (x * vmax).round();
}