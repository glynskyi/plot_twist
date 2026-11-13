import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'range.dart';
import 'scale.dart';

/// Supplies the extent of data plotted on a scale.
@internal
typedef ChartExtentSource =
    ChartRange? Function(ChartScaleController scale, {required bool visibleOnly});

/// The live state of one scale: which window is visible.
///
/// The window is kept in data space, so prepending or appending data never
/// moves it. A scale is either *automatic* — its window follows the scale's
/// [ChartRangePolicy] — or *manual*, after a pan, zoom, [jumpTo] or
/// [animateTo]. Call [resetToAuto] to return to automatic.
///
/// The controller is a [Listenable]: listeners are told whenever the window
/// may have changed. Share one instance between several charts to link them.
class ChartScaleController extends ChangeNotifier implements ChartRangeContext {
  ChartScale _scale = const LinearScale();
  bool _configured = false;

  // Window in scale space.
  double _lo = 0;
  double _hi = 1;
  bool _auto = true;
  bool _dirty = true;
  bool _resolving = false;

  final List<ChartExtentSource> _sources = <ChartExtentSource>[];
  final List<VoidCallback> _renderListeners = <VoidCallback>[];
  final List<TickerProvider> _vsyncs = <TickerProvider>[];
  AnimationController? _animation;
  int _interactions = 0;
  bool _notifyScheduled = false;
  bool _disposed = false;

  @override
  ChartScale get scale => _scale;

  /// Whether the window currently follows the scale's range policy.
  bool get isAuto => _auto;

  /// Whether a gesture or animation is currently moving the window.
  bool get isInteracting => _interactions > 0 || _animation != null;

  /// Lower bound of the visible window in scale space.
  double get scaledMin {
    _resolve();
    return _lo;
  }

  /// Upper bound of the visible window in scale space.
  double get scaledMax {
    _resolve();
    return _hi;
  }

  /// Lower bound of the visible window, in data units.
  double get min => _scale.invert(scaledMin);

  /// Upper bound of the visible window, in data units.
  double get max => _scale.invert(scaledMax);

  /// The visible window, in data units.
  ChartRange get range => ChartRange.of(min, max);

  @override
  ChartRange? dataExtent({bool visibleOnly = false}) {
    ChartRange? result;
    for (final ChartExtentSource source in _sources) {
      result = ChartRange.merge(result, source(this, visibleOnly: visibleOnly));
    }
    return result;
  }

  /// Shows `[min, max]` (data units) immediately and switches to manual mode.
  void jumpTo(double min, double max) => jumpToScaled(_scale.transform(min), _scale.transform(max));

  /// Like [jumpTo], with bounds given in scale space.
  void jumpToScaled(double scaledMin, double scaledMax) {
    stop();
    _setManual(scaledMin, scaledMax);
  }

  /// Moves the window by [scaledDelta] scale-space units.
  void panBy(double scaledDelta) {
    if (scaledDelta == 0) return;
    stop();
    _setManual(scaledMin + scaledDelta, scaledMax + scaledDelta);
  }

  /// Zooms by [factor] (`> 1` zooms in) keeping [anchor] (a data value) or
  /// [scaledAnchor] fixed on screen. Without an anchor the centre stays put.
  void zoomBy(double factor, {double? anchor, double? scaledAnchor}) {
    if (!(factor > 0) || factor == 1) return;
    stop();
    final double lo = scaledMin;
    final double hi = scaledMax;
    final double a = scaledAnchor ?? (anchor != null ? _scale.transform(anchor) : (lo + hi) / 2);
    _setManual(a - (a - lo) / factor, a + (hi - a) / factor);
  }

  /// Whether [panBy] with [scaledDelta] would move the window (false when it
  /// is already against a limit in that direction).
  bool canPanBy(double scaledDelta) {
    if (scaledDelta == 0) return false;
    final double lo = scaledMin;
    final double hi = scaledMax;
    final (double newLo, double newHi) = _clamp(lo + scaledDelta, hi + scaledDelta);
    return (newLo - lo).abs() > (hi - lo) * 1e-9 || (newHi - hi).abs() > (hi - lo) * 1e-9;
  }

  /// Whether [zoomBy] with [factor] would change the window (false at the
  /// zoom limits).
  bool canZoomBy(double factor) {
    if (!(factor > 0) || factor == 1) return false;
    final double lo = scaledMin;
    final double hi = scaledMax;
    final double centre = (lo + hi) / 2;
    final double half = (hi - lo) / 2 / factor;
    final (double newLo, double newHi) = _clamp(centre - half, centre + half);
    return ((newHi - newLo) - (hi - lo)).abs() > (hi - lo) * 1e-9;
  }

  /// How far the window can still be panned towards smaller and larger
  /// values, in scale-space units. Infinite when unbounded.
  (double below, double above) get panRoom {
    final (double? dataMin, double? dataMax) = _scale.limits.bounds(this);
    final double lo = scaledMin;
    final double hi = scaledMax;
    return (
      dataMin == null ? double.infinity : math.max(0, lo - _scale.transform(dataMin)),
      dataMax == null ? double.infinity : math.max(0, _scale.transform(dataMax) - hi),
    );
  }

  /// Animates the window to `[min, max]` (data units).
  ///
  /// Needs a chart attached to drive the animation; without one the window
  /// jumps.
  Future<void> animateTo(
    double min,
    double max, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) => _animateScaled(_scale.transform(min), _scale.transform(max), duration, curve, false);

  /// Returns to automatic mode, optionally animating to the policy's window.
  void resetToAuto({Duration duration = Duration.zero, Curve curve = Curves.easeOutCubic}) {
    if (duration > Duration.zero && _vsyncs.isNotEmpty) {
      final ChartRange target = _scale.range.resolve(this);
      _animateScaled(
        _scale.transform(target.min),
        _scale.transform(target.max),
        duration,
        curve,
        true,
      );
      return;
    }
    stop();
    if (_auto && !_dirty) return;
    _auto = true;
    _dirty = true;
    _notify();
  }

  /// Marks the start of a user gesture. Pair with [endInteraction].
  void beginInteraction() {
    stop();
    _interactions++;
    if (_interactions == 1) _notify();
  }

  /// Marks the end of a user gesture.
  void endInteraction() {
    if (_interactions == 0) return;
    _interactions--;
    if (_interactions == 0) _notify();
  }

  /// Cancels a running animation, leaving the window where it is.
  void stop() {
    final AnimationController? animation = _animation;
    if (animation == null) return;
    _animation = null;
    animation.dispose();
  }

  Future<void> _animateScaled(double lo, double hi, Duration duration, Curve curve, bool endAuto) {
    stop();
    void finish() {
      if (endAuto) {
        _auto = true;
        _dirty = true;
        _notify();
      }
    }

    if (_vsyncs.isEmpty || duration <= Duration.zero) {
      _setManual(lo, hi);
      finish();
      return Future<void>.value();
    }
    final double fromLo = scaledMin;
    final double fromHi = scaledMax;
    final AnimationController animation = AnimationController(
      vsync: _vsyncs.last,
      duration: duration,
    );
    _animation = animation;
    animation.addListener(() {
      final double t = curve.transform(animation.value);
      _setManual(lerpDouble(fromLo, lo, t)!, lerpDouble(fromHi, hi, t)!);
    });
    final Completer<void> done = Completer<void>();
    animation.forward().whenCompleteOrCancel(() {
      if (identical(_animation, animation)) {
        _animation = null;
        animation.dispose();
        finish();
        if (!endAuto) _notify();
      }
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  void _setManual(double lo, double hi) {
    if (!lo.isFinite || !hi.isFinite || !(hi > lo)) return;
    final (double clampedLo, double clampedHi) = _clamp(lo, hi);
    if (!_auto && clampedLo == _lo && clampedHi == _hi) return;
    _lo = clampedLo;
    _hi = clampedHi;
    _auto = false;
    _dirty = false;
    _notify();
  }

  (double, double) _clamp(double lo, double hi) {
    final ChartLimits limits = _scale.limits;
    final (double? dataMin, double? dataMax) = limits.bounds(this);
    final double? boundLo = dataMin == null ? null : _scale.transform(dataMin);
    final double? boundHi = dataMax == null ? null : _scale.transform(dataMax);

    double span = hi - lo;
    final double center = (lo + hi) / 2;
    // Never zoom past what a double can resolve.
    final double floor = math.max(lo.abs(), hi.abs()) * 1e-13 + 1e-300;
    final double minSpan = math.max(limits.minSpan ?? 0, floor);
    double maxSpan = limits.maxSpan ?? double.infinity;
    if (boundLo != null && boundHi != null) maxSpan = math.min(maxSpan, boundHi - boundLo);
    if (maxSpan < minSpan) maxSpan = minSpan;
    final double clampedSpan = span.clamp(minSpan, maxSpan);
    if (clampedSpan != span) {
      span = clampedSpan;
      lo = center - span / 2;
      hi = center + span / 2;
    }
    if (boundLo != null && lo < boundLo) {
      lo = boundLo;
      hi = lo + span;
    }
    if (boundHi != null && hi > boundHi) {
      hi = boundHi;
      lo = hi - span;
    }
    return (lo, hi);
  }

  void _resolve() {
    if (!_auto || !_dirty || _resolving) return;
    _resolving = true;
    try {
      final ChartRange wanted = _scale.range.resolve(this);
      final double lo = _scale.transform(wanted.min);
      final double hi = _scale.transform(wanted.max);
      if (lo.isFinite && hi.isFinite && hi > lo) {
        _lo = lo;
        _hi = hi;
      }
    } finally {
      _resolving = false;
      _dirty = false;
    }
  }

  // Public listeners may call setState, which is illegal while widgets are
  // being built or laid out. Changes that originate from the widget lifecycle
  // ([defer]) and changes made while a frame is being produced are therefore
  // announced right after the frame.
  void _notify({bool defer = false}) {
    if (_disposed) return;
    for (final VoidCallback listener in List<VoidCallback>.of(_renderListeners)) {
      listener();
    }
    final SchedulerBinding scheduler = SchedulerBinding.instance;
    if (defer || scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      scheduler.addPostFrameCallback((Duration _) {
        _notifyScheduled = false;
        if (!_disposed) notifyListeners();
      });
      scheduler.ensureVisualUpdate();
    } else {
      notifyListeners();
    }
  }

  /// Applies the configuration from a chart. A scale equal to the current one
  /// changes nothing; a new range policy puts the scale back in automatic mode.
  @internal
  void configure(ChartScale scale) {
    final ChartScale old = _scale;
    if (_configured && old == scale) return;
    final bool wasConfigured = _configured;
    _configured = true;
    _scale = scale;
    if (!_auto) {
      // Keep showing the same data values under a new transform.
      final double min = old.invert(_lo);
      final double max = old.invert(_hi);
      final double lo = scale.transform(min);
      final double hi = scale.transform(max);
      if (lo.isFinite && hi.isFinite && hi > lo) {
        _lo = lo;
        _hi = hi;
      } else {
        _auto = true;
      }
    }
    if (wasConfigured && old.range != scale.range) _auto = true;
    if (_auto) _dirty = true;
    _notify(defer: true);
  }

  /// Tells the scale that data or another scale's window changed, so an
  /// automatic window must be recomputed.
  ///
  /// [defer] must be true when called from the widget lifecycle.
  @internal
  void markDirty({bool defer = true}) {
    if (!_auto) return;
    _dirty = true;
    _notify(defer: defer);
  }

  /// Registers a source of data extents.
  @internal
  void addSource(ChartExtentSource source) {
    _sources.add(source);
    markDirty();
  }

  /// Removes a source of data extents.
  @internal
  void removeSource(ChartExtentSource source) {
    if (_sources.remove(source) && !_disposed) markDirty();
  }

  /// Adds a listener that is called synchronously in every scheduler phase.
  @internal
  void addRenderListener(VoidCallback listener) => _renderListeners.add(listener);

  /// Removes a listener added with [addRenderListener].
  @internal
  void removeRenderListener(VoidCallback listener) => _renderListeners.remove(listener);

  /// Lends the scale a ticker provider for animations.
  @internal
  void attachVsync(TickerProvider vsync) => _vsyncs.add(vsync);

  /// Takes a ticker provider back.
  @internal
  void detachVsync(TickerProvider vsync) {
    if (_vsyncs.isNotEmpty && identical(_vsyncs.last, vsync)) stop();
    _vsyncs.remove(vsync);
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    _renderListeners.clear();
    _sources.clear();
    super.dispose();
  }
}
