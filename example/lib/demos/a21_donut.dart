import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/ui.dart';

/// Where things are on a donut drawn in a plot of [size].
class Donut {
  Donut(this.values, Size size)
    : centre = size.center(Offset.zero),
      radius = size.shortestSide * 0.3;

  final List<double> values;
  final Offset centre;
  final double radius;

  double get total => values.reduce((double a, double b) => a + b);
  double start(int i) =>
      -math.pi / 2 + values.take(i).fold(0.0, (double a, double b) => a + b) / total * 2 * math.pi;
  double sweep(int i) => values[i] / total * 2 * math.pi;
  double middle(int i) => start(i) + sweep(i) / 2;

  /// A point on the ray through the middle of slice [i].
  Offset along(int i, double factor) =>
      centre + Offset(math.cos(middle(i)), math.sin(middle(i))) * radius * factor;

  int? sliceAt(Offset position) {
    final Offset d = position - centre;
    if (d.distance < radius * 0.6 || d.distance > radius * 1.3) return null;
    final double angle = (math.atan2(d.dy, d.dx) + math.pi / 2) % (2 * math.pi);
    return List<int>.generate(
      values.length,
      (int i) => i,
    ).lastWhere((int i) => start(i) + math.pi / 2 <= angle, orElse: () => 0);
  }
}

class _DonutPainter extends ChartPainter {
  const _DonutPainter(this.values, this.colors, this.selected);

  final List<double> values;
  final List<Color> colors;
  final int? selected;

  @override
  void paint(ChartPaintContext context) {
    final Donut donut = Donut(values, context.size);
    for (int i = 0; i < values.length; i++) {
      final double r = donut.radius * (i == selected ? 1.06 : 1);
      context.canvas.drawArc(
        Rect.fromCircle(center: donut.centre, radius: r),
        donut.start(i) + 0.02,
        donut.sweep(i) - 0.04,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = donut.radius * 0.42
          ..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.values != values;
}

/// A21 — Nothing in a chart is tied to Cartesian axes. A donut is a painter;
/// its centre is a plain widget; its callouts and its tooltip are widgets
/// positioned from the donut's own geometry; hovering uses the same pointer
/// hub as every other behavior.
class DonutDemo extends StatefulWidget {
  const DonutDemo({super.key});

  @override
  State<DonutDemo> createState() => _DonutDemoState();
}

class _DonutDemoState extends State<DonutDemo> {
  static const List<String> names = <String>['Rent', 'Food', 'Travel', 'Savings', 'Fun'];
  static const List<double> values = <double>[1200, 640, 310, 520, 230];
  final ChartController chart = ChartController();
  int? selected;

  @override
  void dispose() {
    chart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    const List<Color> colors = ChartThemeData.defaultPalette;
    return Chart(
      controller: chart,
      children: <Widget>[
        ChartPaint(painter: _DonutPainter(values, colors, selected), clip: false),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('€ 2,900', style: text.headlineSmall),
              const Text('this month'),
            ],
          ),
        ),
        for (int i = 0; i < values.length; i++)
          ChartPositioned.resolve(
            position: (ChartView view) => Donut(values, view.size).along(i, 1.45),
            overflow: .visible,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.circle, size: 10, color: colors[i]),
                Text(' ${names[i]}', style: text.labelMedium),
              ],
            ),
          ),
        if (selected case final int s)
          ChartPositioned.resolve(
            position: (ChartView view) => Donut(values, view.size).along(s, 1),
            fit: .clamp,
            child: IgnorePointer(
              child: Pill('${names[s]}: € ${values[s].round()} · ${(values[s] / 29).round()}%'),
            ),
          ),
        ChartGestureDetector(
          onPointerHover: (ChartPointerEvent e) => _select(e.plotPosition),
          onPointerDown: (ChartPointerEvent e) => _select(e.plotPosition),
          onPointerExit: () => setState(() => selected = null),
        ),
      ],
    );
  }

  void _select(Offset plotPosition) {
    final Size? size = chart.view?.size;
    if (size != null) setState(() => selected = Donut(values, size).sliceAt(plotPosition));
  }
}
