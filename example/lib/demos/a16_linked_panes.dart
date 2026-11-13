import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A16 — Three separate charts that move as one. They share one X scale
/// controller (pan or zoom any pane), one focus (the crosshair appears in all)
/// and one gutter group (the plots line up although the labels differ).
class LinkedPanesDemo extends StatefulWidget {
  const LinkedPanesDemo({super.key});

  @override
  State<LinkedPanesDemo> createState() => _LinkedPanesDemoState();
}

class _LinkedPanesDemoState extends State<LinkedPanesDemo> {
  // The shared state: this is all that links the charts.
  final ChartScaleController time = ChartScaleController();
  final ValueNotifier<ChartFocus?> focus = ValueNotifier<ChartFocus?>(null);
  final ChartGutterGroup gutter = ChartGutterGroup();

  late final List<ChartController> charts = List<ChartController>.generate(
    3,
    (_) => ChartController(x: time, focus: focus),
  );
  final ChartData price = randomWalk(400, x0: year2026, dx: dayMs, start: 180, volatility: 4);
  late final ChartData volume = ChartData.generate(
    400,
    (int i) => (price.x(i), 2e6 + 1.5e6 * math.sin(i / 9).abs() + (i % 13) * 9e4),
  );
  late final ChartData strength = ChartData.generate(
    400,
    (int i) => (price.x(i), 50 + 35 * math.sin(i / 17) + 8 * math.sin(i / 3)),
  );

  @override
  void dispose() {
    for (final ChartController c in charts) {
      c.dispose();
    }
    time.dispose();
    focus.dispose();
    gutter.dispose();
    super.dispose();
  }

  static String _compact(ChartTick tick) =>
      tick.value >= 1e6 ? '${(tick.value / 1e6).toStringAsFixed(1)}M' : tick.label;

  Widget _pane(int index, int flex, ChartScale y, List<Widget> layers, {bool timeAxis = false}) {
    return Expanded(
      flex: flex,
      child: Chart(
        controller: charts[index],
        x: const .time(utc: true),
        y: y,
        right: <Widget>[ChartAxis(extent: .shared(gutter), format: _compact)],
        bottom: timeAxis ? const <Widget>[ChartAxis()] : const <Widget>[],
        children: <Widget>[
          const ChartGrid(),
          ...layers,
          const ChartPanZoom(),
          const ChartCrosshair(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color band = Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.12);
    return Column(
      children: <Widget>[
        _pane(0, 3, const .linear(range: .fitVisible(padding: 0.1)), <Widget>[
          LineSeries(data: price, label: 'Price'),
          const ChartTooltip(),
        ]),
        const Divider(height: 8),
        _pane(1, 1, const .linear(range: FitVisibleRange(includeZero: true)), <Widget>[
          BarSeries(data: volume, label: 'Volume', width: 0.8),
        ]),
        const Divider(height: 8),
        _pane(2, 1, const .linear(range: .fixed(0, 100)), <Widget>[
          // A plain widget stretched between two data values.
          ChartPositioned.span(
            y1: const .value(70),
            y2: const .value(30),
            child: ColoredBox(color: band),
          ),
          LineSeries(data: strength, label: 'Strength', color: const Color(0xFFB07AA1), width: 1.5),
        ], timeAxis: true),
      ],
    );
  }
}
