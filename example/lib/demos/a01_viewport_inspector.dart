import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A1 — The visible range is a value in data space that app code can read,
/// set, animate and listen to.
class ViewportInspectorDemo extends StatefulWidget {
  const ViewportInspectorDemo({super.key});

  @override
  State<ViewportInspectorDemo> createState() => _ViewportInspectorDemoState();
}

class _ViewportInspectorDemoState extends State<ViewportInspectorDemo> {
  final ChartController chart = ChartController();
  final ChartData data = randomWalk(365, x0: year2026, dx: dayMs, volatility: 3);
  final double first = year2026;
  final double last = year2026 + 364 * dayMs;

  @override
  void dispose() {
    chart.dispose();
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // Rebuilt by the controller. The chart itself is not rebuilt.
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[chart.x, chart.y]),
          builder: (BuildContext context, Widget? child) {
            final ChartRange x = chart.x.range;
            return Column(
              children: <Widget>[
                Text(
                  'x: ${shortDate(x.min)} → ${shortDate(x.max)}      '
                  'y: ${chart.y.min.toStringAsFixed(1)} → ${chart.y.max.toStringAsFixed(1)}',
                ),
                // Two-way bound: dragging the slider moves the chart, and
                // panning the chart moves the slider.
                RangeSlider(
                  min: first,
                  max: last,
                  values: RangeValues(x.min.clamp(first, last), x.max.clamp(first, last)),
                  onChanged: (RangeValues v) {
                    if (v.end - v.start >= 7 * dayMs) chart.x.jumpTo(v.start, v.end);
                  },
                ),
              ],
            );
          },
        ),
        Wrap(
          spacing: 8,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: () => chart.x.animateTo(first + 181 * dayMs, first + 273 * dayMs),
              child: const Text('Zoom to Q3'),
            ),
            OutlinedButton(
              onPressed: () => chart.x.resetToAuto(duration: const Duration(milliseconds: 300)),
              child: const Text('Show all'),
            ),
          ],
        ),
        Expanded(
          child: Chart(
            controller: chart,
            x: const .time(utc: true),
            y: const .linear(range: .fitVisible()),
            left: const <Widget>[ChartAxis()],
            bottom: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: data),
              const ChartPanZoom(),
            ],
          ),
        ),
      ],
    );
  }
}
