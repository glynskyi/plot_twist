import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

/// A22 — Styling that depends on the data. The temperature line is red above
/// 30° and blue below 0° wherever those values are on screen, the forecast is
/// dashed, and the chart takes its colours from the surrounding theme.
class StylingDemo extends StatefulWidget {
  const StylingDemo({super.key});

  @override
  State<StylingDemo> createState() => _StylingDemoState();
}

class _StylingDemoState extends State<StylingDemo> {
  final ChartData measured = wave(240, amplitude: 24, period: 110, base: 14);
  late final ChartData forecast = ChartData.generate(
    60,
    (int i) => (239.0 + i, measured.y(239) + (measured.y(239 - i) - measured.y(239)) * 0.8),
  );
  bool dark = false;

  @override
  void dispose() {
    measured.dispose();
    forecast.dispose();
    super.dispose();
  }

  // A vertical gradient whose stops are data values, not pixels.
  static ui.Shader _byTemperature(ChartView view) {
    const Color hot = Color(0xFFE15759);
    const Color mild = Color(0xFF8C8C8C);
    const Color cold = Color(0xFF4E79A7);
    final double top = view.y.toPixel(40);
    final double bottom = view.y.toPixel(-20);
    double stop(double value) => ((view.y.toPixel(value) - top) / (bottom - top)).clamp(0, 1);
    return ui.Gradient.linear(
      Offset(0, top),
      Offset(0, bottom),
      const <Color>[hot, hot, mild, mild, cold, cold],
      <double>[0, stop(30), stop(30), stop(0), stop(0), 1],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: base.colorScheme.primary,
    );
    return Column(
      children: <Widget>[
        SwitchListTile(
          dense: true,
          title: const Text('Dark theme'),
          value: dark,
          onChanged: (bool v) => setState(() => dark = v),
        ),
        Expanded(
          // The chart follows whatever theme it is under.
          child: Theme(
            data: theme,
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MaterialChartTheme(
                  child: Chart(
                    y: const .linear(range: .fixed(-12, 42)),
                    left: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.label}°')],
                    bottom: const <Widget>[ChartAxis()],
                    children: <Widget>[
                      const ChartGrid(),
                      LineSeries(data: measured, width: 2.5, shader: _byTemperature),
                      LineSeries(
                        data: forecast,
                        width: 2,
                        dash: const <double>[6, 5],
                        shader: _byTemperature,
                      ),
                      const ChartPanZoom(panY: true, zoomY: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
