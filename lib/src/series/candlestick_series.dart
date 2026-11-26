import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// The four prices of one candle.
///
/// Every hit of a [CandlestickSeries] carries one as its `datum`, so a tooltip
/// can show all four.
@immutable
class ChartCandle {
  /// Creates a candle.
  const ChartCandle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  /// The first price of the period.
  final double open;

  /// The highest price of the period.
  final double high;

  /// The lowest price of the period.
  final double low;

  /// The last price of the period.
  final double close;

  /// Whether the candle closes at or above its open.
  bool get isUp => close >= open;

  @override
  bool operator ==(Object other) =>
      other is ChartCandle &&
      other.open == open &&
      other.high == high &&
      other.low == low &&
      other.close == close;

  @override
  int get hashCode => Object.hash(open, high, low, close);

  @override
  String toString() => 'ChartCandle(open: $open, high: $high, low: $low, close: $close)';
}

/// How a [CandlestickSeries] draws a candle.
enum CandleStyle {
  /// A filled body between the open and the close, and a wick from the low
  /// to the high.
  filled,

  /// As [filled], except that a candle that closes at or above its open has
  /// an outlined body.
  hollow,

  /// A bar from the low to the high, with a tick to the left at the open and
  /// one to the right at the close.
  ohlc,
}

/// Candlesticks, one per row of a [ChartData] that has a value column each for
/// the open, high, low and close.
///
/// Each candle is centred on its x value. Its body is [widthFactor] × [step]
/// data units wide and spans from the open to the close; its wick spans from the
/// low to the high. A candle that closes at or above its open is drawn in
/// [upColor], any other in [downColor]. [style] draws hollow candles or OHLC
/// bars instead.
///
/// When there are more candles than pixels, each pixel column is drawn as one
/// candle made of the rows in it: from their lowest low to their highest high,
/// coloured by their first open and last close. A long history stays cheap to
/// pan and no extreme is lost.
///
/// For a candle that is still forming, change its row with
/// `ChartData.setValue`; start the next one with `ChartData.addRow`.
class CandlestickSeries extends StatelessWidget {
  /// Creates a candlestick series.
  const CandlestickSeries({
    super.key,
    required this.data,
    this.openColumn = 0,
    this.highColumn = 1,
    this.lowColumn = 2,
    this.closeColumn = 3,
    this.id,
    this.label,
    this.upColor = const Color(0xFF59A14F),
    this.downColor = const Color(0xFFE15759),
    this.style = CandleStyle.filled,
    double? widthFactor,
    this.step,
    this.wickWidth = 1,
    this.visible = true,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.clip = true,
    this.isolate = true,
    @Deprecated('Use widthFactor. Removed in 0.3.0.') double? width,
  }) : widthFactor = widthFactor ?? width ?? 0.7;

  /// The data to plot.
  final ChartData data;

  /// The value column holding the open of each candle.
  final int openColumn;

  /// The value column holding the high of each candle.
  final int highColumn;

  /// The value column holding the low of each candle.
  final int lowColumn;

  /// The value column holding the close of each candle.
  final int closeColumn;

  /// Identifier of the series.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Colour of a candle that closes at or above its open. It is also the
  /// colour legends and tooltips show for the series.
  final Color upColor;

  /// Colour of a candle that closes below its open.
  final Color downColor;

  /// How a candle is drawn: filled, hollow or as an OHLC bar.
  final CandleStyle style;

  /// Body width as a fraction of [step]. Defaults to `0.7`.
  final double widthFactor;

  /// The old name of [widthFactor].
  @Deprecated('Use widthFactor. Removed in 0.3.0.')
  double get width => widthFactor;

  /// Distance between candles in data units. Defaults to the smallest
  /// distance between the first rows, so a weekend or a night without rows
  /// does not widen the candles.
  final double? step;

  /// Wick width in logical pixels. `0` draws no wicks. It is also the
  /// thickness of the outline of a hollow candle and of the lines of an OHLC
  /// bar, which are at least one pixel thick.
  final double wickWidth;

  /// Whether the series is shown; a hidden series stays listed for legends.
  final bool visible;

  /// Id of the horizontal scale.
  final Object xScale;

  /// Id of the vertical scale.
  final Object yScale;

  /// Whether the candles are clipped to the plot area.
  final bool clip;

  /// Whether the series paints into its own compositing layer.
  final bool isolate;

  @override
  Widget build(BuildContext context) {
    return ChartPaint(
      id: id,
      label: label,
      color: upColor,
      visible: visible,
      clip: clip,
      isolate: isolate,
      painter: CandlestickSeriesPainter(
        data: data,
        openColumn: openColumn,
        highColumn: highColumn,
        lowColumn: lowColumn,
        closeColumn: closeColumn,
        upColor: upColor,
        downColor: downColor,
        style: style,
        widthFactor: widthFactor,
        step: step,
        wickWidth: wickWidth,
        xScale: xScale,
        yScale: yScale,
      ),
    );
  }
}

/// Paints a [CandlestickSeries]. Built entirely on the public
/// [ChartSeriesPainter] contract.
///
/// A hit has the close as its `y`, the candle's four prices as its `datum` (a
/// [ChartCandle]) and the candle's on-screen box as its `rect`. Its `position`
/// is the top of the wick, so a tooltip sits clear of the candle.
class CandlestickSeriesPainter extends ChartSeriesPainter {
  /// Creates a candlestick painter.
  CandlestickSeriesPainter({
    required this.data,
    this.openColumn = 0,
    this.highColumn = 1,
    this.lowColumn = 2,
    this.closeColumn = 3,
    required this.upColor,
    required this.downColor,
    this.style = CandleStyle.filled,
    double? widthFactor,
    this.step,
    this.wickWidth = 1,
    super.xScale,
    super.yScale,
    @Deprecated('Use widthFactor. Removed in 0.3.0.') double? width,
  }) : widthFactor = widthFactor ?? width ?? 0.7,
       assert(
         data.valueColumns >
             math.max(math.max(openColumn, highColumn), math.max(lowColumn, closeColumn)),
         'A candlestick series needs a ChartData with a value column each for '
         'the open, high, low and close, for example ChartData(valueColumns: 4)',
       ),
       super(data: data);

  /// The data to plot.
  final ChartData data;

  /// The value column holding the open.
  final int openColumn;

  /// The value column holding the high.
  final int highColumn;

  /// The value column holding the low.
  final int lowColumn;

  /// The value column holding the close.
  final int closeColumn;

  /// Colour of a candle that closes at or above its open.
  final Color upColor;

  /// Colour of a candle that closes below its open.
  final Color downColor;

  /// How a candle is drawn.
  final CandleStyle style;

  /// Body width as a fraction of the step.
  final double widthFactor;

  /// The old name of [widthFactor].
  @Deprecated('Use widthFactor. Removed in 0.3.0.')
  double get width => widthFactor;

  /// Distance between candles in data units.
  final double? step;

  /// Wick width in logical pixels.
  final double wickWidth;

  // Rows looked at to find the distance between candles.
  static const int _stepSample = 16;

  double get _step {
    final double? s = step;
    if (s != null) return s;
    // Markets close, so the gap between two rows can be a night or a weekend.
    // The smallest gap among the first rows is the candle period.
    double smallest = double.infinity;
    if (data.isSorted) {
      final int rows = math.min(data.length, _stepSample);
      for (int i = 1; i < rows; i++) {
        final double gap = data.x(i) - data.x(i - 1);
        if (gap > 0 && gap < smallest) smallest = gap;
      }
    }
    return smallest.isFinite ? smallest : 1;
  }

  double get _half => _step * widthFactor / 2;

  // The pixel width of one step around the candle at [x], drawn at [centre].
  // Both sides are measured: a scale that gives closed hours no room squeezes
  // the step before the first candle of a session, or after the last, to
  // nothing.
  static double _stepPixels(ChartScaleView xs, double x, double centre, double step) =>
      math.max((xs.toPixel(x + step) - centre).abs(), (centre - xs.toPixel(x - step)).abs());

  /// The four prices of row [index], or null when one of them is missing.
  ChartCandle? candleAt(int index) {
    final double open = data.value(index, openColumn);
    final double high = data.value(index, highColumn);
    final double low = data.value(index, lowColumn);
    final double close = data.value(index, closeColumn);
    if (open.isNaN || high.isNaN || low.isNaN || close.isNaN) return null;
    return ChartCandle(open: open, high: high, low: low, close: close);
  }

  @override
  bool shouldRepaint(CandlestickSeriesPainter oldDelegate) =>
      shouldRescale(oldDelegate) ||
      oldDelegate.upColor != upColor ||
      oldDelegate.downColor != downColor ||
      oldDelegate.style != style ||
      oldDelegate.wickWidth != wickWidth;

  @override
  bool shouldRescale(CandlestickSeriesPainter oldDelegate) =>
      !identical(oldDelegate.data, data) ||
      oldDelegate.openColumn != openColumn ||
      oldDelegate.highColumn != highColumn ||
      oldDelegate.lowColumn != lowColumn ||
      oldDelegate.closeColumn != closeColumn ||
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.step != step;

  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    if (data.isEmpty) return null;
    final double half = _half;
    int start = 0;
    int end = data.length;
    if (xWindow != null && data.isSorted) {
      (start, end) = data.indexRange(xWindow.min - half, xWindow.max + half, overscan: 0);
    }
    final ChartRange? x = xWindow == null ? data.xExtent : data.xExtentWithin(xWindow);
    return ChartDataBounds(
      x: x == null ? null : ChartRange(x.min - half, x.max + half),
      y: ChartRange.merge(
        data.valueExtent(column: lowColumn, start: start, end: end, within: yWindow),
        data.valueExtent(column: highColumn, start: start, end: end, within: yWindow),
      ),
    );
  }

  /// The close of the candle whose step contains [x].
  @override
  double? valueAt(double x) {
    final int i = data.nearestIndex(x);
    if (i < 0 || (x - data.x(i)).abs() > _step / 2) return null;
    final double close = data.value(i, closeColumn);
    return close.isNaN ? null : close;
  }

  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    // The rows run along x, so none of them is the one at a given y.
    if (data.isEmpty || query.mode == ChartHitMode.nearestY) return;
    final ChartView view = query.view;
    if (!view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) return;
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    final int i = data.nearestIndex(xs.toValue(query.position.dx));
    if (i < 0) return;
    final ChartCandle? candle = candleAt(i);
    if (candle == null) return;
    final Rect? rect = _boxOf(i, candle, xs, ys);
    if (rect == null) return;
    final Offset outside = Offset(
      math.max(0, (query.position.dx - rect.center.dx).abs() - rect.width / 2),
      math.max(0, (query.position.dy - rect.center.dy).abs() - rect.height / 2),
    );
    final double distance = query.mode == ChartHitMode.nearestX ? outside.dx : outside.distance;
    if (distance > query.maxDistance) return;
    hits.add(_hitOf(i, candle, rect, distance));
  }

  @override
  void visitMarks(ChartView view, bool Function(ChartHit mark) visit) {
    if (data.isEmpty || !view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) {
      return;
    }
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    final double half = _half;
    final (int start, int end) = data.isSorted
        ? data.indexRange(xs.min - half, xs.max + half, overscan: 0)
        : (0, data.length);
    for (int i = start; i < end; i++) {
      final ChartCandle? candle = candleAt(i);
      if (candle == null) continue;
      final Rect? rect = _boxOf(i, candle, xs, ys);
      if (rect == null) continue;
      if (!visit(_hitOf(i, candle, rect, 0))) return;
    }
  }

  // The box around the candle of row [i], from its low to its high, or null
  // when the scales cannot show it.
  Rect? _boxOf(int i, ChartCandle candle, ChartScaleView xs, ChartScaleView ys) {
    final double x = data.x(i);
    final double centre = xs.toPixel(x);
    final double half = _stepPixels(xs, x, centre, _step) * widthFactor / 2;
    final Rect rect = Rect.fromPoints(
      Offset(centre - half, ys.toPixel(candle.low)),
      Offset(centre + half, ys.toPixel(candle.high)),
    );
    return rect.isFinite ? rect : null;
  }

  ChartHit _hitOf(int i, ChartCandle candle, Rect rect, double distance) => ChartHit(
    x: data.x(i),
    y: candle.close,
    position: rect.topCenter,
    distance: distance,
    index: i,
    datum: candle,
    rect: rect,
  );

  @override
  bool hitTest(Offset position, ChartView view) => false;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    if (data.isEmpty || !view.scales.containsKey(xScale) || !view.scales.containsKey(yScale)) {
      return;
    }
    final ChartScaleView xs = view.scale(xScale);
    final ChartScaleView ys = view.scale(yScale);
    if (xs.extent <= 0 || ys.extent <= 0) return;
    final double step = _step;
    final double half = step * widthFactor / 2;
    final (int start, int end) = data.isSorted
        ? data.indexRange(xs.min - half, xs.max + half, overscan: 0)
        : (0, data.length);
    if (end <= start) return;

    // One path per colour, so a frame is two draw calls however many candles
    // it shows.
    final ui.Path up = ui.Path();
    final ui.Path down = ui.Path();
    // Far off-screen ends are pulled in, so rasterizers never see huge
    // coordinates when the price scale is stretched.
    final double above = -ys.extent;
    final double below = ys.extent * 2;
    void box(ui.Path path, double x1, double x2, double y1, double y2) {
      double top = math.min(y1, y2).clamp(above, below);
      double bottom = math.max(y1, y2).clamp(above, below);
      if (bottom - top < 1) {
        // A flat candle still shows, as a hairline.
        top = (top + bottom - 1) / 2;
        bottom = top + 1;
      }
      path.addRect(Rect.fromLTRB(math.min(x1, x2), top, math.max(x1, x2), bottom));
    }

    // Thickness of the outline of a hollow candle and of an OHLC bar.
    final double line = math.max(1, wickWidth);
    final double first = data.x(start);
    if (data.isSorted && _stepPixels(xs, first, xs.toPixel(first), step) < 1) {
      // More candles than pixels: one candle per pixel column.
      final bool ascending = xs.toPixel(xs.max) >= xs.toPixel(xs.min);
      int row = start;
      for (int k = 0; k < xs.extent.ceil() && row < end; k++) {
        final double edge = ascending ? xs.toValue(k + 1.0) : xs.toValue(xs.extent - (k + 1.0));
        final int rowEnd = math.min(end, math.max(row, data.lowerBound(edge)));
        if (rowEnd <= row) continue;
        final (double low, _) = data.minMax(row, rowEnd, column: lowColumn);
        final (_, double high) = data.minMax(row, rowEnd, column: highColumn);
        if (low <= high) {
          double open = double.nan;
          for (int i = row; i < rowEnd && open.isNaN; i++) {
            open = data.value(i, openColumn);
          }
          double close = double.nan;
          for (int i = rowEnd - 1; i >= row && close.isNaN; i--) {
            close = data.value(i, closeColumn);
          }
          final double left = ascending ? k.toDouble() : xs.extent - (k + 1.0);
          box(close < open ? down : up, left, left + 1, ys.toPixel(low), ys.toPixel(high));
        }
        row = rowEnd;
      }
    } else {
      for (int i = start; i < end; i++) {
        final double open = data.value(i, openColumn);
        final double high = data.value(i, highColumn);
        final double low = data.value(i, lowColumn);
        final double close = data.value(i, closeColumn);
        if (open.isNaN || high.isNaN || low.isNaN || close.isNaN) continue;
        final ui.Path path = close < open ? down : up;
        final double x = data.x(i);
        final double centre = xs.toPixel(x);
        final double body = _stepPixels(xs, x, centre, step) * widthFactor;
        final double left = centre - body / 2;
        final double right = centre + body / 2;
        final double yOpen = ys.toPixel(open);
        final double yClose = ys.toPixel(close);
        final double yLow = ys.toPixel(low);
        final double yHigh = ys.toPixel(high);
        void wick(double from, double to) {
          if (wickWidth > 0) box(path, centre - wickWidth / 2, centre + wickWidth / 2, from, to);
        }

        switch (style) {
          case CandleStyle.filled:
            wick(yLow, yHigh);
            // A body no wider than its wick adds nothing to it.
            if (body > wickWidth) box(path, left, right, yOpen, yClose);
          case CandleStyle.hollow:
            final double top = math.min(yOpen, yClose);
            final double bottom = math.max(yOpen, yClose);
            // An outline needs room between its edges.
            final bool outlined =
                close >= open && body > line * 2 + 1 && bottom - top > line * 2 + 1;
            if (!outlined) {
              wick(yLow, yHigh);
              if (body > wickWidth) box(path, left, right, yOpen, yClose);
            } else {
              // The wick stops at the body, so the body stays empty.
              if (top - yHigh >= 0.5) wick(yHigh, top);
              if (yLow - bottom >= 0.5) wick(bottom, yLow);
              box(path, left, right, top, top + line);
              box(path, left, right, bottom - line, bottom);
              box(path, left, left + line, top, bottom);
              box(path, right - line, right, top, bottom);
            }
          case CandleStyle.ohlc:
            box(path, centre - line / 2, centre + line / 2, yLow, yHigh);
            if (body > line) {
              box(path, left, centre, yOpen - line / 2, yOpen + line / 2);
              box(path, centre, right, yClose - line / 2, yClose + line / 2);
            }
        }
      }
    }
    context.canvas
      ..drawPath(up, Paint()..color = upColor)
      ..drawPath(down, Paint()..color = downColor);
  }
}
