import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A11 — Different series types in one plot, on two Y scales: rain as bars on
/// the right axis, temperature as a line on the left, with a floating bar per
/// day for its min–max range. There is no "combo chart" class — a chart is
/// just a list of layers and named scales.
class WeatherComboDemo extends StatefulWidget {
  const WeatherComboDemo({super.key});

  @override
  State<WeatherComboDemo> createState() => _WeatherComboDemoState();
}

class _WeatherComboDemoState extends State<WeatherComboDemo> {
  static final math.Random _random = math.Random(11);
  final ChartData rain = ChartData.fromValues(<double>[
    for (int i = 0; i < 14; i++) i % 4 == 1 ? 0 : _random.nextDouble() * 9,
  ]);
  final ChartData mean = ChartData.fromValues(<double>[
    for (int i = 0; i < 14; i++) 15 + 5 * math.sin(i / 2.2),
  ]);
  // Two value columns: daily maximum and minimum.
  late final ChartData range = ChartData(valueColumns: 2)
    ..addRows(
      <double>[for (int i = 0; i < 14; i++) i.toDouble()],
      <List<double>>[
        <double>[for (int i = 0; i < 14; i++) mean.y(i) + 3 + _random.nextDouble() * 3],
        <double>[for (int i = 0; i < 14; i++) mean.y(i) - 3 - _random.nextDouble() * 3],
      ],
    );

  @override
  void dispose() {
    rain.dispose();
    mean.dispose();
    range.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const Color wet = Color(0xFF4E79A7);
    const Color warm = Color(0xFFE15759);
    return Chart(
      x: ChartScale.band(labels: <String>[for (int i = 0; i < 14; i++) weekdays[i % 7]]),
      y: const .linear(range: .fit(padding: 0.15)),
      scales: const <Object, ChartScale>{
        'rain': LinearScale(range: FitDataRange(includeZero: true, padding: 0.6)),
      },
      left: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.label}°')],
      right: <Widget>[ChartAxis(scale: 'rain', format: (ChartTick tick) => '${tick.label} mm')],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(vertical: false),
        BarSeries(
          data: rain,
          yScale: 'rain',
          label: 'Rain',
          color: wet.withValues(alpha: 0.55),
          radius: 3,
        ),
        BarSeries(
          data: range,
          baseColumn: 1,
          width: 0.18,
          radius: 4,
          label: 'Min–max',
          color: warm.withValues(alpha: 0.3),
        ),
        LineSeries(data: mean, label: 'Mean', color: warm, curve: .smooth, pointRadius: 3),
        const ChartCrosshair(),
        const ChartTooltip(),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('14-day outlook', style: TextStyle(color: scheme.outline)),
          ),
        ),
      ],
    );
  }
}
