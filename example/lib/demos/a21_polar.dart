import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

/// A21 — A pie, a gauge and a radar chart are charts like the others. A
/// `PolarChart` lays the same two scales out on a circle, so the legend, the
/// tooltip, the data labels and the animations of the other demos work here
/// unchanged, and a widget still goes anywhere: the total sits in the hole of
/// the doughnut and the slider is docked below the gauge.
class PolarDemo extends StatefulWidget {
  const PolarDemo({super.key});

  @override
  State<PolarDemo> createState() => _PolarDemoState();
}

class _PolarDemoState extends State<PolarDemo> {
  static const List<String> names = <String>['Rent', 'Food', 'Travel', 'Savings', 'Fun'];
  static const List<String> traits = <String>['Speed', 'Range', 'Comfort', 'Price', 'Safety'];
  final ChartData spending = ChartData.fromValues(<double>[1200, 640, 310, 520, 230]);
  final ChartData modelA = ChartData.fromValues(<double>[8, 6, 7, 4, 9]);
  final ChartData modelB = ChartData.fromValues(<double>[5, 9, 6, 8, 6]);
  final ChartData load = ChartData.fromValues(<double>[72]);
  int? selected;

  @override
  void dispose() {
    for (final ChartData data in <ChartData>[spending, modelA, modelB, load]) {
      data.dispose();
    }
    super.dispose();
  }

  // One slice per row. Tapping a legend item pulls its slice out.
  Widget _doughnut(TextTheme text) => PolarChart(
    innerRadius: 0.62,
    margin: const EdgeInsets.all(10),
    bottom: <Widget>[
      ChartLegend(
        alignment: .center,
        onEntryTap: (ChartSeries series, ChartSeriesEntry entry) =>
            setState(() => selected = selected == entry.index ? null : entry.index),
      ),
    ],
    children: <Widget>[
      ChartAppear(
        effect: .reveal,
        child: PieSeries(
          data: spending,
          labels: names,
          gap: 3,
          cornerRadius: 5,
          offsetOf: (int index) => index == selected ? 8 : 0,
        ),
      ),
      ChartDataLabels(
        position: .center,
        format: (ChartHit mark) => '${(mark.value / 29).round()}%',
      ),
      Center(child: Text('€ 2,900', style: text.headlineSmall)),
      const ChartCrosshair.point(),
      const ChartTooltip(),
    ],
  );

  // One bar around three quarters of a circle. The slider changes the data
  // and the bar moves to it.
  Widget _gauge(TextTheme text) => PolarChart(
    angle: const LinearScale(range: FixedRange(0, 100), ticks: LinearTicks(spacing: 40)),
    startAngle: 0.75 * math.pi,
    sweepAngle: 1.5 * math.pi,
    innerRadius: 0.8,
    margin: const EdgeInsets.all(10),
    bottom: <Widget>[
      // A slider is as high as it is allowed to be, so it gets a height.
      SizedBox(
        height: 40,
        child: Slider(
          value: load.value(0),
          max: 100,
          onChanged: (double value) => setState(() => load.setValue(0, value)),
        ),
      ),
    ],
    children: <Widget>[
      AnimatedChartData(
        data: load,
        builder: (BuildContext context, ChartData animated) => RadialBarSeries(
          data: animated,
          track: true,
          cap: .round,
          colorOf: (int index, double x, double value) => value > 80 ? Colors.redAccent : null,
        ),
      ),
      const ChartPolarAxis.angle(inside: true),
      Center(child: Text('${load.value(0).round()}%', style: text.headlineMedium)),
    ],
  );

  // A band scale around the circle and a linear one from its centre.
  Widget _radar() => PolarChart(
    angle: const ChartScale.band(labels: traits),
    radius: const LinearScale(range: FixedRange(0, 10)),
    margin: const EdgeInsets.fromLTRB(40, 24, 40, 24),
    bottom: const <Widget>[ChartLegend(alignment: .center)],
    children: <Widget>[
      const ChartPolarGrid(shape: .polygon),
      const ChartPolarAxis.angle(),
      RadarSeries(data: modelA, label: 'Model A'),
      RadarSeries(data: modelB, label: 'Model B'),
      const ChartCrosshair.point(showPoints: true),
      const ChartTooltip(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => Flex(
        direction: box.maxWidth > box.maxHeight ? .horizontal : .vertical,
        children: <Widget>[
          for (final Widget chart in <Widget>[_doughnut(text), _gauge(text), _radar()])
            Expanded(
              child: Center(child: AspectRatio(aspectRatio: 0.85, child: chart)),
            ),
        ],
      ),
    );
  }
}
