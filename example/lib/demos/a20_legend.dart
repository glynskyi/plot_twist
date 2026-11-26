import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A20 — A legend. `ChartLegend` lists the series of a chart; here it sits
/// outside the chart, so it is given the controller. Tap an item to hide a
/// series, long-press to show only that one; the scales re-fit to what is
/// left. The series take their colours from the palette of the theme.
class LegendDemo extends StatefulWidget {
  const LegendDemo({super.key});

  @override
  State<LegendDemo> createState() => _LegendDemoState();
}

class _LegendDemoState extends State<LegendDemo> {
  static const List<String> regions = <String>['North', 'South', 'East', 'West'];
  final ChartController chart = ChartController();
  final List<ChartData> lines = <ChartData>[
    for (int i = 0; i < regions.length; i++)
      randomWalk(120, seed: i + 20, start: 30.0 + 25 * i, volatility: 2.5),
  ];
  final Set<Object> hidden = <Object>{};

  @override
  void dispose() {
    chart.dispose();
    for (final ChartData data in lines) {
      data.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // It reports taps; which series is visible stays in this state.
        ChartLegend(
          controller: chart,
          textStyle: Theme.of(context).textTheme.bodyMedium,
          swatchSize: 12,
          spacing: 20,
          onSeriesTap: (ChartSeries series) => setState(
            () => hidden.contains(series.id) ? hidden.remove(series.id) : hidden.add(series.id!),
          ),
          onSeriesLongPress: (ChartSeries series) => setState(() {
            hidden
              ..clear()
              ..addAll(regions.where((String region) => region != series.id));
          }),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Chart(
            controller: chart,
            y: const .linear(range: .fit(padding: 0.1)),
            left: const <Widget>[ChartAxis()],
            bottom: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              for (int i = 0; i < regions.length; i++)
                LineSeries(
                  id: regions[i],
                  label: regions[i],
                  data: lines[i],
                  // Hidden series stay listed, but are not drawn or measured.
                  visible: !hidden.contains(regions[i]),
                ),
              const ChartCrosshair(),
              const ChartTooltip(),
            ],
          ),
        ),
      ],
    );
  }
}
