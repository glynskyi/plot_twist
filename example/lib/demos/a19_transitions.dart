import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

/// A19 — Animated transitions. Switch the period and the bars morph: matching
/// bars move, new ones grow in, extra ones shrink away, and the scales re-fit
/// as they go. Each frame only repaints the series — nothing is rebuilt.
class TransitionsDemo extends StatefulWidget {
  const TransitionsDemo({super.key});

  @override
  State<TransitionsDemo> createState() => _TransitionsDemoState();
}

class _TransitionsDemoState extends State<TransitionsDemo> {
  static final math.Random _random = math.Random(8);
  static ChartData _series(int count, double scale) => ChartData.fromValues(<double>[
    for (int i = 0; i < count; i++) scale * (0.3 + _random.nextDouble()),
  ]);

  final Map<String, ChartData> periods = <String, ChartData>{
    'Week': _series(7, 40),
    'Month': _series(30, 60),
    'Year': _series(12, 900),
  };
  String period = 'Week';

  @override
  void dispose() {
    for (final ChartData data in periods.values) {
      data.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SegmentedButton<String>(
          segments: <ButtonSegment<String>>[
            for (final String name in periods.keys)
              ButtonSegment<String>(value: name, label: Text(name)),
          ],
          selected: <String>{period},
          onSelectionChanged: (Set<String> s) => setState(() => period = s.first),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Chart(
            x: const .band(),
            y: const .linear(range: FitDataRange(includeZero: true, padding: 0.1)),
            left: const <Widget>[ChartAxis(extent: .fixed(48))],
            bottom: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.value.round() + 1}')],
            children: <Widget>[
              const ChartGrid(vertical: false),
              // Give it the data you want to show; it animates the difference.
              AnimatedChartData(
                data: periods[period]!,
                builder: (BuildContext context, ChartData animated) =>
                    BarSeries(data: animated, cornerRadius: 3, step: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
