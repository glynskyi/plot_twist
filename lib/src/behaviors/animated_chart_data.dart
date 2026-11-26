import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Animates between data sets.
///
/// Give it the [data] you want to show and build your series from the store
/// passed to [builder]. Whenever [data] is replaced or mutated, the built
/// store morphs from what it showed to the new values: matching rows move,
/// new rows grow from [baseline], surplus rows shrink away.
///
/// Because the series listen to the animated store, each frame only repaints
/// the series (and re-fits automatic ranges) — no widget is rebuilt. This
/// works with any series, including your own painters.
class AnimatedChartData extends StatefulWidget {
  /// Creates a data transition.
  const AnimatedChartData({
    super.key,
    required this.data,
    required this.builder,
    this.duration = const Duration(milliseconds: 450),
    this.curve = Curves.easeInOutCubic,
    this.baseline = 0,
    this.animateOnMount = true,
  });

  /// The data to show.
  final ChartData data;

  /// Builds the series from the animated store.
  final Widget Function(BuildContext context, ChartData animated) builder;

  /// Length of a transition.
  final Duration duration;

  /// Easing of a transition.
  final Curve curve;

  /// The value rows grow from and shrink to.
  final double baseline;

  /// Whether the first data set grows in from [baseline].
  ///
  /// Like every transition of this widget, it is skipped when the platform
  /// asks for reduced motion (`MediaQuery.disableAnimations`).
  final bool animateOnMount;

  @override
  State<AnimatedChartData> createState() => _AnimatedChartDataState();
}

class _Snapshot {
  _Snapshot(ChartData data)
    : xs = List<double>.generate(data.length, data.x),
      columns = <List<double>>[
        for (int c = 0; c < data.valueColumns; c++)
          List<double>.generate(data.length, (int i) => data.value(i, c)),
      ];

  _Snapshot.empty(int columns)
    : xs = const <double>[],
      columns = List<List<double>>.filled(columns, const <double>[]);

  final List<double> xs;
  final List<List<double>> columns;

  int get length => xs.length;
}

class _AnimatedChartDataState extends State<AnimatedChartData> with SingleTickerProviderStateMixin {
  // Created for the first transition, so a chart that never animates (reduced
  // motion, or data that never changes) never creates a ticker.
  AnimationController? _controller;
  AnimationController get _animation =>
      _controller ??= AnimationController(vsync: this)..addListener(_tick);
  late ChartData _shown;
  late _Snapshot _from;
  late _Snapshot _to;

  @override
  void initState() {
    super.initState();
    _shown = ChartData(valueColumns: widget.data.valueColumns);
    _from = _Snapshot.empty(widget.data.valueColumns);
    _to = _Snapshot(widget.data);
    widget.data.addListener(_retarget);
  }

  bool _mounted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mounted) return;
    _mounted = true;
    // The first show. It waits for this method, the first place where the
    // reduce-motion setting can be read.
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animateOnMount && !reduceMotion && widget.duration > Duration.zero) {
      _animation.duration = widget.duration;
      _write(0);
      _animation.forward(from: 0);
    } else {
      _write(1);
    }
  }

  @override
  void didUpdateWidget(AnimatedChartData oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      oldWidget.data.removeListener(_retarget);
      widget.data.addListener(_retarget);
      _retarget();
    }
  }

  @override
  void dispose() {
    widget.data.removeListener(_retarget);
    _controller?.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _retarget() {
    if (!mounted) return;
    if (widget.data.valueColumns != _shown.valueColumns) {
      _shown.dispose();
      setState(() => _shown = ChartData(valueColumns: widget.data.valueColumns));
      _from = _Snapshot.empty(widget.data.valueColumns);
    } else {
      _from = _Snapshot(_shown);
    }
    _to = _Snapshot(widget.data);
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || widget.duration == Duration.zero) {
      _controller?.stop();
      _write(1);
      return;
    }
    _animation.duration = widget.duration;
    _animation.forward(from: 0);
  }

  void _tick() => _write(widget.curve.transform(_animation.value));

  void _write(double t) {
    final int count = t >= 1 ? _to.length : math.max(_from.length, _to.length);
    final List<double> xs = List<double>.filled(count, 0);
    final List<List<double>> columns = <List<double>>[
      for (int c = 0; c < _to.columns.length; c++) List<double>.filled(count, 0),
    ];
    for (int i = 0; i < count; i++) {
      final bool inFrom = i < _from.length;
      final bool inTo = i < _to.length;
      xs[i] = inFrom && inTo
          ? lerpDouble(_from.xs[i], _to.xs[i], t)!
          : (inTo ? _to.xs[i] : _from.xs[i]);
      for (int c = 0; c < columns.length; c++) {
        final double a = inFrom ? _from.columns[c][i] : widget.baseline;
        final double b = inTo ? _to.columns[c][i] : widget.baseline;
        columns[c][i] = (a.isNaN || b.isNaN) ? b : lerpDouble(a, b, t)!;
      }
    }
    _shown.replaceRows(xs, columns);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _shown);
}
