import 'dart:math' as math;

import 'package:plot_twist/plot_twist.dart';

/// Milliseconds in a day and an hour — time scales count in milliseconds.
const double dayMs = 86400e3;
const double hourMs = 3600e3;

/// Midnight UTC on 1 January 2026, as a time-scale value.
final double year2026 = DateTime.utc(2026).millisecondsSinceEpoch.toDouble();

/// The values of a random walk.
List<double> walk(int n, {int seed = 1, double start = 100, double volatility = 1}) {
  final math.Random random = math.Random(seed);
  double y = start;
  return List<double>.generate(n, (_) => y += (random.nextDouble() - 0.5) * 2 * volatility);
}

/// A random-walk series with [n] rows, [dx] apart, starting at [x0].
ChartData randomWalk(
  int n, {
  int seed = 1,
  double x0 = 0,
  double dx = 1,
  double start = 100,
  double volatility = 1,
}) {
  final List<double> ys = walk(n, seed: seed, start: start, volatility: volatility);
  return ChartData.generate(n, (int i) => (x0 + i * dx, ys[i]));
}

/// A smooth wave with a little noise: [n] rows, [dx] apart, one cycle every
/// [period] rows.
ChartData wave(
  int n, {
  int seed = 1,
  double amplitude = 10,
  double period = 40,
  double base = 20,
  double dx = 1,
}) {
  final math.Random random = math.Random(seed);
  return ChartData.generate(
    n,
    (int i) =>
        (i * dx, base + amplitude * math.sin(i / period * 2 * math.pi) + random.nextDouble() * 2),
  );
}

const List<String> weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

/// "12 Mar" for a time-scale value.
String shortDate(double value) {
  final DateTime t = DateTime.fromMillisecondsSinceEpoch(value.round(), isUtc: true);
  return '${t.day} ${months[t.month - 1]} ${t.year}';
}
