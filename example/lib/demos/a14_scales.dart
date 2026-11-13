import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A project-specific scale: weekends take no room on the axis. A scale is a
/// monotonic transform and its inverse; panning, zooming, ticks and every
/// layer work with it unchanged.
class TradingDaysScale extends ChartScale {
  const TradingDaysScale({super.range, super.limits, super.ticks});

  static const double _week = 7 * dayMs;
  static const double _monday = 4 * dayMs; // 5 January 1970 was a Monday.

  @override
  double transform(double value) {
    final double sinceMonday = value - _monday;
    final double weeks = (sinceMonday / _week).floorToDouble();
    return weeks * 5 * dayMs + (sinceMonday - weeks * _week).clamp(0, 5 * dayMs);
  }

  @override
  double invert(double scaled) {
    final double weeks = (scaled / (5 * dayMs)).floorToDouble();
    return _monday + weeks * _week + (scaled - weeks * 5 * dayMs);
  }

  @override
  ChartTicks get defaultTicks => const TimeTicks(utc: true);
}

/// A14 — Scales are pluggable: time ticks change unit as you zoom, the Y scale
/// switches between linear and logarithmic in place, and the X scale can be
/// swapped for the custom one above.
class ScalesDemo extends StatefulWidget {
  const ScalesDemo({super.key});

  @override
  State<ScalesDemo> createState() => _ScalesDemoState();
}

class _ScalesDemoState extends State<ScalesDemo> {
  // Hourly prices on weekdays for two years, growing exponentially.
  late final ChartData price = _prices();
  bool log = false;
  bool tradingDays = false;

  static ChartData _prices() {
    final math.Random random = math.Random(9);
    final ChartData data = ChartData(capacity: 13000);
    double value = 40;
    for (int hour = 0; hour < 2 * 365 * 24; hour++) {
      final double time = year2026 - 2 * 365 * dayMs + hour * hourMs;
      if (DateTime.fromMillisecondsSinceEpoch(time.round(), isUtc: true).weekday > 5) continue;
      value *= 1 + (random.nextDouble() - 0.485) * 0.012;
      data.add(time, value);
    }
    return data;
  }

  @override
  void dispose() {
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Wrap(
          spacing: 8,
          children: <Widget>[
            FilterChip(
              label: const Text('Logarithmic Y'),
              selected: log,
              onSelected: (bool v) => setState(() => log = v),
            ),
            FilterChip(
              label: const Text('Skip weekends (custom scale)'),
              selected: tradingDays,
              onSelected: (bool v) => setState(() => tradingDays = v),
            ),
          ],
        ),
        Expanded(
          child: Chart(
            // Swapping a scale keeps the same data in view.
            x: tradingDays ? const TradingDaysScale() : const TimeScale(utc: true),
            y: log ? const LogScale(range: .fitVisible()) : const LinearScale(range: .fitVisible()),
            left: const <Widget>[ChartAxis(extent: .fixed(52))],
            bottom: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: price, width: 1.5),
              const ChartPanZoom(),
            ],
          ),
        ),
      ],
    );
  }
}
