import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Axis;

import 'range.dart';
import 'scale.dart';
import 'ticks.dart';

/// Identifies the default horizontal scale of a chart.
const Object kChartX = 'x';

/// Identifies the default vertical scale of a chart.
const Object kChartY = 'y';

/// The state of one scale for one frame: its visible window and how values
/// map to pixels along the plot.
@immutable
class ChartScaleView {
  /// Creates a scale view. Normally only the chart does this.
  ChartScaleView({
    required this.id,
    required this.scale,
    required this.scaledMin,
    required this.scaledMax,
    required this.extent,
    required this.direction,
  });

  /// The id of the scale within its chart.
  final Object id;

  /// The scale configuration.
  final ChartScale scale;

  /// Lower bound of the visible window in scale space.
  final double scaledMin;

  /// Upper bound of the visible window in scale space.
  final double scaledMax;

  /// Length of the plot along this scale, in logical pixels.
  final double extent;

  /// Whether the scale runs horizontally or vertically on screen.
  final Axis direction;

  /// Lower bound of the visible window, in data units.
  late final double min = scale.invert(scaledMin);

  /// Upper bound of the visible window, in data units.
  late final double max = scale.invert(scaledMax);

  /// The visible window in data units.
  ChartRange get range => ChartRange(min, max);

  /// Width of the visible window in scale space.
  double get scaledSpan => scaledMax - scaledMin;

  /// Logical pixels per scale-space unit.
  double get pixelsPerUnit => scaledSpan > 0 ? extent / scaledSpan : 0;

  // Whether pixel coordinates grow against scale values. Vertical scales grow
  // upwards by default, i.e. against the pixel axis.
  bool get _flipped => (direction == Axis.vertical) != scale.reversed;

  /// The pixel position of [value] along the plot.
  double toPixel(double value) => scaledToPixel(scale.transform(value));

  /// The pixel position of a scale-space coordinate.
  double scaledToPixel(double scaled) {
    final double t = scaledSpan > 0 ? (scaled - scaledMin) / scaledSpan : 0;
    return _flipped ? extent - t * extent : t * extent;
  }

  /// The data value at [pixel].
  double toValue(double pixel) => scale.invert(pixelToScaled(pixel));

  /// The scale-space coordinate at [pixel].
  double pixelToScaled(double pixel) {
    final double t = extent > 0 ? pixel / extent : 0;
    return scaledMin + (_flipped ? 1 - t : t) * scaledSpan;
  }

  /// The pixel length of [dataLength] data units starting at [at] (defaults
  /// to the window start). Exact everywhere on linear scales.
  double lengthToPixels(double dataLength, {double? at}) {
    final double from = at ?? min;
    return (toPixel(from + dataLength) - toPixel(from)).abs();
  }

  /// Whether [value] is inside the visible window.
  bool contains(double value) => value >= min && value <= max;

  /// What a tick provider needs to know about this window.
  ChartTickContext get tickContext =>
      ChartTickContext(min: min, max: max, extent: extent, direction: direction);

  /// The ticks for this window, computed once on demand.
  late final List<ChartTick> ticks = scale.effectiveTicks.generate(tickContext);

  /// The values of the minor ticks for this window, computed once on demand.
  /// Empty unless the ticks of the scale have them, as `LinearTicks` does
  /// with a `minorCount`.
  late final List<double> minorTicks = scale.effectiveTicks.generateMinor(tickContext, ticks);

  @override
  bool operator ==(Object other) =>
      other is ChartScaleView &&
      other.id == id &&
      other.scale == scale &&
      other.scaledMin == scaledMin &&
      other.scaledMax == scaledMax &&
      other.extent == extent &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(id, scale, scaledMin, scaledMax, extent, direction);

  @override
  String toString() => 'ChartScaleView($id: $min..$max over ${extent}px)';
}

/// The immutable coordinate snapshot every layer of a chart shares for one
/// frame.
///
/// Pixel coordinates are local to the plot area: `(0, 0)` is its top-left
/// corner. Anything outside `Offset.zero & size` is in a gutter.
@immutable
class ChartView {
  /// Creates a view. Normally only the chart does this.
  const ChartView({required this.size, required this.chartRect, required this.scales});

  /// Size of the plot area.
  final Size size;

  /// The whole chart, gutters included, in plot-local coordinates.
  final Rect chartRect;

  /// All scales of the chart by id.
  final Map<Object, ChartScaleView> scales;

  /// The plot area in its own coordinates.
  Rect get plotRect => Offset.zero & size;

  /// The default horizontal scale.
  ChartScaleView get x => scale(kChartX);

  /// The default vertical scale.
  ChartScaleView get y => scale(kChartY);

  /// The scale registered under [id].
  ChartScaleView scale(Object id) {
    final ChartScaleView? result = scales[id];
    if (result == null) {
      throw ArgumentError.value(id, 'id', 'This chart has no scale with that id');
    }
    return result;
  }

  /// The plot-local position of the data point `(x, y)`.
  Offset toPixel(double x, double y, {Object xScale = kChartX, Object yScale = kChartY}) =>
      Offset(scale(xScale).toPixel(x), scale(yScale).toPixel(y));

  /// The data point under a plot-local [position].
  ({double x, double y}) toValue(
    Offset position, {
    Object xScale = kChartX,
    Object yScale = kChartY,
  }) => (x: scale(xScale).toValue(position.dx), y: scale(yScale).toValue(position.dy));

  /// The plot-local rectangle covering a data-space rectangle.
  Rect toRect(
    double x1,
    double y1,
    double x2,
    double y2, {
    Object xScale = kChartX,
    Object yScale = kChartY,
  }) => Rect.fromPoints(
    toPixel(x1, y1, xScale: xScale, yScale: yScale),
    toPixel(x2, y2, xScale: xScale, yScale: yScale),
  );

  /// Converts a position local to the whole chart into plot-local coordinates.
  Offset chartToPlot(Offset chartPosition) => chartPosition + chartRect.topLeft;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChartView &&
          other.size == size &&
          other.chartRect == chartRect &&
          mapEquals(other.scales, scales));

  @override
  int get hashCode => Object.hash(size, chartRect, Object.hashAll(scales.values));

  @override
  String toString() => 'ChartView($size, ${scales.values.join(', ')})';
}
