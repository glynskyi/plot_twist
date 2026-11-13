import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/range.dart';

/// Column-oriented storage for the data of one series: an x column plus one
/// or more value columns, held in typed arrays.
///
/// Keep a `ChartData` in your state (not in `build`) and mutate it: series
/// listen to it, so appending, prepending or evicting rows repaints the chart
/// and re-fits automatic ranges without rebuilding any widget.
///
/// Rows can be added at both ends cheaply. Use `double.nan` as a value to
/// leave a gap. Range queries are fast when x is sorted ascending, which is
/// tracked automatically ([isSorted]).
class ChartData extends ChangeNotifier {
  /// Creates an empty store with [valueColumns] value columns.
  ChartData({int valueColumns = 1, int capacity = 64})
    : assert(valueColumns >= 1),
      assert(capacity >= 0),
      _capacity = capacity,
      _columns = List<Float64List>.generate(valueColumns + 1, (_) => Float64List(capacity)),
      _indexes = List<_MinMaxIndex?>.filled(valueColumns, null);

  /// Creates a store from parallel lists of x and y values.
  factory ChartData.fromXY(List<double> x, List<double> y) =>
      ChartData(capacity: x.length)..addAll(x, y);

  /// Creates a store from y values spaced [step] apart, starting at [start].
  factory ChartData.fromValues(Iterable<double> values, {double start = 0, double step = 1}) {
    final List<double> ys = values.toList(growable: false);
    final ChartData data = ChartData(capacity: ys.length);
    data._reserve(back: ys.length);
    for (int i = 0; i < ys.length; i++) {
      data._columns[0][data._start + i] = start + i * step;
      data._columns[1][data._start + i] = ys[i];
    }
    data._appended(ys.length);
    return data;
  }

  /// Creates a store with [length] rows produced by [generator].
  factory ChartData.generate(int length, (double x, double y) Function(int index) generator) {
    final ChartData data = ChartData(capacity: length);
    data._reserve(back: length);
    for (int i = 0; i < length; i++) {
      final (double x, double y) = generator(i);
      data._columns[0][data._start + i] = x;
      data._columns[1][data._start + i] = y;
    }
    data._appended(length);
    return data;
  }

  /// Creates a store from app objects. [more] maps additional value columns.
  static ChartData from<T>(
    Iterable<T> items, {
    required double Function(T item) x,
    required double Function(T item) y,
    List<double Function(T item)> more = const <Never>[],
  }) {
    final List<T> list = items.toList(growable: false);
    final ChartData data = ChartData(valueColumns: 1 + more.length, capacity: list.length);
    data._reserve(back: list.length);
    for (int i = 0; i < list.length; i++) {
      final int row = data._start + i;
      data._columns[0][row] = x(list[i]);
      data._columns[1][row] = y(list[i]);
      for (int c = 0; c < more.length; c++) {
        data._columns[c + 2][row] = more[c](list[i]);
      }
    }
    data._appended(list.length);
    return data;
  }

  /// Stacks [layers], which must share their x values, on top of each other.
  ///
  /// Returns one store per layer with two value columns: column 0 is the top
  /// of the layer and column 1 its bottom — ready for a bar series with
  /// `baseColumn: 1`, or an area between two lines.
  static List<ChartData> stacked(List<ChartData> layers) {
    final List<ChartData> result = <ChartData>[];
    List<double>? running;
    for (final ChartData layer in layers) {
      final int n = layer.length;
      final List<double> base = running ?? List<double>.filled(n, 0);
      assert(base.length == n, 'Stacked layers must have the same number of rows');
      final List<double> top = List<double>.generate(n, (int i) {
        final double v = layer.y(i);
        return base[i] + (v.isNaN ? 0 : v);
      });
      result.add(
        ChartData(valueColumns: 2, capacity: n)
          ..addRows(List<double>.generate(n, layer.x), <List<double>>[top, base]),
      );
      running = top;
    }
    return result;
  }

  final List<Float64List> _columns;
  final List<_MinMaxIndex?> _indexes;
  int _capacity;
  int _start = 0;
  int _length = 0;
  int _firstOrdinal = 0;
  int _revision = 0;
  bool _sorted = true;

  /// Number of rows.
  int get length => _length;

  /// Whether there are no rows.
  bool get isEmpty => _length == 0;

  /// Whether there is at least one row.
  bool get isNotEmpty => _length != 0;

  /// Number of value columns.
  int get valueColumns => _columns.length - 1;

  /// Increases with every mutation.
  int get revision => _revision;

  /// Whether x values are in ascending order.
  bool get isSorted => _sorted;

  /// A stable number for the first row: prepending rows lowers it, so
  /// `firstOrdinal + index` identifies a row across prepends.
  int get firstOrdinal => _firstOrdinal;

  /// The x value of row [index].
  double x(int index) => _columns[0][_start + index];

  /// The first value of row [index].
  double y(int index) => _columns[1][_start + index];

  /// The value in [column] of row [index].
  double value(int index, [int column = 0]) => _columns[column + 1][_start + index];

  // ------------------------------------------------------------ mutation

  void _reserve({int front = 0, int back = 0}) {
    final bool needFront = front > _start;
    final bool needBack = _start + _length + back > _capacity;
    if (!needFront && !needBack) return;
    final int head = needFront ? math.max(front, _length ~/ 2) : _start;
    final int tail = needBack ? math.max(back, _length ~/ 2 + 16) : _capacity - _start - _length;
    final int capacity = head + _length + tail;
    for (int c = 0; c < _columns.length; c++) {
      final Float64List next = Float64List(capacity);
      next.setRange(head, head + _length, _columns[c], _start);
      _columns[c] = next;
    }
    _start = head;
    _capacity = capacity;
  }

  void _appended(int count) {
    final Float64List xs = _columns[0];
    int from = _start + _length;
    if (_sorted) {
      double previous = _length > 0 ? xs[from - 1] : double.negativeInfinity;
      for (int i = from; i < from + count; i++) {
        if (xs[i] < previous) {
          _sorted = false;
          break;
        }
        previous = xs[i];
      }
    }
    for (int c = 0; c < _indexes.length; c++) {
      final _MinMaxIndex? index = _indexes[c];
      if (index == null) continue;
      final Float64List column = _columns[c + 1];
      for (int i = from; i < from + count; i++) {
        index.append(column[i]);
      }
    }
    from += count;
    _length += count;
  }

  void _changed({bool invalidateIndexes = false}) {
    if (invalidateIndexes) {
      for (int c = 0; c < _indexes.length; c++) {
        _indexes[c] = null;
      }
    }
    _revision++;
    notifyListeners();
  }

  /// Appends a row with one value.
  void add(double x, double y) {
    assert(valueColumns == 1, 'Use addRow for stores with several value columns');
    _reserve(back: 1);
    final int row = _start + _length;
    _columns[0][row] = x;
    _columns[1][row] = y;
    _appended(1);
    _changed();
  }

  /// Appends a row with one value per value column.
  void addRow(double x, List<double> values) {
    assert(values.length == valueColumns);
    _reserve(back: 1);
    final int row = _start + _length;
    _columns[0][row] = x;
    for (int c = 0; c < values.length; c++) {
      _columns[c + 1][row] = values[c];
    }
    _appended(1);
    _changed();
  }

  /// Appends rows from parallel lists.
  void addAll(List<double> xs, List<double> ys) => addRows(xs, <List<double>>[ys]);

  /// Appends rows from an x list and one list per value column.
  void addRows(List<double> xs, List<List<double>> values) {
    assert(values.length == valueColumns);
    final int count = xs.length;
    if (count == 0) return;
    _reserve(back: count);
    final int row = _start + _length;
    _columns[0].setRange(row, row + count, xs);
    for (int c = 0; c < values.length; c++) {
      assert(values[c].length == count);
      _columns[c + 1].setRange(row, row + count, values[c]);
    }
    _appended(count);
    _changed();
  }

  /// Inserts rows before the first row. The visible window of a chart does
  /// not move, because it is kept in data space.
  void prependAll(List<double> xs, List<double> ys) => prependRows(xs, <List<double>>[ys]);

  /// Inserts rows, given as an x list and one list per value column, before
  /// the first row.
  void prependRows(List<double> xs, List<List<double>> values) {
    assert(values.length == valueColumns);
    final int count = xs.length;
    if (count == 0) return;
    _reserve(front: count);
    final int row = _start - count;
    _columns[0].setRange(row, row + count, xs);
    for (int c = 0; c < values.length; c++) {
      assert(values[c].length == count);
      _columns[c + 1].setRange(row, row + count, values[c]);
    }
    if (_sorted) {
      final Float64List column = _columns[0];
      final int end = _length > 0 ? row + count : row + count - 1;
      for (int i = row; i < end; i++) {
        if (column[i + 1] < column[i]) {
          _sorted = false;
          break;
        }
      }
    }
    _start = row;
    _length += count;
    _firstOrdinal -= count;
    _changed(invalidateIndexes: true);
  }

  /// Removes the first [count] rows.
  void removeFirst(int count) {
    final int n = math.min(count, _length);
    if (n <= 0) return;
    _start += n;
    _length -= n;
    _firstOrdinal += n;
    if (_length == 0) _sorted = true;
    _changed(invalidateIndexes: true);
  }

  /// Removes the last [count] rows.
  void removeLast(int count) {
    final int n = math.min(count, _length);
    if (n <= 0) return;
    _length -= n;
    if (_length == 0) _sorted = true;
    _changed(invalidateIndexes: true);
  }

  /// Changes one value in place — for example the still-forming last point.
  void setValue(int index, double value, {int column = 0}) {
    RangeError.checkValidIndex(index, this, 'index', _length);
    _columns[column + 1][_start + index] = value;
    _changed(invalidateIndexes: true);
  }

  /// Removes all rows.
  void clear() {
    if (_length == 0) return;
    _start = 0;
    _length = 0;
    _sorted = true;
    _changed(invalidateIndexes: true);
  }

  /// Replaces all rows.
  void replaceAll(List<double> xs, List<double> ys) => replaceRows(xs, <List<double>>[ys]);

  /// Replaces all rows, given an x list and one list per value column.
  void replaceRows(List<double> xs, List<List<double>> values) {
    assert(values.length == valueColumns);
    _start = 0;
    _length = 0;
    _sorted = true;
    for (int c = 0; c < _indexes.length; c++) {
      _indexes[c] = null;
    }
    final int count = xs.length;
    _reserve(back: count);
    _columns[0].setRange(_start, _start + count, xs);
    for (int c = 0; c < values.length; c++) {
      assert(values[c].length == count);
      _columns[c + 1].setRange(_start, _start + count, values[c]);
    }
    _appended(count);
    _changed();
  }

  // ------------------------------------------------------------- queries

  /// The index of the first row whose x is `>= x`. Requires sorted x.
  int lowerBound(double x) {
    final Float64List xs = _columns[0];
    int lo = 0;
    int hi = _length;
    while (lo < hi) {
      final int mid = (lo + hi) >> 1;
      if (xs[_start + mid] < x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// The index of the first row whose x is `> x`. Requires sorted x.
  int upperBound(double x) {
    final Float64List xs = _columns[0];
    int lo = 0;
    int hi = _length;
    while (lo < hi) {
      final int mid = (lo + hi) >> 1;
      if (xs[_start + mid] <= x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// The half-open row range `[start, end)` that can be seen in `[min, max]`,
  /// widened by [overscan] rows on each side so lines reach the plot edges.
  ///
  /// For unsorted data this is all rows.
  (int start, int end) indexRange(double min, double max, {int overscan = 1}) {
    if (!_sorted) return (0, _length);
    final int start = math.max(0, lowerBound(min) - overscan);
    final int end = math.min(_length, upperBound(max) + overscan);
    return (start, math.max(start, end));
  }

  /// The index of the row whose x is closest to [x], or -1 if empty.
  int nearestIndex(double x) {
    if (_length == 0) return -1;
    if (!_sorted) {
      int best = 0;
      double bestDistance = double.infinity;
      for (int i = 0; i < _length; i++) {
        final double d = (this.x(i) - x).abs();
        if (d < bestDistance) {
          bestDistance = d;
          best = i;
        }
      }
      return best;
    }
    final int i = lowerBound(x);
    if (i <= 0) return 0;
    if (i >= _length) return _length - 1;
    return (x - this.x(i - 1)) <= (this.x(i) - x) ? i - 1 : i;
  }

  /// The extent of the x column, or null if empty.
  ChartRange? get xExtent {
    if (_length == 0) return null;
    if (_sorted) return ChartRange(x(0), x(_length - 1));
    double lo = double.infinity;
    double hi = double.negativeInfinity;
    for (int i = 0; i < _length; i++) {
      final double v = x(i);
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return lo <= hi ? ChartRange(lo, hi) : null;
  }

  /// The smallest and largest value of [column] in rows `[start, end)`, or
  /// null when there is no finite value there.
  ///
  /// Large stores answer this from a min/max index instead of scanning rows.
  ChartRange? valueExtent({int column = 0, int start = 0, int? end}) {
    final (double lo, double hi) = minMax(start, end ?? _length, column: column);
    return lo <= hi ? ChartRange(lo, hi) : null;
  }

  /// Like [valueExtent] but returns `(infinity, -infinity)` when empty.
  (double min, double max) minMax(int start, int end, {int column = 0}) {
    final int s = math.max(0, start);
    final int e = math.min(_length, end);
    if (e <= s) return (double.infinity, double.negativeInfinity);
    final Float64List values = _columns[column + 1];
    if (e - s >= _MinMaxIndex.threshold) {
      final _MinMaxIndex index = _indexes[column] ??= _MinMaxIndex.build(values, _start, _length);
      return index.query(values, _start, s, e);
    }
    double lo = double.infinity;
    double hi = double.negativeInfinity;
    for (int i = _start + s; i < _start + e; i++) {
      final double v = values[i];
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return (lo, hi);
  }

  /// The row indices of the smallest and largest value of [column] in rows
  /// `[start, end)`, or `(-1, -1)` when there is no finite value there.
  (int minIndex, int maxIndex) argMinMax(int start, int end, {int column = 0}) {
    final int s = math.max(0, start);
    final int e = math.min(_length, end);
    if (e <= s) return (-1, -1);
    final Float64List values = _columns[column + 1];
    if (e - s >= _MinMaxIndex.threshold) {
      final _MinMaxIndex index = _indexes[column] ??= _MinMaxIndex.build(values, _start, _length);
      return index.argQuery(values, _start, s, e);
    }
    return _scanArg(values, _start, s, e);
  }

  static (int, int) _scanArg(Float64List values, int base, int s, int e) {
    double lo = double.infinity;
    double hi = double.negativeInfinity;
    int minIndex = -1;
    int maxIndex = -1;
    for (int i = s; i < e; i++) {
      final double v = values[base + i];
      if (v < lo) {
        lo = v;
        minIndex = i;
      }
      if (v > hi) {
        hi = v;
        maxIndex = i;
      }
    }
    return (minIndex, maxIndex);
  }

  /// The value of [column] at [x], linearly interpolated between the
  /// neighbouring rows. Null outside the data or next to a gap. Requires
  /// sorted x.
  double? interpolate(double x, {int column = 0}) {
    if (_length == 0 || !_sorted) return null;
    final int hi = lowerBound(x);
    if (hi >= _length) return null;
    final double x1 = this.x(hi);
    final double y1 = value(hi, column);
    if (x1 == x) return y1.isNaN ? null : y1;
    if (hi == 0) return null;
    final double x0 = this.x(hi - 1);
    final double y0 = value(hi - 1, column);
    if (y0.isNaN || y1.isNaN || x1 == x0) return null;
    return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
  }
}

// A two-level block index over one value column: level 0 holds the min/max of
// every 64 rows, level 1 of every 64 level-0 blocks. NaN values are ignored.
class _MinMaxIndex {
  _MinMaxIndex._(int blocks0)
    : _min0 = Float64List(blocks0),
      _max0 = Float64List(blocks0),
      _min1 = Float64List(blocks0 ~/ _b1 + 1),
      _max1 = Float64List(blocks0 ~/ _b1 + 1);

  factory _MinMaxIndex.build(Float64List column, int start, int length) {
    final _MinMaxIndex index = _MinMaxIndex._(length ~/ _b0 + 2);
    for (int i = start; i < start + length; i++) {
      index.append(column[i]);
    }
    return index;
  }

  static const int _b0 = 64;
  static const int _b1 = 64;

  /// Ranges shorter than this are scanned directly.
  static const int threshold = 2048;

  Float64List _min0;
  Float64List _max0;
  Float64List _min1;
  Float64List _max1;
  int _rows = 0;

  void append(double v) {
    final int block = _rows ~/ _b0;
    if (block >= _min0.length) {
      final int size = _min0.length * 2;
      _min0 = Float64List(size)..setRange(0, _min0.length, _min0);
      _max0 = Float64List(size)..setRange(0, _max0.length, _max0);
    }
    final int big = block ~/ _b1;
    if (big >= _min1.length) {
      final int size = _min1.length * 2;
      _min1 = Float64List(size)..setRange(0, _min1.length, _min1);
      _max1 = Float64List(size)..setRange(0, _max1.length, _max1);
    }
    if (_rows % _b0 == 0) {
      _min0[block] = double.infinity;
      _max0[block] = double.negativeInfinity;
      if (block % _b1 == 0) {
        _min1[big] = double.infinity;
        _max1[big] = double.negativeInfinity;
      }
    }
    if (v < _min0[block]) _min0[block] = v;
    if (v > _max0[block]) _max0[block] = v;
    if (v < _min1[big]) _min1[big] = v;
    if (v > _max1[big]) _max1[big] = v;
    _rows++;
  }

  // Like [query], but returns the row indices of the extremes. Finds the
  // block holding each extreme, then scans only that block.
  (int, int) argQuery(Float64List column, int base, int start, int end) {
    final (double lo, double hi) = query(column, base, start, end);
    if (lo > hi) return (-1, -1);
    int find(double target, Float64List level0, Float64List level1) {
      int i = start;
      final int headEnd = math.min(end, ((start + _b0 - 1) ~/ _b0) * _b0);
      for (; i < headEnd; i++) {
        if (column[base + i] == target) return i;
      }
      if (i < end) {
        int block = i ~/ _b0;
        final int endBlock = end ~/ _b0;
        int scanBlock(int b) {
          for (int r = b * _b0; r < (b + 1) * _b0; r++) {
            if (column[base + r] == target) return r;
          }
          return -1;
        }

        if (block < endBlock) {
          final int bigHeadEnd = math.min(endBlock, ((block + _b1 - 1) ~/ _b1) * _b1);
          for (; block < bigHeadEnd; block++) {
            if (level0[block] == target) return scanBlock(block);
          }
          final int endBig = endBlock ~/ _b1;
          int big = block ~/ _b1;
          for (; big < endBig; big++) {
            if (level1[big] == target) {
              for (int b = big * _b1; b < (big + 1) * _b1; b++) {
                if (level0[b] == target) return scanBlock(b);
              }
            }
          }
          if (big * _b1 > block) block = big * _b1;
          for (; block < endBlock; block++) {
            if (level0[block] == target) return scanBlock(block);
          }
          i = endBlock * _b0;
        }
        for (; i < end; i++) {
          if (column[base + i] == target) return i;
        }
      }
      return -1;
    }

    return (find(lo, _min0, _min1), find(hi, _max0, _max1));
  }

  (double, double) query(Float64List column, int base, int start, int end) {
    assert(end <= _rows);
    double lo = double.infinity;
    double hi = double.negativeInfinity;
    int i = start;
    final int headEnd = math.min(end, ((start + _b0 - 1) ~/ _b0) * _b0);
    for (; i < headEnd; i++) {
      final double v = column[base + i];
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (i < end) {
      int block = i ~/ _b0;
      final int endBlock = end ~/ _b0;
      if (block < endBlock) {
        final int bigHeadEnd = math.min(endBlock, ((block + _b1 - 1) ~/ _b1) * _b1);
        for (; block < bigHeadEnd; block++) {
          if (_min0[block] < lo) lo = _min0[block];
          if (_max0[block] > hi) hi = _max0[block];
        }
        final int endBig = endBlock ~/ _b1;
        int big = block ~/ _b1;
        for (; big < endBig; big++) {
          if (_min1[big] < lo) lo = _min1[big];
          if (_max1[big] > hi) hi = _max1[big];
        }
        if (big * _b1 > block) block = big * _b1;
        for (; block < endBlock; block++) {
          if (_min0[block] < lo) lo = _min0[block];
          if (_max0[block] > hi) hi = _max0[block];
        }
        i = endBlock * _b0;
      }
      for (; i < end; i++) {
        final double v = column[base + i];
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    return (lo, hi);
  }
}
