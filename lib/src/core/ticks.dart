import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Axis;

/// One mark on a scale: a data [value] and its default text [label].
@immutable
class ChartTick {
  /// Creates a tick.
  const ChartTick(this.value, this.label, {this.level = 0});

  /// The data value the tick sits at.
  final double value;

  /// Default text for the tick. Axis label builders may ignore it.
  final String label;

  /// Significance of the tick. `0` is a regular tick; higher levels mark
  /// boundaries such as a new day on a time scale.
  final int level;

  @override
  bool operator ==(Object other) =>
      other is ChartTick && other.value == value && other.label == label && other.level == level;

  @override
  int get hashCode => Object.hash(value, label, level);

  @override
  String toString() => 'ChartTick($value, "$label")';
}

/// A list of ticks with value equality, so layout builders rebuild only when
/// the set of ticks actually changes.
@immutable
class ChartTickSet {
  /// Wraps [ticks].
  const ChartTickSet(this.ticks);

  /// An empty set.
  static const ChartTickSet empty = ChartTickSet(<ChartTick>[]);

  /// The ticks, in ascending value order.
  final List<ChartTick> ticks;

  @override
  bool operator ==(Object other) => other is ChartTickSet && listEquals(other.ticks, ticks);

  @override
  int get hashCode => Object.hashAll(ticks);
}

/// What a tick provider needs to know to place ticks.
@immutable
class ChartTickContext {
  /// Creates a tick context.
  const ChartTickContext({
    required this.min,
    required this.max,
    required this.extent,
    required this.direction,
  });

  /// Lower bound of the visible window, in data units.
  final double min;

  /// Upper bound of the visible window, in data units.
  final double max;

  /// Length of the axis in logical pixels.
  final double extent;

  /// Whether the scale runs horizontally or vertically on screen.
  final Axis direction;

  /// A sensible number of ticks for [spacing] logical pixels between ticks.
  int targetCount(double? spacing) {
    final double s = spacing ?? (direction == Axis.horizontal ? 84.0 : 44.0);
    if (!(extent > 0)) return 2;
    return math.max(2, (extent / s).floor());
  }
}

/// Formats a tick value for display.
typedef ChartValueFormatter = String Function(double value);

/// Decides where ticks go and what their default labels say.
///
/// Subclass this to provide a custom tick strategy; the built-in ones are
/// [LinearTicks], [LogTicks], [TimeTicks], [BandTicks] and [FixedTicks].
abstract class ChartTicks {
  /// Const constructor for subclasses.
  const ChartTicks();

  /// "Nice" 1-2-5 ticks for a linear scale.
  const factory ChartTicks.linear({double? spacing, ChartValueFormatter? format}) = LinearTicks;

  /// Ticks at exactly the given values.
  const factory ChartTicks.fixed(List<double> values, {ChartValueFormatter? format}) = FixedTicks;

  /// Returns the ticks to show for [context], in ascending order.
  List<ChartTick> generate(ChartTickContext context);
}

/// Returns a "nice" step (1, 2, 2.5 or 5 times a power of ten) close to [raw].
double niceStep(double raw) {
  if (!(raw > 0) || !raw.isFinite) return 1;
  final double exponent = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final double fraction = raw / exponent;
  final double nice;
  if (fraction <= 1.0) {
    nice = 1;
  } else if (fraction <= 2.0) {
    nice = 2;
  } else if (fraction <= 2.5) {
    nice = 2.5;
  } else if (fraction <= 5.0) {
    nice = 5;
  } else {
    nice = 10;
  }
  return nice * exponent;
}

/// Formats [value] with just enough decimals to distinguish steps of [step].
String formatNumber(double value, {double? step}) {
  if (!value.isFinite) return '';
  int decimals = 0;
  if (step != null && step > 0) {
    // The fewest decimals that write the step exactly: 2.5 needs one, 0.25 two.
    double scaled = step;
    while (decimals < 10 && (scaled - scaled.roundToDouble()).abs() > 1e-9 * scaled.abs()) {
      scaled *= 10;
      decimals++;
    }
  } else {
    final double abs = value.abs();
    if (abs != abs.roundToDouble()) decimals = abs < 1 ? 3 : (abs < 100 ? 2 : 1);
  }
  String text = value.toStringAsFixed(decimals);
  if (double.parse(text) == 0) text = 0.0.toStringAsFixed(decimals);
  return text;
}

/// "Nice" ticks for a linear scale: multiples of 1, 2, 2.5 or 5 × 10ⁿ.
class LinearTicks extends ChartTicks {
  /// Creates linear ticks roughly [spacing] logical pixels apart.
  const LinearTicks({this.spacing, this.format});

  /// Target distance between ticks, in logical pixels.
  final double? spacing;

  /// Custom label formatter.
  final ChartValueFormatter? format;

  @override
  List<ChartTick> generate(ChartTickContext context) {
    final double span = context.max - context.min;
    if (!(span > 0) || !span.isFinite) return const <ChartTick>[];
    final double step = niceStep(span / context.targetCount(spacing));
    final double first = (context.min / step).ceilToDouble() * step;
    final List<ChartTick> ticks = <ChartTick>[];
    // Index-based to avoid accumulating floating point error.
    for (int i = 0; i < 1000; i++) {
      final double value = first + i * step;
      if (value > context.max + step * 1e-9) break;
      final double clean = (value / step).roundToDouble() * step;
      ticks.add(ChartTick(clean, format?.call(clean) ?? formatNumber(clean, step: step)));
    }
    return ticks;
  }

  @override
  bool operator ==(Object other) =>
      other is LinearTicks && other.spacing == spacing && other.format == format;

  @override
  int get hashCode => Object.hash(spacing, format);
}

/// Ticks at fixed values.
class FixedTicks extends ChartTicks {
  /// Creates ticks at [values].
  const FixedTicks(this.values, {this.format});

  /// The tick values.
  final List<double> values;

  /// Custom label formatter.
  final ChartValueFormatter? format;

  @override
  List<ChartTick> generate(ChartTickContext context) => <ChartTick>[
    for (final double v in values)
      if (v >= context.min && v <= context.max) ChartTick(v, format?.call(v) ?? formatNumber(v)),
  ];

  @override
  bool operator ==(Object other) =>
      other is FixedTicks && listEquals(other.values, values) && other.format == format;

  @override
  int get hashCode => Object.hash(Object.hashAll(values), format);
}

/// Ticks at powers of the base for a logarithmic scale.
class LogTicks extends ChartTicks {
  /// Creates logarithmic ticks.
  const LogTicks({this.base = 10, this.spacing, this.format});

  /// The logarithm base.
  final double base;

  /// Target distance between ticks, in logical pixels.
  final double? spacing;

  /// Custom label formatter.
  final ChartValueFormatter? format;

  @override
  List<ChartTick> generate(ChartTickContext context) {
    if (!(context.min > 0) || !(context.max > context.min)) return const <ChartTick>[];
    final int target = context.targetCount(spacing);
    final double logBase = math.log(base);
    final int lo = (math.log(context.min) / logBase).floor();
    final int hi = (math.log(context.max) / logBase).ceil();
    if (hi - lo > target) {
      // Many decades: label every n-th power, aligned to multiples of n.
      final int skip = ((hi - lo) / target).ceil();
      return <ChartTick>[
        for (int e = (lo / skip).ceil() * skip; e <= hi; e += skip)
          if (_contains(context, _value(1, e))) _tick(_value(1, e), 1),
      ];
    }
    // The finest set of mantissas that still fits: 1, then 1-2-5, then 1…9.
    final List<List<double>> sets = <List<double>>[
      const <double>[1],
      if (base == 10) const <double>[1, 2, 5],
      if (base == base.roundToDouble() && base > 2)
        <double>[for (int m = 1; m < base; m++) m.toDouble()],
    ];
    List<ChartTick> best = const <ChartTick>[];
    for (final List<double> mantissas in sets) {
      final List<ChartTick> ticks = <ChartTick>[
        for (int e = lo; e <= hi; e++)
          for (final double m in mantissas)
            if (_contains(context, _value(m, e))) _tick(_value(m, e), m == 1 ? 1 : 0),
      ];
      if (ticks.length > target) break;
      best = ticks;
    }
    // A window narrower than the decade structure: plain linear steps read better.
    if (best.length * 2 < target) {
      return LinearTicks(spacing: spacing, format: format).generate(context);
    }
    return best;
  }

  // m × baseᵉ; divides for negative exponents so 0.003 is the double nearest 0.003.
  double _value(double m, int e) =>
      e >= 0 ? m * math.pow(base, e).toDouble() : m / math.pow(base, -e).toDouble();

  static bool _contains(ChartTickContext context, double v) =>
      v >= context.min * (1 - 1e-12) && v <= context.max * (1 + 1e-12);

  ChartTick _tick(double v, int level) =>
      ChartTick(v, format?.call(v) ?? formatNumber(v, step: v), level: level);

  @override
  bool operator ==(Object other) =>
      other is LogTicks && other.base == base && other.spacing == spacing && other.format == format;

  @override
  int get hashCode => Object.hash(base, spacing, format);
}

/// Ticks at whole numbers, for band (category) scales.
class BandTicks extends ChartTicks {
  /// Creates band ticks. [labels] are looked up by index.
  const BandTicks({this.labels, this.spacing, this.format});

  /// Category names, indexed by band value.
  final List<String>? labels;

  /// Minimum distance between labelled bands, in logical pixels.
  final double? spacing;

  /// Custom label formatter, used when [labels] has no entry.
  final ChartValueFormatter? format;

  @override
  List<ChartTick> generate(ChartTickContext context) {
    final int lo = context.min.ceil();
    final int hi = context.max.floor();
    if (hi < lo) return const <ChartTick>[];
    final int count = hi - lo + 1;
    final int target = context.targetCount(spacing ?? 56);
    final int step = math.max(1, (count / target).ceil());
    final int first = (lo / step).ceil() * step;
    final List<ChartTick> ticks = <ChartTick>[];
    for (int i = first; i <= hi; i += step) {
      final List<String>? names = labels;
      final String label = names != null && i >= 0 && i < names.length
          ? names[i]
          : (format?.call(i.toDouble()) ?? '$i');
      ticks.add(ChartTick(i.toDouble(), label));
    }
    return ticks;
  }

  @override
  bool operator ==(Object other) =>
      other is BandTicks &&
      listEquals(other.labels, labels) &&
      other.spacing == spacing &&
      other.format == format;

  @override
  int get hashCode => Object.hash(labels == null ? null : Object.hashAll(labels!), spacing, format);
}

/// The calendar unit a [TimeTicks] step is expressed in.
enum ChartTimeUnit {
  /// Milliseconds.
  millisecond,

  /// Seconds.
  second,

  /// Minutes.
  minute,

  /// Hours.
  hour,

  /// Days.
  day,

  /// Months.
  month,

  /// Years.
  year,
}

/// Formats a tick on a time scale.
typedef ChartTimeFormatter = String Function(DateTime time, ChartTimeUnit unit, bool isBoundary);

/// Calendar-aware ticks for a time scale whose values are milliseconds since
/// the Unix epoch.
class TimeTicks extends ChartTicks {
  /// Creates time ticks.
  const TimeTicks({this.spacing, this.utc = false, this.format});

  /// Target distance between ticks, in logical pixels.
  final double? spacing;

  /// Whether ticks align to UTC instead of local time.
  final bool utc;

  /// Custom label formatter.
  final ChartTimeFormatter? format;

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  // (unit, count, approximate length in ms)
  static const List<(ChartTimeUnit, int, double)> _steps = <(ChartTimeUnit, int, double)>[
    (ChartTimeUnit.millisecond, 1, 1),
    (ChartTimeUnit.millisecond, 5, 5),
    (ChartTimeUnit.millisecond, 10, 10),
    (ChartTimeUnit.millisecond, 50, 50),
    (ChartTimeUnit.millisecond, 100, 100),
    (ChartTimeUnit.millisecond, 500, 500),
    (ChartTimeUnit.second, 1, 1e3),
    (ChartTimeUnit.second, 5, 5e3),
    (ChartTimeUnit.second, 15, 15e3),
    (ChartTimeUnit.second, 30, 30e3),
    (ChartTimeUnit.minute, 1, 60e3),
    (ChartTimeUnit.minute, 5, 300e3),
    (ChartTimeUnit.minute, 15, 900e3),
    (ChartTimeUnit.minute, 30, 1800e3),
    (ChartTimeUnit.hour, 1, 3600e3),
    (ChartTimeUnit.hour, 3, 10800e3),
    (ChartTimeUnit.hour, 6, 21600e3),
    (ChartTimeUnit.hour, 12, 43200e3),
    (ChartTimeUnit.day, 1, 86400e3),
    (ChartTimeUnit.day, 2, 172800e3),
    (ChartTimeUnit.day, 7, 604800e3),
    (ChartTimeUnit.day, 14, 1209600e3),
    (ChartTimeUnit.month, 1, 2629800e3),
    (ChartTimeUnit.month, 3, 7889400e3),
    (ChartTimeUnit.month, 6, 15778800e3),
    (ChartTimeUnit.year, 1, 31557600e3),
    (ChartTimeUnit.year, 2, 63115200e3),
    (ChartTimeUnit.year, 5, 157788000e3),
    (ChartTimeUnit.year, 10, 315576000e3),
    (ChartTimeUnit.year, 25, 788940000e3),
    (ChartTimeUnit.year, 100, 3155760000e3),
  ];

  DateTime _at(double ms) => DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: utc);

  DateTime _make(int y, [int mo = 1, int d = 1, int h = 0, int mi = 0, int s = 0, int ms = 0]) =>
      utc ? DateTime.utc(y, mo, d, h, mi, s, ms) : DateTime(y, mo, d, h, mi, s, ms);

  DateTime _floor(DateTime t, ChartTimeUnit unit, int n) {
    switch (unit) {
      case ChartTimeUnit.year:
        return _make(t.year - t.year % n);
      case ChartTimeUnit.month:
        return _make(t.year, t.month - (t.month - 1) % n);
      case ChartTimeUnit.day:
        // Align multi-day steps to the epoch so ticks do not shift while panning.
        final DateTime day = _make(t.year, t.month, t.day);
        if (n == 1) return day;
        final int index = (day.millisecondsSinceEpoch / 86400e3).round();
        return day.subtract(Duration(days: index % n));
      case ChartTimeUnit.hour:
        return _make(t.year, t.month, t.day, t.hour - t.hour % n);
      case ChartTimeUnit.minute:
        return _make(t.year, t.month, t.day, t.hour, t.minute - t.minute % n);
      case ChartTimeUnit.second:
        return _make(t.year, t.month, t.day, t.hour, t.minute, t.second - t.second % n);
      case ChartTimeUnit.millisecond:
        return _make(
          t.year,
          t.month,
          t.day,
          t.hour,
          t.minute,
          t.second, //
          t.millisecond - t.millisecond % n,
        );
    }
  }

  DateTime _advance(DateTime t, ChartTimeUnit unit, int n) {
    switch (unit) {
      case ChartTimeUnit.year:
        return _make(t.year + n);
      case ChartTimeUnit.month:
        return _make(t.year, t.month + n);
      case ChartTimeUnit.day:
        return _make(t.year, t.month, t.day + n);
      case ChartTimeUnit.hour:
        return t.add(Duration(hours: n));
      case ChartTimeUnit.minute:
        return t.add(Duration(minutes: n));
      case ChartTimeUnit.second:
        return t.add(Duration(seconds: n));
      case ChartTimeUnit.millisecond:
        return t.add(Duration(milliseconds: n));
    }
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';

  /// The default label for [t] at a step of [unit].
  static String defaultFormat(DateTime t, ChartTimeUnit unit, bool isBoundary) {
    switch (unit) {
      case ChartTimeUnit.year:
        return '${t.year}';
      case ChartTimeUnit.month:
        return isBoundary ? '${t.year}' : _months[t.month - 1];
      case ChartTimeUnit.day:
        return isBoundary
            ? '${_months[t.month - 1]} ${t.year}'
            : '${_months[t.month - 1]} ${t.day}';
      case ChartTimeUnit.hour:
      case ChartTimeUnit.minute:
        return isBoundary
            ? '${_months[t.month - 1]} ${t.day}'
            : '${_two(t.hour)}:${_two(t.minute)}';
      case ChartTimeUnit.second:
        return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
      case ChartTimeUnit.millisecond:
        return '${_two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    }
  }

  bool _isBoundary(DateTime t, ChartTimeUnit unit) {
    switch (unit) {
      case ChartTimeUnit.year:
        return false;
      case ChartTimeUnit.month:
        return t.month == 1;
      case ChartTimeUnit.day:
        return t.day == 1 && t.month == 1;
      case ChartTimeUnit.hour:
      case ChartTimeUnit.minute:
        return t.hour == 0 && t.minute == 0;
      case ChartTimeUnit.second:
      case ChartTimeUnit.millisecond:
        return false;
    }
  }

  @override
  List<ChartTick> generate(ChartTickContext context) {
    final double span = context.max - context.min;
    if (!(span > 0) || !span.isFinite) return const <ChartTick>[];
    final double rawStep = span / context.targetCount(spacing);
    (ChartTimeUnit, int, double) step = _steps.last;
    for (final (ChartTimeUnit, int, double) candidate in _steps) {
      if (candidate.$3 >= rawStep) {
        step = candidate;
        break;
      }
    }
    final ChartTimeUnit unit = step.$1;
    final int n = step.$2;
    final List<ChartTick> ticks = <ChartTick>[];
    DateTime t = _floor(_at(context.min), unit, n);
    for (int i = 0; i < 1000; i++) {
      final double value = t.millisecondsSinceEpoch.toDouble();
      if (value > context.max) break;
      if (value >= context.min) {
        final bool boundary = _isBoundary(t, unit);
        ticks.add(
          ChartTick(value, (format ?? defaultFormat)(t, unit, boundary), level: boundary ? 1 : 0),
        );
      }
      t = _advance(t, unit, n);
    }
    return ticks;
  }

  @override
  bool operator ==(Object other) =>
      other is TimeTicks && other.spacing == spacing && other.utc == utc && other.format == format;

  @override
  int get hashCode => Object.hash(spacing, utc, format);
}
