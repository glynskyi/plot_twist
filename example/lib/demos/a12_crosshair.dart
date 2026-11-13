import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

/// A12 — What the user points at is shared state. The crosshair, the badges on
/// both axes, the tooltip and the table beside the chart all follow one
/// `ChartController.focus` value, which lives in data space.
class CrosshairDemo extends StatefulWidget {
  const CrosshairDemo({super.key});

  @override
  State<CrosshairDemo> createState() => _CrosshairDemoState();
}

class _CrosshairDemoState extends State<CrosshairDemo> {
  static const double rowHeight = 28;
  final ChartController chart = ChartController();
  final ScrollController table = ScrollController();
  final ChartData indoor = wave(80, seed: 1, amplitude: 3, period: 30, base: 21);
  final ChartData outdoor = wave(80, seed: 2, amplitude: 8, period: 40, base: 12);

  @override
  void initState() {
    super.initState();
    // Keep the pointed-at row in view.
    chart.focus.addListener(() {
      final ChartFocus? focus = chart.focus.value;
      if (focus == null || !table.hasClients) return;
      table.jumpTo((focus.x * rowHeight - 120).clamp(0, table.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    chart.dispose();
    table.dispose();
    indoor.dispose();
    outdoor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Chart(
            controller: chart,
            y: const .linear(range: .fit(padding: 0.1)),
            left: <Widget>[
              ChartAxis(
                extent: const .fixed(48),
                markers: <Widget>[
                  ChartCrosshairBadge(
                    builder: (BuildContext context, double v) => Pill('${v.toStringAsFixed(1)}°'),
                  ),
                ],
              ),
            ],
            bottom: <Widget>[
              ChartAxis(
                markers: <Widget>[
                  ChartCrosshairBadge(
                    builder: (BuildContext context, double v) => Pill('hour ${v.round()}'),
                  ),
                ],
              ),
            ],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: indoor, label: 'Indoor'),
              LineSeries(data: outdoor, label: 'Outdoor', color: const Color(0xFFF28E2B)),
              const ChartPanZoom(),
              const ChartCrosshair(horizontal: true),
              const ChartTooltip(),
            ],
          ),
        ),
        // An ordinary widget outside the chart, driven by the same state.
        SizedBox(
          width: 170,
          child: ValueListenableBuilder<ChartFocus?>(
            valueListenable: chart.focus,
            builder: (BuildContext context, ChartFocus? focus, Widget? child) => ListView.builder(
              controller: table,
              itemCount: indoor.length,
              itemExtent: rowHeight,
              itemBuilder: (BuildContext context, int i) => ColoredBox(
                color: focus?.x == indoor.x(i) ? scheme.primaryContainer : Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Text(
                    'h$i   ${indoor.y(i).toStringAsFixed(1)}°   ${outdoor.y(i).toStringAsFixed(1)}°',
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
