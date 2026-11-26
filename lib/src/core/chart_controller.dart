import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'chart_view.dart';
import 'range.dart';
import 'scale.dart';
import 'scale_controller.dart';
import 'series.dart';

/// The data position a user is pointing at — what a crosshair shows.
///
/// It is kept in data space, so it survives panning, zooming and data updates,
/// and can be shared between linked charts.
@immutable
class ChartFocus {
  /// Creates a focus at data value [x], optionally with a [y].
  const ChartFocus({required this.x, this.y, this.mode = ChartHitMode.nearestX, this.source});

  /// Position on the x scale, in data units.
  final double x;

  /// Position on the y scale of the chart that produced the focus, if known.
  final double? y;

  /// Which data points the focus stands for: those at [x], those at [y], or
  /// the ones at exactly this position. See `ChartController.hitsFor`.
  final ChartHitMode mode;

  /// The controller of the chart the pointer is in. Linked charts use this to
  /// tell their own focus from a mirrored one.
  final Object? source;

  @override
  bool operator ==(Object other) =>
      other is ChartFocus &&
      other.x == x &&
      other.y == y &&
      other.mode == mode &&
      identical(other.source, source);

  @override
  int get hashCode => Object.hash(x, y, mode, source);

  @override
  String toString() => 'ChartFocus($x, $y, ${mode.name})';
}

// Series come and go with the widget lifecycle, so their listeners (which may
// call setState) are always told right after the frame.
class _DeferredNotifier extends ChangeNotifier {
  bool _scheduled = false;
  bool _disposed = false;

  void notify() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The handle to a chart's state: its scales, its series and what the user is
/// pointing at.
///
/// A `Chart` creates one automatically. Create your own and pass it to the
/// chart when you need to read or drive the chart from outside — to react to
/// the visible range, zoom programmatically, build a legend or link charts.
///
/// To link charts, give their controllers the same [ChartScaleController]
/// (shared panning and zooming) and the same [focus] notifier (shared
/// crosshair).
class ChartController {
  /// Creates a controller, optionally reusing scale controllers and a focus
  /// notifier owned by someone else.
  ChartController({
    ChartScaleController? x,
    ChartScaleController? y,
    Map<Object, ChartScaleController> scales = const <Object, ChartScaleController>{},
    ValueNotifier<ChartFocus?>? focus,
  }) : focus = focus ?? ValueNotifier<ChartFocus?>(null),
       _ownsFocus = focus == null {
    if (x != null) _adopt(kChartX, x, owned: false);
    if (y != null) _adopt(kChartY, y, owned: false);
    scales.forEach((Object id, ChartScaleController c) => _adopt(id, c, owned: false));
  }

  final Map<Object, ChartScaleController> _scales = <Object, ChartScaleController>{};
  final Map<ChartScaleController, VoidCallback> _scaleListeners =
      <ChartScaleController, VoidCallback>{};
  final Set<ChartScaleController> _owned = <ChartScaleController>{};
  final List<ChartSeries> _series = <ChartSeries>[];
  final _DeferredNotifier _seriesNotifier = _DeferredNotifier();
  final List<VoidCallback> _renderListeners = <VoidCallback>[];
  final List<TickerProvider> _vsyncs = <TickerProvider>[];
  final bool _ownsFocus;
  ChartView? _view;
  bool _propagating = false;
  bool _seriesOrderDirty = false;
  int _revision = 0;
  bool _disposed = false;

  /// What the user is pointing at, in data space. Null when nothing is.
  final ValueNotifier<ChartFocus?> focus;

  /// The default horizontal scale.
  ChartScaleController get x => scale(kChartX);

  /// The default vertical scale.
  ChartScaleController get y => scale(kChartY);

  /// The controller of the scale registered under [id], created on demand.
  ChartScaleController scale(Object id) =>
      _scales[id] ?? _adopt(id, ChartScaleController(), owned: true);

  /// Ids of all scales this controller knows about.
  Iterable<Object> get scaleIds => _scales.keys;

  ChartScaleController _adopt(Object id, ChartScaleController controller, {required bool owned}) {
    assert(!_scales.containsKey(id));
    _scales[id] = controller;
    if (owned) _owned.add(controller);
    void listener() => _onScaleChanged(controller);
    _scaleListeners[controller] = listener;
    controller.addRenderListener(listener);
    controller.addSource(_extentFor);
    for (final TickerProvider vsync in _vsyncs) {
      controller.attachVsync(vsync);
    }
    return controller;
  }

  // The extent of the series on [controller]'s scale. With [visibleOnly],
  // only what the other scale of each series shows counts; with [within],
  // only data inside that range of this scale does.
  ChartRange? _extentFor(
    ChartScaleController controller, {
    required bool visibleOnly,
    ChartRange? within,
  }) {
    ChartRange? result;
    for (final ChartSeries series in _series) {
      final ChartScaleController xs = scale(series.xScale);
      final ChartScaleController ys = scale(series.yScale);
      if (identical(ys, controller)) {
        result = ChartRange.merge(
          result,
          series.bounds(xWindow: visibleOnly ? xs.range : null, yWindow: within)?.y,
        );
      }
      if (identical(xs, controller)) {
        result = ChartRange.merge(
          result,
          series.bounds(xWindow: within, yWindow: visibleOnly ? ys.range : null)?.x,
        );
      }
    }
    return result;
  }

  void _onScaleChanged(ChartScaleController source) {
    if (_disposed) return;
    if (!_propagating) {
      // A scale that fits visible data must be recomputed when another scale
      // of the same chart moves.
      _propagating = true;
      try {
        for (final ChartScaleController other in _scales.values) {
          if (!identical(other, source) && other.isAuto && other.scale.range.dependsOnVisibleData) {
            other.markDirty(defer: false);
          }
        }
      } finally {
        _propagating = false;
      }
    }
    _notifyRender();
  }

  void _notifyRender() {
    for (final VoidCallback listener in List<VoidCallback>.of(_renderListeners)) {
      listener();
    }
  }

  // ---------------------------------------------------------------- series

  /// The series currently in the chart, in the order they are painted:
  /// the first one is at the bottom.
  ///
  /// The order is settled by the layout of the chart. Until then, a series
  /// added on a rebuild comes last.
  List<ChartSeries> get series => List<ChartSeries>.unmodifiable(_series);

  /// Notifies when series are added, removed or change their data or metadata.
  Listenable get seriesListenable => _seriesNotifier;

  /// The first series registered with [id], or null.
  ChartSeries? seriesById(Object id) {
    for (final ChartSeries s in _series) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Changes every time the set of series or their data changes.
  @internal
  int get revision => _revision;

  /// Adds [series] to the registry.
  @internal
  void registerSeries(ChartSeries series) {
    _series.add(series);
    _seriesOrderDirty = true;
    _seriesChanged();
  }

  /// Removes [series] from the registry.
  @internal
  void unregisterSeries(ChartSeries series) {
    if (!_series.remove(series)) return;
    _seriesOrderDirty = true;
    _seriesChanged();
  }

  /// Whether series came or went since [orderSeries] was last called.
  @internal
  bool get seriesOrderDirty => _seriesOrderDirty;

  /// Puts the registered series into the order of [painted], which lists
  /// them as they are painted. Returns whether a series changed its place.
  @internal
  bool orderSeries(List<ChartSeries> painted) {
    _seriesOrderDirty = false;
    final Set<ChartSeries> registered = Set<ChartSeries>.identity()..addAll(_series);
    final Set<ChartSeries> placed = Set<ChartSeries>.identity();
    final List<ChartSeries> next = <ChartSeries>[
      for (final ChartSeries s in painted)
        if (registered.contains(s) && placed.add(s)) s,
    ];
    // A series the chart did not find keeps its place after the others.
    for (final ChartSeries s in _series) {
      if (!placed.contains(s)) next.add(s);
    }
    bool moved = false;
    for (int i = 0; i < next.length && !moved; i++) {
      moved = !identical(next[i], _series[i]);
    }
    if (!moved) return false;
    _series
      ..clear()
      ..addAll(next);
    _seriesNotifier.notify();
    return true;
  }

  /// The place of [series] in [ChartController.series], or -1.
  @internal
  int seriesIndex(ChartSeries series) => _series.indexOf(series);

  /// Reports that the data or metadata of [series] changed.
  @internal
  void seriesChanged(ChartSeries series) => _seriesChanged();

  void _seriesChanged() {
    if (_disposed) return;
    _revision++;
    _propagating = true;
    try {
      for (final ChartScaleController c in _scales.values) {
        c.markDirty();
      }
    } finally {
      _propagating = false;
    }
    _notifyRender();
    _seriesNotifier.notify();
  }

  // ------------------------------------------------------------------ view

  /// The coordinate snapshot of the last layout, for use in event handlers.
  /// Null until the chart has been laid out once.
  ChartView? get view => _view;

  /// Stores the view of the layout that just finished.
  @internal
  void commitView(ChartView view) => _view = view;

  /// The data points at or near a plot-local [position], closest first.
  List<ChartHit> hitTest(
    Offset position, {
    ChartHitMode mode = ChartHitMode.nearestX,
    double maxDistance = double.infinity,
    ChartView? view,
  }) {
    final ChartView? v = view ?? _view;
    if (v == null) return const <ChartHit>[];
    final ChartHitQuery query = ChartHitQuery(
      position: position,
      view: v,
      mode: mode,
      maxDistance: maxDistance,
    );
    final List<ChartHit> hits = <ChartHit>[];
    for (final ChartSeries s in _series) {
      final int start = hits.length;
      s.collectHits(query, hits);
      for (int i = start; i < hits.length; i++) {
        if (hits[i].series == null) hits[i] = hits[i].withSeries(s);
      }
    }
    hits.sort((ChartHit a, ChartHit b) => a.distance.compareTo(b.distance));
    return hits;
  }

  /// The data point of each series closest to the data value [x].
  List<ChartHit> hitsAt(double x, {Object xScale = kChartX, ChartView? view}) {
    final ChartView? v = view ?? _view;
    if (v == null || !v.scales.containsKey(xScale)) return const <ChartHit>[];
    return hitTest(Offset(v.scale(xScale).toPixel(x), v.size.height / 2), view: v);
  }

  /// The data points [focus] stands for. This is what a crosshair marks and
  /// a tooltip lists.
  ///
  ///  * `nearestX`: the point of each series closest to the focused x.
  ///  * `nearestY`: the point of each series closest to the focused y.
  ///  * `nearest`: the points at the focused position, so nothing when the
  ///    focus is not on a point. A focus that has no y, or that comes from
  ///    another chart, whose y scale is not this one's, is matched along x.
  ///
  /// [xScale] and [yScale] are the scales the focus is measured on.
  List<ChartHit> hitsFor(
    ChartFocus focus, {
    Object xScale = kChartX,
    Object yScale = kChartY,
    ChartView? view,
  }) {
    final ChartView? v = view ?? _view;
    if (v == null) return const <ChartHit>[];
    final double? x = v.scales.containsKey(xScale) ? v.scale(xScale).toPixel(focus.x) : null;
    final double? focusY = focus.y;
    final double? y = focusY != null && v.scales.containsKey(yScale)
        ? v.scale(yScale).toPixel(focusY)
        : null;
    final bool own = focus.source == null || identical(focus.source, this);
    switch (focus.mode) {
      case ChartHitMode.nearest when y != null && own:
        if (x == null) return const <ChartHit>[];
        return hitTest(Offset(x, y), mode: ChartHitMode.nearest, maxDistance: 0.5, view: v);
      case ChartHitMode.nearestY:
        if (y == null) return const <ChartHit>[];
        return hitTest(Offset(v.size.width / 2, y), mode: ChartHitMode.nearestY, view: v);
      case ChartHitMode.nearestX || ChartHitMode.nearest:
        if (x == null) return const <ChartHit>[];
        return hitTest(Offset(x, v.size.height / 2), view: v);
    }
  }

  // ------------------------------------------------- pixel-space helpers

  /// The pixel mapping of scale [id] for its window as it is right now, which
  /// may be newer than the last layout. Null before the first layout.
  ChartScaleView? liveScaleView(Object id) {
    final ChartScaleView? laidOut = _view?.scales[id];
    if (laidOut == null) return null;
    final ChartScaleController c = scale(id);
    return ChartScaleView(
      id: id,
      scale: c.scale,
      scaledMin: c.scaledMin,
      scaledMax: c.scaledMax,
      extent: laidOut.extent,
      direction: laidOut.direction,
    );
  }

  /// The scale-space distance a drag of [pixels] along scale [id] stands for,
  /// or null before the first layout.
  double? pixelsToScaledDelta(Object id, double pixels) {
    final ChartScaleView? s = liveScaleView(id);
    if (s == null) return null;
    return s.pixelToScaled(0) - s.pixelToScaled(pixels);
  }

  /// Pans by [delta] logical pixels, as a drag by that amount would. Pass a
  /// null scale id to leave that dimension alone.
  void panByPixels(Offset delta, {Object? xScale = kChartX, Object? yScale = kChartY}) {
    if (xScale != null && delta.dx != 0) {
      final double? d = pixelsToScaledDelta(xScale, delta.dx);
      if (d != null) scale(xScale).panBy(d);
    }
    if (yScale != null && delta.dy != 0) {
      final double? d = pixelsToScaledDelta(yScale, delta.dy);
      if (d != null) scale(yScale).panBy(d);
    }
  }

  /// Zooms around a plot-local [focalPoint]. Factors above 1 zoom in.
  void zoomAt(
    Offset focalPoint, {
    double xFactor = 1,
    double yFactor = 1,
    Object xScale = kChartX,
    Object yScale = kChartY,
  }) {
    if (xFactor != 1) {
      final ChartScaleView? s = liveScaleView(xScale);
      if (s != null) scale(xScale).zoomBy(xFactor, scaledAnchor: s.pixelToScaled(focalPoint.dx));
    }
    if (yFactor != 1) {
      final ChartScaleView? s = liveScaleView(yScale);
      if (s != null) scale(yScale).zoomBy(yFactor, scaledAnchor: s.pixelToScaled(focalPoint.dy));
    }
  }

  /// Whether a gesture or animation is moving any scale.
  bool get isInteracting => _scales.values.any((ChartScaleController c) => c.isInteracting);

  // ------------------------------------------------------- chart plumbing

  /// Applies scale configuration coming from a chart widget.
  @internal
  void configure(Map<Object, ChartScale> scales) {
    scales.forEach((Object id, ChartScale config) => scale(id).configure(config));
  }

  /// Lends every scale a ticker provider for animations.
  @internal
  void attachVsync(TickerProvider vsync) {
    _vsyncs.add(vsync);
    for (final ChartScaleController c in _scales.values) {
      c.attachVsync(vsync);
    }
  }

  /// Takes the ticker provider back.
  @internal
  void detachVsync(TickerProvider vsync) {
    _vsyncs.remove(vsync);
    for (final ChartScaleController c in _scales.values) {
      c.detachVsync(vsync);
    }
  }

  /// Adds a listener called synchronously whenever layout must be redone.
  @internal
  void addRenderListener(VoidCallback listener) => _renderListeners.add(listener);

  /// Removes a listener added with [addRenderListener].
  @internal
  void removeRenderListener(VoidCallback listener) => _renderListeners.remove(listener);

  /// Releases the resources of the controller. Scale controllers and the
  /// focus notifier passed to the constructor stay alive.
  void dispose() {
    _disposed = true;
    for (final MapEntry<ChartScaleController, VoidCallback> e in _scaleListeners.entries) {
      e.key.removeRenderListener(e.value);
      e.key.removeSource(_extentFor);
    }
    for (final ChartScaleController c in _owned) {
      c.dispose();
    }
    if (_ownsFocus) focus.dispose();
    _seriesNotifier.dispose();
    _renderListeners.clear();
    _series.clear();
  }
}
