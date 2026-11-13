import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A18 — Accessible by composition. The chart has a summary label, every
/// visible bar is a semantics node a screen reader can step through, and the
/// arrow keys move the same focus the crosshair and tooltip follow.
class AccessibilityDemo extends StatefulWidget {
  const AccessibilityDemo({super.key});

  @override
  State<AccessibilityDemo> createState() => _AccessibilityDemoState();
}

class _AccessibilityDemoState extends State<AccessibilityDemo> {
  final ChartController chart = ChartController();
  final ChartData revenue = ChartData.fromValues(<double>[
    2.1, 2.8, 4.2, 3.9, 3.1, 2.6, 2.9, 3.4, 3.8, 3.3, 2.7, 3.6, //
  ]);

  @override
  void dispose() {
    chart.dispose();
    revenue.dispose();
    super.dispose();
  }

  void _focus(int month) =>
      chart.focus.value = ChartFocus(x: month.clamp(0, 11).toDouble(), source: chart);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final int current = chart.focus.value?.x.round() ?? -1;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _focus(current + 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _focus(current < 0 ? 11 : current - 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Press ← and → to step through the months.'),
        const SizedBox(height: 8),
        Expanded(
          child: Focus(
            autofocus: true,
            onKeyEvent: _onKey,
            child: Chart(
              controller: chart,
              semanticLabel:
                  'Revenue by month. Bar chart, 12 values, highest 4.2 thousand in March.',
              x: const .band(labels: months),
              y: const .linear(range: FitDataRange(includeZero: true, padding: 0.15)),
              left: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.label}k')],
              bottom: const <Widget>[ChartAxis()],
              children: <Widget>[
                const ChartGrid(vertical: false),
                // The focused bar is highlighted: state in, colours out.
                ValueListenableBuilder<ChartFocus?>(
                  valueListenable: chart.focus,
                  builder: (BuildContext context, ChartFocus? focus, Widget? child) => BarSeries(
                    data: revenue,
                    label: 'Revenue',
                    radius: 4,
                    colorOf: (int i, double x, double y) => focus?.x == x ? scheme.tertiary : null,
                  ),
                ),
                const ChartCrosshair(vertical: false, showPoints: false),
                const ChartTooltip(),
                // One semantics node per visible bar, built lazily, sitting
                // exactly on its bar.
                ChartLayoutBuilder<(int, int)>(
                  selector: (ChartView view) =>
                      (view.x.min.ceil().clamp(0, 12), view.x.max.floor().clamp(-1, 11)),
                  builder: (BuildContext context, (int, int) visible) => ChartStack(
                    children: <Widget>[
                      for (int i = visible.$1; i <= visible.$2; i++)
                        ChartPositioned.span(
                          key: ValueKey<int>(i),
                          x1: .value(i - 0.35),
                          x2: .value(i + 0.35),
                          child: Semantics(
                            label: '${months[i]}: ${revenue.y(i)} thousand',
                            button: true,
                            onTap: () => _focus(i),
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
