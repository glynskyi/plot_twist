import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Loads more data when the user scrolls towards the edge of what is loaded.
///
/// Add it to `Chart.children`. Whenever the visible window comes within
/// [prefetch] window-widths of the first or last loaded x value of [data],
/// [onLoadBefore] or [onLoadAfter] is called — once at a time per side. Add
/// the new rows to [data] (`prependAll` / `addAll`) and complete the future
/// with `false` when that side has nothing more to load.
///
/// A load that fails is reported to [onError]. That side is asked again when
/// the visible window or the data next changes, and so is a side that said
/// there was more but added no rows.
///
/// Loading never blocks scrolling: the window lives in data space, so the
/// user can keep panning into the part that is still on its way, and rows
/// that arrive do not move what is on screen.
class ChartLoader extends StatefulWidget {
  /// Creates a loader for [data].
  const ChartLoader({
    super.key,
    required this.data,
    this.onLoadBefore,
    this.onLoadAfter,
    this.prefetch = 0.5,
    this.xScale = kChartX,
    this.onLoadingChanged,
    this.onError,
  });

  /// The store whose x extent is "what is loaded".
  final ChartData data;

  /// Loads rows before the first loaded row. Complete with false when there
  /// are none left.
  final Future<bool> Function()? onLoadBefore;

  /// Loads rows after the last loaded row. Complete with false when there are
  /// none left.
  final Future<bool> Function()? onLoadAfter;

  /// How early to load, as a fraction of the visible window's width.
  final double prefetch;

  /// Id of the scale whose window triggers loading.
  final Object xScale;

  /// Called when a load starts or finishes, with whether any is running.
  final ValueChanged<bool>? onLoadingChanged;

  /// Called when a load fails: its future completes with an error, or the
  /// callback throws. Without it the error is reported through
  /// [FlutterError.reportError].
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<ChartLoader> createState() => _ChartLoaderState();
}

class _ChartLoaderState extends State<ChartLoader> {
  ChartScaleController? _scale;
  bool _loadingBefore = false;
  bool _loadingAfter = false;
  bool _doneBefore = false;
  bool _doneAfter = false;
  // A side whose last load failed, or added nothing although it said there
  // was more. It waits until the window or the data changes.
  bool _stalledBefore = false;
  bool _stalledAfter = false;

  @override
  void initState() {
    super.initState();
    widget.data.addListener(_handleChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScale();
  }

  @override
  void didUpdateWidget(ChartLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      oldWidget.data.removeListener(_handleChange);
      widget.data.addListener(_handleChange);
      _doneBefore = false;
      _doneAfter = false;
      _stalledBefore = false;
      _stalledAfter = false;
    }
    if (oldWidget.xScale != widget.xScale) _attachScale();
  }

  @override
  void dispose() {
    _scale?.removeListener(_handleChange);
    widget.data.removeListener(_handleChange);
    super.dispose();
  }

  // Listens to the scale named by the widget, and looks at it once the frame
  // is done: a load must not start while widgets are being built.
  void _attachScale() {
    final ChartScaleController scale = ChartScope.of(context).controller.scale(widget.xScale);
    if (!identical(scale, _scale)) {
      _scale?.removeListener(_handleChange);
      _scale = scale..addListener(_handleChange);
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _check());
  }

  // The window or the data changed: a side that was waiting may try again.
  void _handleChange() {
    _stalledBefore = false;
    _stalledAfter = false;
    _check();
  }

  void _check() {
    final ChartScaleController? scale = _scale;
    if (!mounted || scale == null) return;
    final ChartRange window = scale.range;
    final ChartRange? loaded = widget.data.xExtent;
    final double margin = window.span * widget.prefetch;
    final Future<bool> Function()? before = widget.onLoadBefore;
    if (before != null &&
        !_loadingBefore &&
        !_doneBefore &&
        !_stalledBefore &&
        (loaded == null || window.min < loaded.min + margin)) {
      _load(before, before: true);
    }
    final Future<bool> Function()? after = widget.onLoadAfter;
    if (after != null &&
        !_loadingAfter &&
        !_doneAfter &&
        !_stalledAfter &&
        (loaded == null || window.max > loaded.max - margin)) {
      _load(after, before: false);
    }
  }

  void _load(Future<bool> Function() callback, {required bool before}) {
    final ChartData data = widget.data;
    double? edge() => before ? data.xExtent?.min : data.xExtent?.max;
    final double? edgeBefore = edge();
    if (before) {
      _loadingBefore = true;
    } else {
      _loadingAfter = true;
    }
    _announce();

    void finish({required bool more, Object? error, StackTrace? stackTrace}) {
      if (!mounted) return;
      // A load for a store the widget no longer shows says nothing about the
      // new one.
      final bool current = identical(data, widget.data);
      final bool failed = error != null;
      final bool stalled = current && (failed || (more && edge() == edgeBefore));
      if (before) {
        _loadingBefore = false;
        if (current) _doneBefore = !failed && !more;
        _stalledBefore = stalled;
      } else {
        _loadingAfter = false;
        if (current) _doneAfter = !failed && !more;
        _stalledAfter = stalled;
      }
      _announce();
      if (error != null) _report(error, stackTrace ?? StackTrace.current);
      _check();
    }

    final Future<bool> result;
    try {
      result = callback();
    } catch (error, stackTrace) {
      finish(more: false, error: error, stackTrace: stackTrace);
      return;
    }
    unawaited(
      result.then(
        (bool more) => finish(more: more),
        onError: (Object error, StackTrace stackTrace) =>
            finish(more: false, error: error, stackTrace: stackTrace),
      ),
    );
  }

  void _report(Object error, StackTrace stackTrace) {
    final void Function(Object error, StackTrace stackTrace)? handler = widget.onError;
    if (handler != null) {
      handler(error, stackTrace);
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'plot_twist',
        context: ErrorDescription('while a ChartLoader was loading more data'),
      ),
    );
  }

  void _announce() {
    if (mounted) widget.onLoadingChanged?.call(_loadingBefore || _loadingAfter);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
