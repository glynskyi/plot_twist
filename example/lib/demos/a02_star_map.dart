import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

/// A2 — Panning and zooming in both dimensions: drag diagonally, pinch or use
/// the wheel, drag an axis to stretch just that scale, double-tap to reset.
/// Hovering (or a long press) picks the star nearest to the pointer.
class StarMapDemo extends StatefulWidget {
  const StarMapDemo({super.key});

  @override
  State<StarMapDemo> createState() => _StarMapDemoState();
}

class _StarMapDemoState extends State<StarMapDemo> {
  late final ChartData stars = _stars();

  // 50,000 points in loose clusters. They are not sorted by x.
  static ChartData _stars() {
    final math.Random random = math.Random(4);
    final List<Offset> centres = List<Offset>.generate(
      30,
      (_) => Offset(random.nextDouble() * 360, random.nextDouble() * 180 - 90),
    );
    return ChartData.generate(50000, (int i) {
      final Offset c = centres[random.nextInt(centres.length)];
      final double r = 14 * math.sqrt(-2 * math.log(1 - random.nextDouble()));
      final double a = random.nextDouble() * 2 * math.pi;
      return (c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    });
  }

  @override
  void dispose() {
    stars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Chart(
      x: const .linear(range: .fixed(0, 360)),
      y: const .linear(range: .fixed(-90, 90)),
      // A tick's label has as many decimals as the zoom level needs.
      left: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.label}°')],
      bottom: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.label}°')],
      children: <Widget>[
        const ChartGrid(),
        ScatterSeries(data: stars, pointRadius: 1.1),
        // The whole feature: one behavior, configured for two dimensions.
        const ChartPanZoom(panY: true, zoomY: true),
        // The nearest point in both dimensions, not the nearest along x.
        const ChartCrosshair(mode: .nearest, snapDistance: 24, horizontal: true),
        ChartTooltip(
          builder: (BuildContext context, List<ChartHit> hits) => Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${hits.first.x.toStringAsFixed(1)}°, ${hits.first.y.toStringAsFixed(1)}°',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
