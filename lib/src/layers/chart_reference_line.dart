import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// A line across the plot at one value of a scale: a threshold, a target, an
/// average, "now".
///
/// ```dart
/// ChartReferenceLine.y(30, dash: [6, 4], label: Text('limit'))
/// ```
///
/// It is an ordinary layer: put it in `Chart.children`, after the series to
/// draw it on top of them. It is not a series, so no legend lists it. With
/// [includeInRange], automatic ranges make room for it.
class ChartReferenceLine extends StatelessWidget {
  /// A horizontal line at [value] on a vertical scale.
  const ChartReferenceLine.y(
    this.value, {
    super.key,
    this.scale = kChartY,
    this.color,
    this.width = 1,
    this.dash,
    this.label,
    this.labelAlignment = Alignment.topRight,
    this.labelPadding = const EdgeInsets.all(4),
    this.includeInRange = false,
  }) : direction = Axis.horizontal;

  /// A vertical line at [value] on a horizontal scale.
  const ChartReferenceLine.x(
    this.value, {
    super.key,
    this.scale = kChartX,
    this.color,
    this.width = 1,
    this.dash,
    this.label,
    this.labelAlignment = Alignment.topRight,
    this.labelPadding = const EdgeInsets.all(4),
    this.includeInRange = false,
  }) : direction = Axis.vertical;

  /// The value the line is drawn at.
  final double value;

  /// The direction the line runs in.
  final Axis direction;

  /// Id of the scale [value] is on.
  final Object scale;

  /// Line colour. Defaults to the crosshair colour of the chart theme.
  final Color? color;

  /// Line width in logical pixels.
  final double width;

  /// Dash pattern: lengths of alternating dashes and gaps. Null draws a solid
  /// line.
  final List<double>? dash;

  /// A widget shown at the line, usually a short `Text`. It gets the label
  /// style of the chart theme, follows the line without being rebuilt, moves
  /// to the other side of the line where it would leave the plot, and is
  /// hidden while the line is outside the plot.
  final Widget? label;

  /// Where the label sits. Along the line it is an alignment within the
  /// plot; across the line it is a side.
  ///
  /// For a horizontal line, `Alignment.topRight` (the default) puts the label
  /// above the right end and `Alignment.bottomLeft` below the left end. For a
  /// vertical line, `Alignment.topRight` puts it at the top, to the right of
  /// the line. A `0` across the line centres the label on it.
  final Alignment labelAlignment;

  /// Space around the label, which keeps it off the line and the plot edge.
  final EdgeInsets labelPadding;

  /// Whether automatic ranges are widened to show the line.
  final bool includeInRange;

  @override
  Widget build(BuildContext context) {
    final ChartThemeData theme = ChartTheme.of(context);
    final bool horizontal = direction == Axis.horizontal;
    final Widget line = ChartPaint(
      listed: false,
      painter: _ReferenceLinePainter(
        value: value,
        direction: direction,
        scale: scale,
        color: color ?? theme.crosshairColor,
        width: width,
        dash: dash,
        includeInRange: includeInRange,
      ),
    );
    final Widget? content = label;
    if (content == null) return line;
    final Alignment at = labelAlignment;
    final Widget child = Padding(
      padding: labelPadding,
      child: DefaultTextStyle(style: theme.labelStyle, child: content),
    );
    return ChartStack(
      children: <Widget>[
        line,
        // The anchor is on the line; the alignment says which point of the
        // label sits there, which is the corner facing the line.
        if (horizontal)
          ChartPositioned(
            x: ChartAnchor.fraction((at.x + 1) / 2),
            y: ChartAnchor.value(value),
            yScale: scale,
            alignment: Alignment(at.x, -at.y),
            fit: ChartPositionedFit.flip,
            child: child,
          )
        else
          ChartPositioned(
            x: ChartAnchor.value(value),
            y: ChartAnchor.fraction((at.y + 1) / 2),
            xScale: scale,
            alignment: Alignment(-at.x, at.y),
            fit: ChartPositionedFit.flip,
            child: child,
          ),
      ],
    );
  }
}

// A series painter, so the line can take part in automatic ranges. Its layer
// is not listed, so it is no series to a legend.
class _ReferenceLinePainter extends ChartSeriesPainter {
  const _ReferenceLinePainter({
    required this.value,
    required this.direction,
    required Object scale,
    required this.color,
    required this.width,
    required this.dash,
    required this.includeInRange,
  }) : super(
         xScale: direction == Axis.vertical ? scale : kChartX,
         yScale: direction == Axis.horizontal ? scale : kChartY,
       );

  final double value;
  final Axis direction;
  final Color color;
  final double width;
  final List<double>? dash;
  final bool includeInRange;

  bool get _horizontal => direction == Axis.horizontal;

  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    if (!includeInRange || !value.isFinite) return null;
    // A window on this dimension is what the scale can show at all.
    final ChartRange? window = _horizontal ? yWindow : xWindow;
    if (window != null && !window.contains(value)) return null;
    final ChartRange range = ChartRange(value, value);
    return _horizontal ? ChartDataBounds(y: range) : ChartDataBounds(x: range);
  }

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    final ChartScaleView? along = view.scales[_horizontal ? yScale : xScale];
    if (along == null) return;
    final double pixel = along.toPixel(value);
    if (!pixel.isFinite || pixel < -width || pixel > along.extent + width) return;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width;
    final List<double> pattern = dash ?? const <double>[];
    // Dashes are anchored to the other scale, so they move with the data.
    final ChartScaleView? across = view.scales[_horizontal ? kChartX : kChartY];
    final double phase = pattern.isEmpty || across == null ? 0 : -across.scaledToPixel(0);
    ChartPainter.drawDashedLine(
      context.canvas,
      _horizontal ? Offset(0, pixel) : Offset(pixel, 0),
      _horizontal ? Offset(view.size.width, pixel) : Offset(pixel, view.size.height),
      paint,
      pattern,
      phase: phase,
    );
  }

  @override
  bool shouldRepaint(_ReferenceLinePainter oldDelegate) =>
      shouldRescale(oldDelegate) ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      !listEquals(oldDelegate.dash, dash);

  @override
  bool shouldRescale(_ReferenceLinePainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.direction != direction ||
      oldDelegate.includeInRange != includeInRange;
}
