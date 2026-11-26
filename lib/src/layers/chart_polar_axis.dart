import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// The labels of one scale of a polar chart, painted in the plot.
///
/// [ChartPolarAxis.angle] writes around the circle, at the ticks of the angle
/// scale: the categories of a radar chart or the numbers of a gauge. Give
/// the chart a `margin` so they have room. [ChartPolarAxis.radius] writes
/// along a line from the centre, at the ticks of the radius scale.
///
/// ```dart
/// PolarChart(
///   margin: const EdgeInsets.all(28),
///   children: [const ChartPolarGrid(), const ChartPolarAxis.angle(), …],
/// )
/// ```
///
/// A label that would cover one already written is left out. For labels that
/// are widgets, use `ChartPolarPositioned`.
class ChartPolarAxis extends StatelessWidget {
  /// Labels around the circle, at the ticks of the angle scale.
  ///
  /// They stand outside the circle, [padding] away from it, or inside it
  /// with [inside]. A [tickLength] draws a short mark at each tick.
  const ChartPolarAxis.angle({
    super.key,
    this.format,
    this.style,
    this.padding = 6,
    this.tickLength = 0,
    this.inside = false,
    this.color,
  }) : _around = true,
       angle = null;

  /// Labels along a line from the centre, at the ticks of the radius scale.
  ///
  /// The line runs at [angle], in radians as `Canvas.drawArc` counts them;
  /// null is the start angle of the chart. The labels stand [padding] beside
  /// it, on its clockwise side.
  const ChartPolarAxis.radius({super.key, this.format, this.style, this.padding = 4, this.angle})
    : _around = false,
      tickLength = 0,
      inside = false,
      color = null;

  final bool _around;

  /// Writes the text of a tick. An empty text leaves the tick without a
  /// label. Defaults to the label the scale gives the tick.
  final String Function(ChartTick tick)? format;

  /// Text style merged into the label style of the chart theme.
  final TextStyle? style;

  /// Space between a label and the circle or the line, in logical pixels.
  final double padding;

  /// Length of the mark at each tick of the angle scale; zero draws none.
  final double tickLength;

  /// Whether the labels and marks of the angle scale are inside the circle.
  final bool inside;

  /// Colour of the tick marks. Defaults to the axis colour of the chart
  /// theme.
  final Color? color;

  /// The angle of the line the radius labels run along.
  final double? angle;

  @override
  Widget build(BuildContext context) {
    final ChartThemeData theme = ChartTheme.of(context);
    return ChartPaint(
      clip: false,
      painter: _PolarAxisPainter(
        polar: ChartPolarScope.of(context),
        around: _around,
        format: format,
        style: theme.labelStyle.merge(style),
        padding: padding,
        tickLength: tickLength,
        inside: inside,
        color: color ?? theme.axisColor,
        angle: angle,
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
      ),
    );
  }
}

class _PolarAxisPainter extends ChartPainter {
  const _PolarAxisPainter({
    required this.polar,
    required this.around,
    required this.format,
    required this.style,
    required this.padding,
    required this.tickLength,
    required this.inside,
    required this.color,
    required this.angle,
    required this.textDirection,
    required this.textScaler,
  });

  final ChartPolar polar;
  final bool around;
  final String Function(ChartTick tick)? format;
  final TextStyle style;
  final double padding;
  final double tickLength;
  final bool inside;
  final Color color;
  final double? angle;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  void paint(ChartPaintContext context) {
    final ChartPolarView circle = polar.resolve(context.view);
    if (!(circle.radius > 0)) return;
    final List<Rect> drawn = <Rect>[];
    // Writes [tick] in a box whose side facing against [away] touches
    // [anchor].
    void write(ChartTick tick, Offset anchor, Offset away) {
      final String text = format == null ? tick.label : format!(tick);
      if (text.isEmpty) return;
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final Rect rect = Rect.fromCenter(
        center: anchor + Offset(away.dx * painter.width / 2, away.dy * painter.height / 2),
        width: painter.width,
        height: painter.height,
      );
      if (!drawn.any(rect.overlaps)) {
        drawn.add(rect);
        painter.paint(context.canvas, rect.topLeft);
      }
      painter.dispose();
    }

    if (around) {
      final double side = inside ? -1 : 1;
      final Paint mark = Paint()
        ..color = color
        ..strokeWidth = 1;
      for (final ChartTick tick in circle.angleTicks) {
        final double a = circle.angleOf(tick.value);
        final Offset out = Offset(math.cos(a), math.sin(a));
        if (tickLength > 0) {
          context.canvas.drawLine(
            circle.pointAt(a, circle.radius),
            circle.pointAt(a, circle.radius + side * tickLength),
            mark,
          );
        }
        write(tick, circle.pointAt(a, circle.radius + side * (tickLength + padding)), out * side);
      }
    } else {
      final double a = angle ?? polar.startAngle;
      // Beside the line, on its clockwise side.
      final Offset beside = Offset(-math.sin(a), math.cos(a));
      for (final ChartTick tick in circle.radiusTicks) {
        final double r = circle.radiusOf(tick.value);
        if (r < -0.5 || r > circle.radius + 0.5) continue;
        write(tick, circle.pointAt(a, r) + beside * padding, beside);
      }
    }
  }

  @override
  bool shouldRepaint(_PolarAxisPainter oldDelegate) =>
      oldDelegate.polar != polar ||
      oldDelegate.around != around ||
      oldDelegate.format != format ||
      oldDelegate.style != style ||
      oldDelegate.padding != padding ||
      oldDelegate.tickLength != tickLength ||
      oldDelegate.inside != inside ||
      oldDelegate.color != color ||
      oldDelegate.angle != angle ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler;
}
