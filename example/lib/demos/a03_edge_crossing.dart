import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

/// A3 — A project-specific overlay nobody planned for: a dot where the line
/// crosses the Y axis, which stays on the axis while the chart is scrolled.
///
/// It mixes anchors (x from the plot edge, y from data), derives its position
/// from live chart state, and paints over the axis line.
class EdgeCrossingDemo extends StatefulWidget {
  const EdgeCrossingDemo({super.key});

  @override
  State<EdgeCrossingDemo> createState() => _EdgeCrossingDemoState();
}

class _EdgeCrossingDemoState extends State<EdgeCrossingDemo> {
  final ChartController chart = ChartController();
  final ChartData data = wave(600, amplitude: 12, period: 90);

  @override
  void dispose() {
    chart.dispose();
    data.dispose();
    super.dispose();
  }

  // The value of the drawn curve at the left edge of the plot.
  double? _crossing(ChartView view) => chart.seriesById('temp')?.valueAt(view.x.min);

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.tertiary;
    final double latest = data.y(data.length - 1);
    return Chart(
      controller: chart,
      x: const .linear(range: .fixed(100, 300)),
      y: const .linear(range: .fit(padding: 0.15)),
      left: <Widget>[
        ChartAxis(
          extent: const .fixed(52),
          markers: <Widget>[
            // The value pill, in the gutter, at the height of the crossing.
            ChartAxisMarker.resolve(
              resolver: _crossing,
              clamp: true,
              child: ChartLayoutBuilder<String>(
                selector: (ChartView view) => _crossing(view)?.toStringAsFixed(1) ?? '',
                builder: (BuildContext context, String text) => Pill(text, color: accent),
              ),
            ),
          ],
        ),
      ],
      right: <Widget>[
        ChartAxis(
          extent: const .fixed(52),
          showLabels: false,
          markers: <Widget>[
            ChartAxisMarker(value: latest, clamp: true, child: Pill(latest.toStringAsFixed(1))),
          ],
        ),
      ],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(),
        LineSeries(id: 'temp', data: data, curve: .smooth),
        const ChartPanZoom(panY: true, zoomY: true),
        // The dot: pinned to the plot's left edge, wherever the line is there.
        ChartPositioned.resolve(
          position: (ChartView view) {
            final double? y = _crossing(view);
            if (y == null) return null;
            return Offset(0, view.y.toPixel(y).clamp(0, view.size.height));
          },
          overflow: .visible,
          // Rebuilt only when the crossing leaves or re-enters the window.
          child: ChartLayoutBuilder<int>(
            selector: (ChartView view) {
              final double? y = _crossing(view);
              if (y == null) return 0;
              return y > view.y.max ? 1 : (y < view.y.min ? -1 : 0);
            },
            builder: (BuildContext context, int side) => side == 0
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                    ),
                  )
                : Icon(
                    side > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    color: accent,
                    size: 18,
                  ),
          ),
        ),
      ],
    );
  }
}
