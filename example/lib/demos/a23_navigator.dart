import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';

/// A23 — A range navigator without a navigator class. It is a second, small
/// chart of the same data; the window is a widget stretched between two data
/// values and bound to the main chart's controller. Drag the window to pan,
/// drag its edges to zoom — or pan the main chart and watch it follow.
class NavigatorDemo extends StatefulWidget {
  const NavigatorDemo({super.key});

  @override
  State<NavigatorDemo> createState() => _NavigatorDemoState();
}

class _NavigatorDemoState extends State<NavigatorDemo> {
  final ChartController main = ChartController();
  final ChartController mini = ChartController();
  final ChartData data = randomWalk(2000, volatility: 3);

  @override
  void dispose() {
    main.dispose();
    mini.dispose();
    data.dispose();
    super.dispose();
  }

  // A drag of [pixels] on the mini chart, in main-chart data units.
  double _units(double pixels) => -(mini.pixelsToScaledDelta(kChartX, pixels) ?? 0);

  Widget _edge(void Function(double units) onDrag) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragUpdate: (DragUpdateDetails d) => onDrag(_units(d.delta.dx)),
    child: const MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: SizedBox(width: 12, height: double.infinity),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Expanded(
          child: Chart(
            controller: main,
            x: const .linear(range: .fixed(600, 900), limits: ChartLimits.data()),
            y: const .linear(range: .fitVisible()),
            left: const <Widget>[ChartAxis(extent: .fixed(48))],
            bottom: const <Widget>[ChartAxis()],
            children: <Widget>[
              const ChartGrid(),
              LineSeries(data: data),
              const ChartPanZoom(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Chart(
              controller: mini,
              children: <Widget>[
                LineSeries(data: data, width: 1, color: scheme.outline),
                // Rebuilt when the main window changes; placed by the mini chart.
                ListenableBuilder(
                  listenable: main.x,
                  builder: (BuildContext context, Widget? child) => ChartPositioned.span(
                    x1: .value(main.x.min),
                    x2: .value(main.x.max),
                    child: GestureDetector(
                      onHorizontalDragUpdate: (DragUpdateDetails d) =>
                          main.x.panBy(_units(d.delta.dx)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.18),
                          border: Border.symmetric(
                            vertical: BorderSide(color: scheme.primary, width: 2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            _edge((double u) => main.x.jumpTo(main.x.min + u, main.x.max)),
                            _edge((double u) => main.x.jumpTo(main.x.min, main.x.max + u)),
                          ],
                        ),
                      ),
                    ),
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
