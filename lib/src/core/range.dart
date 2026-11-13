import 'package:flutter/foundation.dart';

/// A closed interval `[min, max]` of data values.
@immutable
class ChartRange {
  /// Creates a range. [max] must not be smaller than [min].
  const ChartRange(this.min, this.max) : assert(max >= min, 'max must be >= min');

  /// Creates a range from two unordered values.
  factory ChartRange.of(double a, double b) => a <= b ? ChartRange(a, b) : ChartRange(b, a);

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// `max - min`.
  double get span => max - min;

  /// The midpoint.
  double get center => (min + max) / 2;

  /// Whether both bounds are finite.
  bool get isFinite => min.isFinite && max.isFinite;

  /// Whether [value] lies inside the range, bounds included.
  bool contains(double value) => value >= min && value <= max;

  /// Whether this range and [other] share at least one value.
  bool overlaps(ChartRange other) => other.max >= min && other.min <= max;

  /// The smallest range containing both this range and [other].
  ChartRange union(ChartRange other) =>
      ChartRange(other.min < min ? other.min : min, other.max > max ? other.max : max);

  /// The smallest range containing this range and [value].
  ChartRange include(double value) =>
      ChartRange(value < min ? value : min, value > max ? value : max);

  /// This range moved by [delta].
  ChartRange shift(double delta) => ChartRange(min + delta, max + delta);

  /// This range grown by [amount] on both sides.
  ChartRange inflate(double amount) => ChartRange(min - amount, max + amount);

  /// [value] clamped into the range.
  double clamp(double value) => value < min ? min : (value > max ? max : value);

  /// The union of two optional ranges.
  static ChartRange? merge(ChartRange? a, ChartRange? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.union(b);
  }

  @override
  bool operator ==(Object other) => other is ChartRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'ChartRange($min, $max)';
}

/// The data extent of a series: an optional range per dimension.
@immutable
class ChartDataBounds {
  /// Creates data bounds. A null range means "no data in that dimension".
  const ChartDataBounds({this.x, this.y});

  /// Extent along the series' x scale.
  final ChartRange? x;

  /// Extent along the series' y scale.
  final ChartRange? y;

  @override
  bool operator ==(Object other) => other is ChartDataBounds && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'ChartDataBounds(x: $x, y: $y)';
}
