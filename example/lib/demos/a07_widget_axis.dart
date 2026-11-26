import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A7 — Axis tick labels are widgets: an icon over two lines of text below,
/// chips on the left. The axis measures them, so the gutter grows by itself
/// when the labels get wider. Labels slide while panning; they are rebuilt
/// only when a tick enters or leaves.
class WidgetAxisDemo extends StatefulWidget {
  const WidgetAxisDemo({super.key});

  @override
  State<WidgetAxisDemo> createState() => _WidgetAxisDemoState();
}

class _WidgetAxisDemoState extends State<WidgetAxisDemo> {
  final ChartData sales = ChartData.fromValues(<double>[
    for (int i = 0; i < 42; i++) 12 + 8 * math.sin(i / 3) + (i % 7 >= 5 ? 9 : 0),
  ]);
  bool thousands = false;

  @override
  void dispose() {
    sales.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        SwitchListTile(
          dense: true,
          title: const Text('Long labels — the gutter makes room'),
          value: thousands,
          onChanged: (bool v) => setState(() => thousands = v),
        ),
        Expanded(
          child: Chart(
            x: const .band(range: .fixed(-0.5, 13.5)),
            y: const .linear(range: FitDataRange(includeZero: true, padding: 0.1)),
            left: <Widget>[
              ChartAxis(
                labelBuilder: (BuildContext context, ChartTick tick) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text(
                      thousands ? '€ ${tick.value.round()},000.00' : '€ ${tick.value.round()}k',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ),
              ),
            ],
            bottom: <Widget>[
              ChartAxis(
                labelBuilder: (BuildContext context, ChartTick tick) {
                  final int day = tick.value.round();
                  final bool weekend = day % 7 >= 5;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        weekend ? Icons.weekend_outlined : Icons.storefront_outlined,
                        size: 14,
                        color: weekend ? scheme.tertiary : scheme.outline,
                      ),
                      Text(weekdays[day % 7]),
                      Text('${day + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ],
            children: <Widget>[
              const ChartGrid(vertical: false),
              BarSeries(data: sales, cornerRadius: 3),
              const ChartPanZoom(),
            ],
          ),
        ),
      ],
    );
  }
}
