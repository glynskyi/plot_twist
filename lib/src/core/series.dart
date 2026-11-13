import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter/foundation.dart';

import 'chart_view.dart';
import 'range.dart';

/// How a pointer position is matched to data points.
enum ChartHitMode {
  /// The closest point along the x scale, one per series. Best for line and
  /// bar charts and for crosshairs.
  nearestX,

  /// The closest point by on-screen distance. Best for scatter plots.
  nearest,
}

/// A request to find the data under (or near) a position.
@immutable
class ChartHitQuery {
  /// Creates a query.
  const ChartHitQuery({
    required this.position,
    required this.view,
    this.mode = ChartHitMode.nearestX,
    this.maxDistance = double.infinity,
  });

  /// The plot-local position being queried.
  final Offset position;

  /// The view to resolve data positions with.
  final ChartView view;

  /// How candidates are ranked.
  final ChartHitMode mode;

  /// Candidates further than this many logical pixels are ignored.
  final double maxDistance;
}

/// One data point found by a hit query.
@immutable
class ChartHit {
  /// Creates a hit.
  const ChartHit({
    required this.x,
    required this.y,
    required this.position,
    required this.distance,
    this.index,
    this.series,
    this.datum,
    this.rect,
  });

  /// The x value of the data point.
  final double x;

  /// The y value of the data point.
  final double y;

  /// Plot-local pixel position of the data point.
  final Offset position;

  /// Distance from the query position, in logical pixels.
  final double distance;

  /// Index of the point within its series, if it has one.
  final int? index;

  /// The series the point belongs to.
  final ChartSeries? series;

  /// The app's own object behind the point, if the series exposes one.
  final Object? datum;

  /// The on-screen rectangle of the mark (for bars and similar), if any.
  final Rect? rect;

  /// A copy of this hit attributed to [series].
  ChartHit withSeries(ChartSeries series) => ChartHit(
    x: x,
    y: y,
    position: position,
    distance: distance,
    index: index,
    series: series,
    datum: datum,
    rect: rect,
  );

  /// Whether this hit refers to the same data point as [other], regardless of
  /// where it currently is on screen.
  bool isSamePoint(ChartHit other) =>
      identical(other.series, series) && other.index == index && other.x == x && other.y == y;

  @override
  String toString() => 'ChartHit(${series?.label ?? series?.id}, #$index, $x, $y)';
}

/// A list of hits with data-point equality, so tooltip builders rebuild only
/// when the pointed-at data changes — not when it merely moves on screen.
@immutable
class ChartHitSet {
  /// Wraps [hits].
  const ChartHitSet(this.hits);

  /// No hits.
  static const ChartHitSet empty = ChartHitSet(<ChartHit>[]);

  /// The hits, closest first.
  final List<ChartHit> hits;

  /// Whether there are no hits.
  bool get isEmpty => hits.isEmpty;

  /// Whether there is at least one hit.
  bool get isNotEmpty => hits.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (other is! ChartHitSet || other.hits.length != hits.length) return false;
    for (int i = 0; i < hits.length; i++) {
      if (!hits[i].isSamePoint(other.hits[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hashAll(hits.map((ChartHit h) => Object.hash(h.series, h.index, h.x, h.y)));
}

/// A series registered with a chart: everything legends, tooltips, crosshairs
/// and auto-ranging need to know about it.
///
/// Obtain series from `ChartController.series` or `ChartController.seriesById`.
abstract class ChartSeries {
  /// App-chosen identifier, if any.
  Object? get id;

  /// Human-readable name, for legends and tooltips.
  String? get label;

  /// Representative colour, for legends and tooltips.
  Color? get color;

  /// Whether the series is shown. A hidden series stays registered — so a
  /// legend can still list it — but is not painted, hit or auto-ranged.
  bool get visible;

  /// Id of the horizontal scale the series is plotted on.
  Object get xScale;

  /// Id of the vertical scale the series is plotted on.
  Object get yScale;

  /// The data extent of the series.
  ///
  /// With [xWindow] (or [yWindow]) only data inside that window counts; this
  /// is how a scale fits itself to what is visible.
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow});

  /// The y value of the drawn series at [x], interpolated the same way it is
  /// drawn, or null if the series has no value there.
  double? valueAt(double x);

  /// Adds the data points matching [query] to [hits].
  void collectHits(ChartHitQuery query, List<ChartHit> hits);
}
