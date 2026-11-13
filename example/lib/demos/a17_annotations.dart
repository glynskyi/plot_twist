import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

typedef _Point = ({double x, double y});

/// A17 — Annotations the user can edit: drag the threshold pill up and down,
/// drag either end of the trend line. They are made of the same public pieces
/// as everything else — a painter for the lines, positioned widgets for the
/// handles — and the handles keep their drags to themselves.
class AnnotationsDemo extends StatefulWidget {
  const AnnotationsDemo({super.key});

  @override
  State<AnnotationsDemo> createState() => _AnnotationsDemoState();
}

class _AnnotationsDemoState extends State<AnnotationsDemo> {
  final ChartController chart = ChartController();
  final ChartData data = wave(300, amplitude: 9, period: 70, base: 20);
  double threshold = 26;
  final List<_Point> trend = <_Point>[(x: 40, y: 12), (x: 240, y: 30)];

  @override
  void dispose() {
    chart.dispose();
    data.dispose();
    super.dispose();
  }

  // Where a data point ends up after being dragged by [delta] pixels.
  _Point _moved(_Point point, Offset delta) {
    final ChartView view = chart.view!;
    return view.toValue(view.toPixel(point.x, point.y) + delta);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Chart(
      controller: chart,
      y: const .linear(range: .fixed(5, 35)),
      left: const <Widget>[ChartAxis()],
      bottom: const <Widget>[ChartAxis()],
      children: <Widget>[
        const ChartGrid(),
        LineSeries(data: data),
        const ChartPanZoom(),
        ChartPaint(painter: _AnnotationPainter(threshold, trend, scheme.error, scheme.tertiary)),
        ChartPositioned(
          x: .end,
          y: .value(threshold),
          alignment: .centerRight,
          child: ChartGestureShield(
            child: GestureDetector(
              onVerticalDragUpdate: (DragUpdateDetails d) =>
                  setState(() => threshold = _moved((x: 0, y: threshold), Offset(0, d.delta.dy)).y),
              child: Pill('↕ alert above ${threshold.toStringAsFixed(1)}', color: scheme.error),
            ),
          ),
        ),
        for (int i = 0; i < trend.length; i++)
          ChartPositioned(
            x: .value(trend[i].x),
            y: .value(trend[i].y),
            child: ChartGestureShield(
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails d) =>
                    setState(() => trend[i] = _moved(trend[i], d.delta)),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.tertiary, width: 3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnnotationPainter extends ChartPainter {
  const _AnnotationPainter(this.threshold, this.trend, this.alert, this.line);

  final double threshold;
  final List<_Point> trend;
  final Color alert;
  final Color line;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    final double y = view.y.toPixel(threshold);
    context.canvas
      ..drawRect(
        Rect.fromLTRB(0, 0, view.size.width, y),
        Paint()..color = alert.withValues(alpha: 0.08),
      )
      ..drawLine(
        Offset(0, y),
        Offset(view.size.width, y),
        Paint()
          ..color = alert
          ..strokeWidth = 1.5,
      )
      ..drawLine(
        view.toPixel(trend[0].x, trend[0].y),
        view.toPixel(trend[1].x, trend[1].y),
        Paint()
          ..color = line
          ..strokeWidth = 2,
      );
  }

  // The list is mutated in place, so always repaint when rebuilt.
  @override
  bool shouldRepaint(_AnnotationPainter oldDelegate) => true;
}
