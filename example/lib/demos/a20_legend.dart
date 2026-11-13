import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A20 — The legend is an ordinary widget outside the chart, fed by the
/// chart's public list of series. Tap a chip to hide a series, long-press to
/// show only that one; the scales re-fit to what is left.
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
        // Rebuilt when series are added, removed or change.
        ListenableBuilder(
          listenable: chart.seriesListenable,
          builder: (BuildContext context, Widget? child) => Wrap(
            spacing: 8,
            children: <Widget>[
              for (final ChartSeries series in chart.series)
                GestureDetector(
                  onLongPress: () => setState(() {
                    hidden
                      ..clear()
                      ..addAll(
                        chart.series
                            .map((ChartSeries s) => s.id!)
                            .where((Object id) => id != series.id),
                      );
                  }),
                  child: FilterChip(
                    avatar: CircleAvatar(backgroundColor: series.color),
                    showCheckmark: false,
                    label: Text(series.label ?? ''),
                    selected: !hidden.contains(series.id),
                    onSelected: (bool show) =>
                        setState(() => show ? hidden.remove(series.id) : hidden.add(series.id!)),
                  ),
                ),
            ],
          ),
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
                  color: ChartThemeData.defaultPalette[i],
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
