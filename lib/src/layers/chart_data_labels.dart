import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Where a [ChartDataLabels] layer puts the label of a data point.
enum ChartDataLabelPosition {
  /// Beyond the end of the mark: above a point, a candle or a bar that
  /// points up, below a bar that points down, beside the end of a bar that
  /// lies. Where the plot leaves no room there, the label moves inside the
  /// end of the bar, or below the point.
  outside,

  /// Inside a bar, at its end. A bar too small for its label has none. On a
  /// point this is the same as [center].
  inside,

  /// In the middle of a bar, which suits the layers of a stack, or centred
  /// on a point. A bar too small for its label has none.
  center,
}

/// Writes the value of every visible data point next to it.
///
/// ```dart
/// Chart(children: [BarSeries(data: sales), const ChartDataLabels()])
/// ```
///
/// It is an ordinary layer: put it after the series it labels. It asks each
/// series for the data points it shows, so it works with bars in both
/// directions, lines, scatter plots, candlesticks and any series that
/// implements `ChartSeriesPainter.visitMarks`.
///
/// The labels are painted, not built as widgets, and their text is laid out
/// once and kept, so they follow a pan or an animation cheaply. Labels are
/// for a number of points that can be read: with more than [maxLabels] in
/// view, none is drawn.
class ChartDataLabels extends StatefulWidget {
  /// Creates a layer of data labels.
  const ChartDataLabels({
    super.key,
    this.series,
    this.format,
    this.position = ChartDataLabelPosition.outside,
    this.style,
    this.padding = 4,
    this.hideOverlapping = true,
    this.maxLabels = 250,
  });

  /// The `id` of the only series to label. Null labels every series the
  /// controller lists.
  final Object? series;

  /// Writes the text for a data point. Null or an empty text gives it no
  /// label. Defaults to the value, formatted as a tick is.
  ///
  /// For one layer of a stack, `mark.value - mark.base!` is its own size.
  final String? Function(ChartHit mark)? format;

  /// Where the labels sit.
  final ChartDataLabelPosition position;

  /// Text style merged into the label style of the chart theme. Without a
  /// colour of its own, a label inside a bar is white or dark, whichever
  /// reads better on the colour of its series.
  final TextStyle? style;

  /// Space between a label and the end of its mark, in logical pixels.
  final double padding;

  /// Whether a label that would cover one already drawn is left out.
  final bool hideOverlapping;

  /// The largest number of visible data points that still get labels. With
  /// more of them in view, the layer draws nothing.
  final int maxLabels;

  @override
  State<ChartDataLabels> createState() => _ChartDataLabelsState();
}

class _ChartDataLabelsState extends State<ChartDataLabels> {
  final _LabelCache _cache = _LabelCache();

  @override
  void dispose() {
    _cache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChartController controller = ChartScope.of(context).controller;
    final TextStyle style = ChartTheme.of(context).labelStyle.merge(widget.style);
    _cache.configure(
      style,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
      MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    );
    return ChartPaint(
      // A label may reach over the edge of the plot beside its point.
      clip: false,
      painter: _DataLabelsPainter(
        controller: controller,
        cache: _cache,
        series: widget.series,
        format: widget.format,
        position: widget.position,
        padding: widget.padding,
        hideOverlapping: widget.hideOverlapping,
        maxLabels: widget.maxLabels,
        style: style,
        contrast: widget.style?.color == null,
      ),
    );
  }
}

// Laid-out texts by their string and colour, so a label that stays in view
// is laid out once.
class _LabelCache {
  static const int _capacity = 2000;

  final Map<(String, int), TextPainter> _painters = <(String, int), TextPainter>{};
  TextStyle? _style;
  TextDirection _direction = TextDirection.ltr;
  TextScaler _scaler = TextScaler.noScaling;

  void configure(TextStyle style, TextDirection direction, TextScaler scaler) {
    if (style == _style && direction == _direction && scaler == _scaler) return;
    clear();
    _style = style;
    _direction = direction;
    _scaler = scaler;
  }

  TextPainter painterFor(String text, Color color) {
    final (String, int) key = (text, color.toARGB32());
    final TextPainter? known = _painters[key];
    if (known != null) return known;
    if (_painters.length >= _capacity) clear();
    return _painters[key] = TextPainter(
      text: TextSpan(
        text: text,
        style: _style?.copyWith(color: color),
      ),
      textDirection: _direction,
      textScaler: _scaler,
      maxLines: 1,
    )..layout();
  }

  void clear() {
    for (final TextPainter painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }
}

class _DataLabelsPainter extends ChartPainter {
  _DataLabelsPainter({
    required this.controller,
    required this.cache,
    required this.series,
    required this.format,
    required this.position,
    required this.padding,
    required this.hideOverlapping,
    required this.maxLabels,
    required this.style,
    required this.contrast,
  }) : super(repaint: controller.seriesRepaint);

  static const Color _light = Color(0xFFFFFFFF);
  static const Color _dark = Color(0xFF1F1F1F);

  final ChartController controller;
  final _LabelCache cache;
  final Object? series;
  final String? Function(ChartHit mark)? format;
  final ChartDataLabelPosition position;
  final double padding;
  final bool hideOverlapping;
  final int maxLabels;
  final TextStyle style;

  // Whether a label inside a bar picks its colour by the colour of the bar.
  final bool contrast;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    final List<ChartHit> marks = <ChartHit>[];
    for (final ChartSeries s in controller.series) {
      if (series != null && s.id != series) continue;
      bool tooMany = false;
      s.visitMarks(view, (ChartHit mark) {
        marks.add(mark);
        return !(tooMany = marks.length > maxLabels);
      });
      // More points than can be read: no labels rather than some of them.
      if (tooMany) return;
    }
    final Rect plot = Offset.zero & view.size;
    final Color outsideColor = style.color ?? _dark;
    final List<Rect> drawn = <Rect>[];
    for (final ChartHit mark in marks) {
      final String? text = format == null ? ChartTicks.formatNumber(mark.value) : format!(mark);
      if (text == null || text.isEmpty) continue;
      // Measured in the colour of a label outside a bar; one inside may need
      // the other colour, which is the same size.
      final Size size = cache.painterFor(text, outsideColor).size;
      final (Rect, bool)? placed = _place(mark, size, plot);
      if (placed == null) continue;
      final (Rect rect, bool inside) = placed;
      if (hideOverlapping && drawn.any(rect.overlaps)) continue;
      drawn.add(rect);
      final Color color = inside && contrast ? _colorOn(mark.series?.color) : outsideColor;
      cache.painterFor(text, color).paint(context.canvas, rect.topLeft);
    }
  }

  // White on a dark bar, dark on a light one.
  static Color _colorOn(Color? bar) =>
      bar == null || bar.computeLuminance() > 0.45 ? _dark : _light;

  // Where a label of [size] goes for [mark], and whether that is inside its
  // bar. Null when there is no place for it.
  (Rect, bool)? _place(ChartHit mark, Size size, Rect plot) {
    final Rect? bar = mark.rect;
    final bool lying = mark.valueAxis == Axis.horizontal;
    // The direction the value points in, from the base of the mark.
    final Offset tip = mark.position;
    final Offset towards = bar == null
        ? const Offset(0, -1)
        : lying
        ? Offset(tip.dx >= bar.center.dx ? 1 : -1, 0)
        : Offset(0, tip.dy <= bar.center.dy ? -1 : 1);
    // The end of the mark the value is at.
    final Offset end = bar == null
        ? tip
        : lying
        ? Offset(towards.dx > 0 ? bar.right : bar.left, bar.center.dy)
        : Offset(bar.center.dx, towards.dy < 0 ? bar.top : bar.bottom);
    // Half the label along the direction of the value, plus the gap.
    final double reach = (lying ? size.width : size.height) / 2 + padding;
    Rect at(Offset centre) =>
        Rect.fromCenter(center: centre, width: size.width, height: size.height);

    final Rect beyond = at(end + towards * reach);
    final Rect within = at(end - towards * reach);
    // A label inside a bar must fit in it, with the gap at both ends.
    final bool fits =
        bar != null &&
        (lying
            ? size.height <= bar.height && size.width + padding * 2 <= bar.width
            : size.width <= bar.width && size.height + padding * 2 <= bar.height);
    final bool centred = bar != null && size.width <= bar.width && size.height <= bar.height;

    final (Rect, bool)? result = switch (position) {
      ChartDataLabelPosition.outside =>
        _inPlot(beyond, plot, lying)
            ? (beyond, false)
            // No room beyond the end: inside the bar, or on the other side
            // of the point.
            : (bar == null ? (within, false) : (fits ? (within, true) : null)),
      ChartDataLabelPosition.inside =>
        bar == null ? (at(tip), false) : (fits ? (within, true) : null),
      ChartDataLabelPosition.center =>
        bar == null ? (at(tip), false) : (centred ? (at(bar.center), true) : null),
    };
    if (result == null || !_inPlot(result.$1, plot, lying)) return null;
    return result;
  }

  // Whether a label at [rect] is on the plot: all of it along the direction
  // of the values, and its middle along the other one.
  static bool _inPlot(Rect rect, Rect plot, bool lying) => lying
      ? rect.left >= plot.left &&
            rect.right <= plot.right &&
            rect.center.dy >= plot.top &&
            rect.center.dy <= plot.bottom
      : rect.top >= plot.top &&
            rect.bottom <= plot.bottom &&
            rect.center.dx >= plot.left &&
            rect.center.dx <= plot.right;

  @override
  bool shouldRepaint(_DataLabelsPainter oldDelegate) =>
      !identical(oldDelegate.controller, controller) ||
      oldDelegate.series != series ||
      oldDelegate.format != format ||
      oldDelegate.position != position ||
      oldDelegate.padding != padding ||
      oldDelegate.hideOverlapping != hideOverlapping ||
      oldDelegate.maxLabels != maxLabels ||
      oldDelegate.style != style ||
      oldDelegate.contrast != contrast;
}
