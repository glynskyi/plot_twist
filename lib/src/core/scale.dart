import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'range.dart';
import 'ticks.dart';

/// What a [ChartRangePolicy] or [ChartLimits] can ask about the data plotted
/// on its scale.
abstract class ChartRangeContext {
  /// The scale being resolved.
  ChartScale get scale;

  /// The extent of all data plotted on this scale, or null if there is none.
  ///
  /// With [visibleOnly], only data inside the visible windows of the other
  /// scales is considered — this is what makes "fit Y to the visible X range"
  /// work.
  ChartRange? dataExtent({bool visibleOnly = false});
}

/// Decides which window a scale shows while it is in automatic mode.
///
/// A scale stays automatic until the user (or code) pans, zooms or jumps; it
/// returns to automatic on `resetToAuto()`. Subclass this to add a policy.
abstract class ChartRangePolicy {
  /// Const constructor for subclasses.
  const ChartRangePolicy();

  /// Shows all data on the scale.
  const factory ChartRangePolicy.fit({
    double padding,
    double margin,
    bool includeZero,
    ChartRange fallback,
  }) = FitDataRange;

  /// Shows the data that is visible in the other dimension, re-fitting as
  /// that dimension is panned or zoomed.
  const factory ChartRangePolicy.fitVisible({
    double padding,
    double margin,
    bool includeZero,
    ChartRange fallback,
  }) = FitVisibleRange;

  /// Shows exactly `[min, max]`.
  const factory ChartRangePolicy.fixed(double min, double max) = FixedRange;

  /// Shows the latest [span] units of data, following new data as it arrives.
  const factory ChartRangePolicy.follow({required double span, double lead}) = FollowRange;

  /// The window, in data units, this policy wants to show.
  ChartRange resolve(ChartRangeContext context);

  /// Whether the result depends on the visible windows of other scales.
  bool get dependsOnVisibleData => false;
}

ChartRange _fit(
  ChartRangeContext context,
  ChartRange? extent, {
  required double padding,
  required double margin,
  required bool includeZero,
  required ChartRange fallback,
}) {
  if (extent == null || !extent.isFinite) return fallback;
  final ChartScale scale = context.scale;
  final ChartRange data = includeZero ? extent.include(0) : extent;
  double lo = scale.transform(data.min);
  double hi = scale.transform(data.max);
  if (!lo.isFinite || !hi.isFinite) return fallback;
  if (hi - lo <= 0) {
    final double nudge = lo == 0 ? 0.5 : lo.abs() * 0.05;
    lo -= nudge;
    hi += nudge;
  }
  final double pad = (hi - lo) * padding;
  // When zero was added as a baseline, things should sit on it: no padding
  // on that side.
  final bool restsOnZero = includeZero && extent.min >= 0;
  final bool hangsFromZero = includeZero && extent.max <= 0;
  final double min = restsOnZero ? data.min : scale.invert(lo - pad) - margin;
  final double max = hangsFromZero ? data.max : scale.invert(hi + pad) + margin;
  return max > min ? ChartRange(min, max) : fallback;
}

/// Fits all data plotted on the scale.
class FitDataRange extends ChartRangePolicy {
  /// Creates a fit-all policy.
  ///
  /// [padding] is a fraction of the data span added on each side; [margin] is
  /// an absolute amount in data units.
  const FitDataRange({
    this.padding = 0,
    this.margin = 0,
    this.includeZero = false,
    this.fallback = const ChartRange(0, 1),
  });

  /// Fraction of the data span added on both sides.
  final double padding;

  /// Data units added on both sides.
  final double margin;

  /// Whether zero is always part of the window.
  final bool includeZero;

  /// The window used when there is no data.
  final ChartRange fallback;

  @override
  ChartRange resolve(ChartRangeContext context) => _fit(
    context,
    context.dataExtent(),
    padding: padding,
    margin: margin,
    includeZero: includeZero,
    fallback: fallback,
  );

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is FitDataRange &&
      other.padding == padding &&
      other.margin == margin &&
      other.includeZero == includeZero &&
      other.fallback == fallback;

  @override
  int get hashCode => Object.hash(runtimeType, padding, margin, includeZero, fallback);
}

/// Fits the data that is visible in the other dimension.
class FitVisibleRange extends FitDataRange {
  /// Creates a fit-visible policy. See [FitDataRange] for the parameters.
  const FitVisibleRange({super.padding = 0.08, super.margin, super.includeZero, super.fallback});

  @override
  ChartRange resolve(ChartRangeContext context) => _fit(
    context,
    context.dataExtent(visibleOnly: true) ?? context.dataExtent(),
    padding: padding,
    margin: margin,
    includeZero: includeZero,
    fallback: fallback,
  );

  @override
  bool get dependsOnVisibleData => true;
}

/// Fits whole bands on a band scale: from half a band before the first
/// category to half a band after the last, whatever the series draw.
class FitBandsRange extends ChartRangePolicy {
  /// Creates a fit-bands policy.
  const FitBandsRange({this.fallback = const ChartRange(-0.5, 0.5)});

  /// The window used when there is no data.
  final ChartRange fallback;

  @override
  ChartRange resolve(ChartRangeContext context) {
    final ChartRange? extent = context.dataExtent();
    if (extent == null || !extent.isFinite) return fallback;
    // Series may report their bars' edges; snap outwards to band boundaries.
    final double min = (extent.min + 0.5).floorToDouble() - 0.5;
    final double max = (extent.max - 0.5).ceilToDouble() + 0.5;
    return max > min ? ChartRange(min, max) : fallback;
  }

  @override
  bool operator ==(Object other) => other is FitBandsRange && other.fallback == fallback;

  @override
  int get hashCode => fallback.hashCode;
}

/// Always shows `[min, max]`.
class FixedRange extends ChartRangePolicy {
  /// Creates a fixed window.
  const FixedRange(this.min, this.max);

  /// Lower bound of the window.
  final double min;

  /// Upper bound of the window.
  final double max;

  @override
  ChartRange resolve(ChartRangeContext context) => ChartRange(min, max);

  @override
  bool operator ==(Object other) => other is FixedRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// Shows the most recent [span] units of data.
class FollowRange extends ChartRangePolicy {
  /// Creates a follow policy. [lead] leaves empty room after the newest value.
  const FollowRange({required this.span, this.lead = 0});

  /// Width of the window, in data units.
  final double span;

  /// Empty room after the newest value, in data units.
  final double lead;

  @override
  ChartRange resolve(ChartRangeContext context) {
    final double end = (context.dataExtent()?.max ?? span) + lead;
    return ChartRange(end - span, end);
  }

  @override
  bool operator ==(Object other) =>
      other is FollowRange && other.span == span && other.lead == lead;

  @override
  int get hashCode => Object.hash(span, lead);
}

/// How far a scale may be panned and zoomed.
///
/// Subclass and override [bounds] for limits that depend on app state (for
/// example the part of a domain a loader is allowed to reach).
class ChartLimits {
  /// Explicit limits in data units. Null sides are unbounded.
  const ChartLimits({this.min, this.max, this.minSpan, this.maxSpan}) : dataPadding = null;

  /// The window may not leave the data extent, grown by [padding] (a fraction
  /// of the extent) on both sides.
  const ChartLimits.data({double padding = 0, this.minSpan, this.maxSpan})
    : dataPadding = padding,
      min = null,
      max = null;

  /// Lower bound of the pannable domain.
  final double? min;

  /// Upper bound of the pannable domain.
  final double? max;

  /// When non-null, bounds follow the data extent with this padding fraction.
  final double? dataPadding;

  /// Smallest window width the user can zoom to, in scale-space units.
  final double? minSpan;

  /// Largest window width the user can zoom to, in scale-space units.
  final double? maxSpan;

  /// The pannable domain in data units; null sides are unbounded.
  (double? min, double? max) bounds(ChartRangeContext context) {
    final double? padding = dataPadding;
    if (padding == null) return (min, max);
    final ChartRange? extent = context.dataExtent();
    if (extent == null || !extent.isFinite) return (null, null);
    final ChartScale scale = context.scale;
    final double lo = scale.transform(extent.min);
    final double hi = scale.transform(extent.max);
    final double pad = (hi - lo) * padding;
    return (scale.invert(lo - pad), scale.invert(hi + pad));
  }

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is ChartLimits &&
      other.min == min &&
      other.max == max &&
      other.dataPadding == dataPadding &&
      other.minSpan == minSpan &&
      other.maxSpan == maxSpan;

  @override
  int get hashCode => Object.hash(runtimeType, min, max, dataPadding, minSpan, maxSpan);
}

/// One dimension of a chart: how values map to positions, which window is
/// shown by default, how far it can be moved, and where its ticks go.
///
/// A scale is immutable configuration. The live window lives in a
/// `ChartScaleController`; a new, equal scale passed on rebuild never resets
/// it.
///
/// Subclass this for a custom mapping: implement [transform] and [invert]
/// (strictly increasing) and [defaultTicks]. Subclasses that add fields must
/// include them in `==` and `hashCode`.
abstract class ChartScale {
  /// Const constructor for subclasses.
  const ChartScale({
    this.range = const FitDataRange(),
    this.limits = const ChartLimits(),
    this.ticks,
    this.reversed = false,
  });

  /// A linear scale.
  const factory ChartScale.linear({
    ChartRangePolicy range,
    ChartLimits limits,
    ChartTicks? ticks,
    bool reversed,
  }) = LinearScale;

  /// A logarithmic scale.
  const factory ChartScale.log({
    double base,
    ChartRangePolicy range,
    ChartLimits limits,
    ChartTicks? ticks,
    bool reversed,
  }) = LogScale;

  /// A time scale. Values are milliseconds since the Unix epoch.
  const factory ChartScale.time({
    bool utc,
    ChartRangePolicy range,
    ChartLimits limits,
    ChartTicks? ticks,
    bool reversed,
  }) = TimeScale;

  /// A band (category) scale. Band `i` is centred on the value `i`.
  const factory ChartScale.band({
    List<String>? labels,
    ChartRangePolicy range,
    ChartLimits limits,
    ChartTicks? ticks,
    bool reversed,
  }) = BandScale;

  /// The window shown while the scale is in automatic mode.
  final ChartRangePolicy range;

  /// How far the window may be panned and zoomed.
  final ChartLimits limits;

  /// Tick strategy; null uses [defaultTicks].
  final ChartTicks? ticks;

  /// Whether values grow right-to-left (horizontal) or top-to-bottom
  /// (vertical) instead of the usual direction.
  final bool reversed;

  /// Maps a data value into scale space, where panning and zooming are linear.
  double transform(double value);

  /// The inverse of [transform].
  double invert(double scaled);

  /// The tick strategy used when [ticks] is null.
  ChartTicks get defaultTicks;

  /// [ticks] or, if null, [defaultTicks].
  ChartTicks get effectiveTicks => ticks ?? defaultTicks;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          other is ChartScale &&
          other.range == range &&
          other.limits == limits &&
          other.ticks == ticks &&
          other.reversed == reversed);

  @override
  int get hashCode => Object.hash(runtimeType, range, limits, ticks, reversed);
}

/// A linear scale.
class LinearScale extends ChartScale {
  /// Creates a linear scale.
  const LinearScale({super.range, super.limits, super.ticks, super.reversed});

  @override
  double transform(double value) => value;

  @override
  double invert(double scaled) => scaled;

  @override
  ChartTicks get defaultTicks => const LinearTicks();
}

/// A logarithmic scale. Values must be positive.
class LogScale extends ChartScale {
  /// Creates a logarithmic scale.
  const LogScale({this.base = 10, super.range, super.limits, super.ticks, super.reversed});

  /// The logarithm base.
  final double base;

  @override
  double transform(double value) =>
      value > 0 ? math.log(value) / math.log(base) : double.negativeInfinity;

  @override
  double invert(double scaled) => math.pow(base, scaled).toDouble();

  @override
  ChartTicks get defaultTicks => LogTicks(base: base);

  @override
  bool operator ==(Object other) => super == other && other is LogScale && other.base == base;

  @override
  int get hashCode => Object.hash(super.hashCode, base);
}

/// A time scale. Values are milliseconds since the Unix epoch.
class TimeScale extends ChartScale {
  /// Creates a time scale.
  const TimeScale({this.utc = false, super.range, super.limits, super.ticks, super.reversed});

  /// Whether ticks align to UTC rather than local time.
  final bool utc;

  /// The scale value of [time].
  static double valueOf(DateTime time) => time.millisecondsSinceEpoch.toDouble();

  /// The time a scale [value] stands for.
  static DateTime dateOf(double value, {bool utc = false}) =>
      DateTime.fromMillisecondsSinceEpoch(value.round(), isUtc: utc);

  @override
  double transform(double value) => value;

  @override
  double invert(double scaled) => scaled;

  @override
  ChartTicks get defaultTicks => TimeTicks(utc: utc);

  @override
  bool operator ==(Object other) => super == other && other is TimeScale && other.utc == utc;

  @override
  int get hashCode => Object.hash(super.hashCode, utc);
}

/// A band (category) scale: band `i` is centred on the value `i` and is one
/// unit wide.
class BandScale extends ChartScale {
  /// Creates a band scale. [labels] name the bands by index.
  const BandScale({
    this.labels,
    super.range = const FitBandsRange(),
    super.limits,
    super.ticks,
    super.reversed,
  });

  /// Category names, indexed by band value.
  final List<String>? labels;

  @override
  double transform(double value) => value;

  @override
  double invert(double scaled) => scaled;

  @override
  ChartTicks get defaultTicks => BandTicks(labels: labels);

  @override
  bool operator ==(Object other) =>
      super == other && other is BandScale && listEquals(other.labels, labels);

  @override
  int get hashCode => Object.hash(super.hashCode, labels == null ? null : Object.hashAll(labels!));
}

/// Converts between [DateTime] and time-scale values.
extension ChartDateTime on DateTime {
  /// This time as a value on a [TimeScale].
  double get chartValue => millisecondsSinceEpoch.toDouble();
}
