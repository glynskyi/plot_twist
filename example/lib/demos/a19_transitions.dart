import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

/// A19 — Animated transitions. Switch the period and the bars morph: matching
/// bars move, new ones grow in, extra ones shrink away, and the scales re-fit
/// as they go. Each frame only repaints the series — nothing is rebuilt. The
/// button lays the bars down; the value labels follow either way.
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
  bool horizontal = false;

  @override
  void dispose() {
    for (final ChartData data in periods.values) {
      data.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The rows of the data are bands; which way they run is up to the series.
    final ChartScale bands = ChartScale.band(reversed: horizontal);
    const ChartScale values = LinearScale(range: FitDataRange(includeZero: true, padding: 0.1));
    final Widget bandAxis = ChartAxis(format: (ChartTick tick) => '${tick.value.round() + 1}');
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                for (final String name in periods.keys)
                  ButtonSegment<String>(value: name, label: Text(name)),
              ],
              selected: <String>{period},
              onSelectionChanged: (Set<String> s) => setState(() => period = s.first),
            ),
            IconButton(
              tooltip: horizontal ? 'Columns' : 'Horizontal bars',
              icon: const Icon(Icons.rotate_90_degrees_cw),
              onPressed: () => setState(() => horizontal = !horizontal),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Chart(
            x: horizontal ? values : bands,
            y: horizontal ? bands : values,
            left: <Widget>[horizontal ? bandAxis : const ChartAxis(extent: .fixed(48))],
            bottom: <Widget>[horizontal ? const ChartAxis() : bandAxis],
            children: <Widget>[
              ChartGrid(vertical: horizontal, horizontal: !horizontal),
              // Give it the data you want to show; it animates the difference.
              AnimatedChartData(
                data: periods[period]!,
                builder: (BuildContext context, ChartData animated) => BarSeries(
                  data: animated,
                  direction: horizontal ? .horizontal : .vertical,
                  cornerRadius: 3,
                  step: 1,
                ),
              ),
              // One layer labels what the series show, whichever way they point.
              ChartDataLabels(format: (ChartHit mark) => '${mark.value.round()}'),
            ],
          ),
        ),
      ],
    );
  }
}
