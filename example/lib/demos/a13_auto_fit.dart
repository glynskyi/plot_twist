import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A13 — The Y scale fits whatever is visible as you pan and zoom in X. Take
/// over by dragging the Y axis and automatic fitting switches off; the chip
/// brings it back with an animation.
class AutoFitDemo extends StatefulWidget {
  const AutoFitDemo({super.key});

  @override
  State<AutoFitDemo> createState() => _AutoFitDemoState();
}

class _AutoFitDemoState extends State<AutoFitDemo> {
  final ChartController chart = ChartController();
  final ChartData price = randomWalk(
    3650,
    x0: year2026 - 3650 * dayMs,
    dx: dayMs,
    start: 400,
    volatility: 6,
  );

  @override
  void dispose() {
    chart.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // "Automatic or not" is state of the scale; anything can show it.
        ListenableBuilder(
          listenable: chart.y,
          builder: (BuildContext context, Widget? child) => FilterChip(
            label: Text(
              chart.y.isAuto ? 'Y fits the visible data' : 'Y is manual — tap to fit again',
            ),
            selected: chart.y.isAuto,
            onSelected: (_) => chart.y.resetToAuto(duration: const Duration(milliseconds: 350)),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Chart(
            controller: chart,
            x: ChartScale.time(
              utc: true,
              range: FixedRange(year2026 - 400 * dayMs, year2026),
              limits: const ChartLimits.data(),
            ),
            // The whole feature is this policy.
            y: const .linear(range: .fitVisible(padding: 0.1)),
            right: const <Widget>[ChartAxis(extent: .fixed(56))],
            bottom: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: price),
              const ChartPanZoom(),
            ],
          ),
        ),
      ],
    );
  }
}
