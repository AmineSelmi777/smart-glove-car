/// LiPo voltage to percent (rough discharge curve, same as the web dashboard).
double lipoPercent(double volts, {int cells = 2}) {
  final v = volts / cells;
  const pts = [
    [3.3, 0.0],
    [3.5, 5.0],
    [3.65, 20.0],
    [3.75, 40.0],
    [3.85, 60.0],
    [4.0, 80.0],
    [4.2, 100.0],
  ];
  if (v <= pts[0][0]) return 0;
  for (var i = 1; i < pts.length; i++) {
    if (v <= pts[i][0]) {
      final a = pts[i - 1];
      final b = pts[i];
      return a[1] + (v - a[0]) / (b[0] - a[0]) * (b[1] - a[1]);
    }
  }
  return 100;
}