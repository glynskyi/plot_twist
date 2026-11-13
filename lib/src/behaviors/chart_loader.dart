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

  @override
  State<ChartLoader> createState() => _ChartLoaderState();
}

class _ChartLoaderState extends State<ChartLoader> {
  ChartScaleController? _scale;
  bool _loadingBefore = false;
  bool _loadingAfter = false;
  bool _doneBefore = false;
  bool _doneAfter = false;

  @override
  void initState() {
    super.initState();
    widget.data.addListener(_check);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ChartScaleController scale = ChartScope.of(context).controller.scale(widget.xScale);
    if (!identical(scale, _scale)) {
      _scale?.removeListener(_check);
      _scale = scale..addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _check());
  }

  @override
  void didUpdateWidget(ChartLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      oldWidget.data.removeListener(_check);
      widget.data.addListener(_check);
      _doneBefore = false;
      _doneAfter = false;
    }
  }

  @override
  void dispose() {
    _scale?.removeListener(_check);
    widget.data.removeListener(_check);
    super.dispose();
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
        (loaded == null || window.min < loaded.min + margin)) {
      _loadingBefore = true;
      _announce();
      unawaited(
        before().then((bool more) {
          _loadingBefore = false;
          _doneBefore = !more;
          _announce();
          _check();
        }),
      );
    }
    final Future<bool> Function()? after = widget.onLoadAfter;
    if (after != null &&
        !_loadingAfter &&
        !_doneAfter &&
        (loaded == null || window.max > loaded.max - margin)) {
      _loadingAfter = true;
      _announce();
      unawaited(
        after().then((bool more) {
          _loadingAfter = false;
          _doneAfter = !more;
          _announce();
          _check();
        }),
      );
    }
  }

  void _announce() {
    if (mounted) widget.onLoadingChanged?.call(_loadingBefore || _loadingAfter);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
