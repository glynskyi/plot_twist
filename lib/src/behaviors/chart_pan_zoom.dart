import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// What the mouse wheel does over a chart.
enum ChartWheelAction {
  /// Zooms around the pointer.
  zoom,

  /// Pans along the x scale.
  pan,

  /// Nothing; the wheel is left to whatever is behind the chart.
  none,
}

/// Lets the user pan and zoom a chart.
///
/// Add it to `Chart.children`. A chart without it has no gesture recognizers
/// at all.
///
///  * One finger (or a mouse drag) pans along [panX] / [panY]. Drags in other
///    directions are left to parent scrollables.
///  * Two fingers pinch-zoom along [zoomX] / [zoomY].
///  * The mouse wheel zooms around the pointer; trackpad scrolling pans.
///  * Dragging on an axis zooms just that scale ([axisDrag]).
///  * Lifting a moving finger flings with the platform's scroll physics.
///  * A double tap returns to the automatic range.
///
/// Everything it does goes through the public `ChartController` API, so a
/// custom behavior can do the same.
class ChartPanZoom extends StatefulWidget {
  /// Creates a pan/zoom behavior.
  const ChartPanZoom({
    super.key,
    this.panX = true,
    this.panY = false,
    this.zoomX = true,
    this.zoomY = false,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.wheel = ChartWheelAction.zoom,
    this.wheelRequiresModifier = false,
    this.inertia = true,
    this.axisDrag = true,
    this.doubleTapToReset = true,
    this.yieldAtLimits = false,
    this.anisotropicPinch = false,
  });

  /// Whether dragging pans the x scale.
  final bool panX;

  /// Whether dragging pans the y scale.
  final bool panY;

  /// Whether pinching and the wheel zoom the x scale.
  final bool zoomX;

  /// Whether pinching and the wheel zoom the y scale.
  final bool zoomY;

  /// Id of the horizontal scale to move.
  final Object xScale;

  /// Id of the vertical scale to move.
  final Object yScale;

  /// What the mouse wheel does.
  final ChartWheelAction wheel;

  /// Whether the wheel only acts while Ctrl or ⌘ is held, so a page containing
  /// the chart can still be scrolled with the wheel.
  final bool wheelRequiresModifier;

  /// Whether a moving finger that is lifted flings the chart.
  final bool inertia;

  /// Whether dragging on an axis zooms that axis's scale.
  final bool axisDrag;

  /// Whether a double tap returns the scales to their automatic range.
  final bool doubleTapToReset;

  /// Whether a drag the chart cannot follow (it is at a limit) is left to a
  /// parent, such as a `PageView`.
  final bool yieldAtLimits;

  /// Whether a pinch zooms x and y by the horizontal and vertical spread of
  /// the fingers separately.
  final bool anisotropicPinch;

  @override
  State<ChartPanZoom> createState() => _ChartPanZoomState();
}

class _ChartPanZoomState extends State<ChartPanZoom> with SingleTickerProviderStateMixin {
  late ChartController _controller;
  ChartPanZoomGestureRecognizer? _recognizer;
  Ticker? _ticker;
  Simulation? _simX;
  Simulation? _simY;
  double _lastX = 0;
  double _lastY = 0;

  // Where the current gesture started.
  ChartRegion _region = ChartRegion.plot;
  Object? _axisScale;
  bool _gestureActive = false;
  // The scales a gesture or fling of this widget is moving.
  final Set<ChartScaleController> _interacting = <ChartScaleController>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ChartScope.of(context).controller;
  }

  @override
  void dispose() {
    // The widget may be removed with a finger still down. The end of that
    // gesture never arrives here, so the scales are released now.
    _gestureActive = false;
    _stopFling();
    _ticker?.dispose();
    super.dispose();
  }

  bool _acceptsPointer(ChartPointerEvent event) =>
      event.region == ChartRegion.plot || (widget.axisDrag && event.axisScale != null);

  void _handlePointerDown(ChartPointerEvent event) {
    _stopFling();
    if (_gestureActive || !_acceptsPointer(event)) return;
    _region = event.region;
    _axisScale = event.axisScale;
    final ChartPanZoomGestureRecognizer? recognizer = _recognizer;
    if (recognizer == null) return;
    if (_region == ChartRegion.plot) {
      recognizer
        ..panHorizontal = widget.panX
        ..panVertical = widget.panY
        ..pinch = widget.zoomX || widget.zoomY;
    } else {
      // On an axis: drag along it to zoom its scale.
      final bool horizontalAxis = _region == ChartRegion.top || _region == ChartRegion.bottom;
      recognizer
        ..panHorizontal = horizontalAxis
        ..panVertical = !horizontalAxis
        ..pinch = false;
    }
  }

  bool _canPan(Offset delta) {
    bool can(Object id, double pixels, bool enabled) {
      if (!enabled || pixels == 0) return false;
      final double? scaled = _controller.pixelsToScaledDelta(id, pixels);
      return scaled != null && _controller.scale(id).canPanBy(scaled);
    }

    return can(widget.xScale, delta.dx, widget.panX) || can(widget.yScale, delta.dy, widget.panY);
  }

  void _begin(Object id) {
    final ChartScaleController scale = _controller.scale(id);
    if (_interacting.add(scale)) scale.beginInteraction();
  }

  // Ends the interaction on the scales it began on, which are not
  // necessarily those of the chart's current controller.
  void _endAll() {
    for (final ChartScaleController scale in _interacting) {
      scale.endInteraction();
    }
    _interacting.clear();
  }

  void _handleStart(ChartPanZoomStartDetails details) {
    _stopFling();
    _gestureActive = true;
    if (_region == ChartRegion.plot) {
      if (widget.panX || widget.zoomX) _begin(widget.xScale);
      if (widget.panY || widget.zoomY) _begin(widget.yScale);
    } else if (_axisScale != null) {
      _begin(_axisScale!);
    }
  }

  void _handleUpdate(ChartPanZoomUpdateDetails details) {
    final ChartView? view = _controller.view;
    if (view == null) return;
    if (_region != ChartRegion.plot) {
      final Object? id = _axisScale;
      if (id == null) return;
      final bool horizontalAxis = _region == ChartRegion.top || _region == ChartRegion.bottom;
      final double factor = horizontalAxis
          ? math.exp(details.focalPointDelta.dx / 160)
          : math.exp(-details.focalPointDelta.dy / 160);
      _controller.scale(id).zoomBy(factor);
      return;
    }
    _controller.panByPixels(
      details.focalPointDelta,
      xScale: widget.panX ? widget.xScale : null,
      yScale: widget.panY ? widget.yScale : null,
    );
    if (details.scale != 1 || details.horizontalScale != 1 || details.verticalScale != 1) {
      _controller.zoomAt(
        view.chartToPlot(details.localFocalPoint),
        xFactor: widget.zoomX
            ? (widget.anisotropicPinch ? details.horizontalScale : details.scale)
            : 1,
        yFactor: widget.zoomY
            ? (widget.anisotropicPinch ? details.verticalScale : details.scale)
            : 1,
        xScale: widget.xScale,
        yScale: widget.yScale,
      );
    }
  }

  void _handleEnd(ChartPanZoomEndDetails details) {
    _gestureActive = false;
    final bool fling =
        widget.inertia &&
        _region == ChartRegion.plot &&
        details.velocity.pixelsPerSecond != Offset.zero &&
        _startFling(details.velocity.pixelsPerSecond);
    if (!fling) _endAll();
  }

  // ------------------------------------------------------------- fling

  Simulation? _simulationFor(Object id, double dragVelocity, AxisDirection direction) {
    if (dragVelocity == 0) return null;
    final ChartScaleView? live = _controller.liveScaleView(id);
    if (live == null || live.extent <= 0) return null;
    final (double below, double above) = _controller.scale(id).panRoom;
    final double pixelsPerUnit = live.pixelsPerUnit;
    // In scroll terms, a positive offset moves the content against the drag.
    final bool flipped = live.scaledToPixel(live.scaledMax) < live.scaledToPixel(live.scaledMin);
    final double forward = (flipped ? below : above) * pixelsPerUnit;
    final double backward = (flipped ? above : below) * pixelsPerUnit;
    final double velocity = -dragVelocity;
    if ((velocity > 0 && forward <= 0) || (velocity < 0 && backward <= 0)) return null;
    final ScrollPhysics physics = ScrollConfiguration.of(context).getScrollPhysics(context);
    return physics.createBallisticSimulation(
      FixedScrollMetrics(
        minScrollExtent: -backward,
        maxScrollExtent: forward,
        pixels: 0,
        viewportDimension: live.extent,
        axisDirection: direction,
        devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      ),
      velocity,
    );
  }

  bool _startFling(Offset velocity) {
    _simX = widget.panX ? _simulationFor(widget.xScale, velocity.dx, AxisDirection.right) : null;
    _simY = widget.panY ? _simulationFor(widget.yScale, velocity.dy, AxisDirection.down) : null;
    if (_simX == null && _simY == null) return false;
    _lastX = 0;
    _lastY = 0;
    final Ticker ticker = _ticker ??= createTicker(_tick);
    if (ticker.isActive) ticker.stop();
    ticker.start();
    return true;
  }

  void _tick(Duration elapsed) {
    final double t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    double dx = 0;
    double dy = 0;
    final Simulation? simX = _simX;
    if (simX != null) {
      final double x = simX.x(t);
      dx = x - _lastX;
      _lastX = x;
      if (simX.isDone(t) || !_canMove(widget.xScale, -dx)) _simX = null;
    }
    final Simulation? simY = _simY;
    if (simY != null) {
      final double y = simY.x(t);
      dy = y - _lastY;
      _lastY = y;
      if (simY.isDone(t) || !_canMove(widget.yScale, -dy)) _simY = null;
    }
    _controller.panByPixels(Offset(-dx, -dy), xScale: widget.xScale, yScale: widget.yScale);
    if (_simX == null && _simY == null) _stopFling();
  }

  bool _canMove(Object id, double pixels) {
    if (pixels == 0) return true;
    final double? scaled = _controller.pixelsToScaledDelta(id, pixels);
    return scaled != null && _controller.scale(id).canPanBy(scaled);
  }

  void _stopFling() {
    _simX = null;
    _simY = null;
    final Ticker? ticker = _ticker;
    if (ticker != null && ticker.isActive) ticker.stop();
    if (!_gestureActive) _endAll();
  }

  // ---------------------------------------------------- wheel, trackpad

  void _handleSignal(ChartPointerEvent chartEvent) {
    final PointerEvent event = chartEvent.event;
    final bool overAxis = chartEvent.region != ChartRegion.plot;
    if (overAxis && chartEvent.axisScale == null) return;

    void zoom(double factor) {
      if (overAxis) {
        final ChartScaleController scale = _controller.scale(chartEvent.axisScale!);
        if (!scale.canZoomBy(factor)) return;
        GestureBinding.instance.pointerSignalResolver.register(event as PointerSignalEvent, (
          PointerSignalEvent _,
        ) {
          _stopFling();
          scale.zoomBy(factor);
        });
        return;
      }
      final bool x = widget.zoomX && _controller.scale(widget.xScale).canZoomBy(factor);
      final bool y = widget.zoomY && _controller.scale(widget.yScale).canZoomBy(factor);
      if (!x && !y) return;
      GestureBinding.instance.pointerSignalResolver.register(event as PointerSignalEvent, (
        PointerSignalEvent _,
      ) {
        _stopFling();
        _controller.zoomAt(
          chartEvent.plotPosition,
          xFactor: x ? factor : 1,
          yFactor: y ? factor : 1,
          xScale: widget.xScale,
          yScale: widget.yScale,
        );
      });
    }

    void pan(Offset delta) {
      if (overAxis || delta == Offset.zero || !_canPan(delta)) return;
      GestureBinding.instance.pointerSignalResolver.register(event as PointerSignalEvent, (
        PointerSignalEvent _,
      ) {
        _stopFling();
        _controller.panByPixels(
          delta,
          xScale: widget.panX ? widget.xScale : null,
          yScale: widget.panY ? widget.yScale : null,
        );
      });
    }

    if (event is PointerScaleEvent) {
      zoom(event.scale);
    } else if (event is PointerScrollEvent) {
      if (event.kind == PointerDeviceKind.trackpad) {
        pan(-event.scrollDelta);
        return;
      }
      if (widget.wheel == ChartWheelAction.none) return;
      if (widget.wheelRequiresModifier &&
          !HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isMetaPressed) {
        return;
      }
      if (widget.wheel == ChartWheelAction.zoom) {
        zoom(math.exp(-event.scrollDelta.dy / 300));
      } else {
        // A vertical wheel pans horizontally; a tilt wheel pans directly.
        final double amount = event.scrollDelta.dx != 0
            ? event.scrollDelta.dx
            : event.scrollDelta.dy;
        pan(Offset(-amount, 0));
      }
    }
  }

  void _reset() {
    _stopFling();
    const Duration duration = Duration(milliseconds: 250);
    if (widget.panX || widget.zoomX) {
      _controller.scale(widget.xScale).resetToAuto(duration: duration);
    }
    if (widget.panY || widget.zoomY) {
      _controller.scale(widget.yScale).resetToAuto(duration: duration);
    }
  }

  @override
  Widget build(BuildContext context) => ChartGestureDetector(
    acceptPointer: _acceptsPointer,
    onPointerDown: _handlePointerDown,
    onPointerSignal: _handleSignal,
    gestures: <Type, GestureRecognizerFactory>{
      ChartPanZoomGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<ChartPanZoomGestureRecognizer>(
            () => ChartPanZoomGestureRecognizer(debugOwner: this),
            (ChartPanZoomGestureRecognizer recognizer) {
              _recognizer = recognizer
                ..shouldAcceptPan = widget.yieldAtLimits
                    ? (Offset delta) => _region != ChartRegion.plot || _canPan(delta)
                    : null
                ..onStart = _handleStart
                ..onUpdate = _handleUpdate
                ..onEnd = _handleEnd;
            },
          ),
      if (widget.doubleTapToReset)
        DoubleTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
              () => DoubleTapGestureRecognizer(debugOwner: this),
              (DoubleTapGestureRecognizer recognizer) => recognizer.onDoubleTap = _reset,
            ),
    },
  );
}
