import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Tracks what the user points at and draws a crosshair there.
///
/// The pointed-at position is stored in `ChartController.focus`, in data
/// space — so it survives panning and live data, can be read from outside the
/// chart (to show a value in a header, highlight a table row), and can be
/// shared between linked charts by giving their controllers the same focus
/// notifier.
///
/// Hovering with a mouse and long-pressing on touch set the focus; with [tap]
/// a tap sets it until the next tap. Pair it with `ChartTooltip` and
/// `ChartCrosshairBadge`, which follow the same focus.
///
/// [mode] chooses what the pointer picks: the points at its x (the default),
/// the single closest point (for scatter plots) or the points at its y (for
/// horizontal bars).
class ChartCrosshair extends StatefulWidget {
  /// Creates a crosshair.
  const ChartCrosshair({
    super.key,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.mode = ChartHitMode.nearestX,
    this.snap = true,
    this.snapDistance = double.infinity,
    bool? vertical,
    bool? horizontal,
    this.showPoints = true,
    this.hover = true,
    this.longPress = true,
    this.tap = false,
    this.color,
    this.width = 1,
    this.pointRadius = 4,
  }) : vertical = vertical ?? mode != ChartHitMode.nearestY,
       horizontal = horizontal ?? mode == ChartHitMode.nearestY;

  /// Id of the horizontal scale.
  final Object xScale;

  /// Id of the vertical scale.
  final Object yScale;

  /// How the pointer is matched to data points, and so what the focus stands
  /// for:
  ///
  ///  * `nearestX`: the focus snaps along x and stands for the point of each
  ///    series at that x.
  ///  * `nearest`: the focus snaps to the closest point in both dimensions
  ///    and stands for that point alone.
  ///  * `nearestY`: the focus snaps along y and stands for the point of each
  ///    series at that y.
  final ChartHitMode mode;

  /// Whether the focus snaps to the nearest data point.
  final bool snap;

  /// How far from the pointer, in logical pixels, a data point may be for the
  /// focus to snap to it. Further away, the focus stays under the pointer.
  final double snapDistance;

  /// Whether a vertical line is drawn at the focus. Defaults to true, and to
  /// false when [mode] is `nearestY`. Then it is only shown in the chart the
  /// pointer is in.
  final bool vertical;

  /// Whether a horizontal line is drawn at the focus. Defaults to false, and
  /// to true when [mode] is `nearestY`. In the other modes it is only shown
  /// in the chart the pointer is in.
  final bool horizontal;

  /// Whether a dot is drawn on each data point the focus stands for.
  final bool showPoints;

  /// Whether hovering with a mouse sets the focus.
  final bool hover;

  /// Whether a long press (and drag) sets the focus on touch screens.
  final bool longPress;

  /// Whether a tap sets a focus that stays until the next tap.
  final bool tap;

  /// Line colour. Defaults to the chart theme.
  final Color? color;

  /// Line width.
  final double width;

  /// Radius of the dots drawn on series.
  final double pointRadius;

  @override
  State<ChartCrosshair> createState() => _ChartCrosshairState();
}

class _ChartCrosshairState extends State<ChartCrosshair> {
  late ChartController _controller;
  bool _sticky = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ChartScope.of(context).controller;
  }

  void _focusAt(Offset plotPosition) {
    final ChartView? view = _controller.view;
    if (view == null || !view.scales.containsKey(widget.xScale)) return;
    final ChartScaleView xs = view.scale(widget.xScale);
    final ChartScaleView? ys = view.scales[widget.yScale];
    double x = xs.toValue(plotPosition.dx);
    double? y = ys?.toValue(plotPosition.dy);
    if (widget.snap) {
      final List<ChartHit> hits = _controller.hitTest(
        plotPosition,
        mode: widget.mode,
        maxDistance: widget.snapDistance,
        view: view,
      );
      if (hits.isNotEmpty) {
        // The focus is kept in the units of this crosshair's scales, which
        // need not be the ones the series is drawn on.
        final ChartHit hit = hits.first;
        final bool sameX = hit.series?.xScale == widget.xScale;
        final bool sameY = hit.series?.yScale == widget.yScale;
        if (widget.mode != ChartHitMode.nearestY) {
          x = sameX ? hit.x : xs.toValue(hit.position.dx);
        }
        if (widget.mode != ChartHitMode.nearestX && ys != null) {
          y = sameY ? hit.y : ys.toValue(hit.position.dy);
        }
      }
    }
    _controller.focus.value = ChartFocus(x: x, y: y, mode: widget.mode, source: _controller);
  }

  // Whether two focuses of this crosshair point at the same data.
  bool _sameTarget(ChartFocus a, ChartFocus? b) => switch (widget.mode) {
    ChartHitMode.nearestX => a.x == b?.x,
    ChartHitMode.nearestY => a.y == b?.y,
    ChartHitMode.nearest => a.x == b?.x && a.y == b?.y,
  };

  void _clear() {
    if (_sticky) return;
    if (identical(_controller.focus.value?.source, _controller)) _controller.focus.value = null;
  }

  Offset _toPlot(Offset chartLocal) => _controller.view?.chartToPlot(chartLocal) ?? chartLocal;

  @override
  Widget build(BuildContext context) {
    final ChartThemeData theme = ChartTheme.of(context);
    return ChartGestureDetector(
      onPointerHover: widget.hover && !_sticky
          ? (ChartPointerEvent event) {
              if (event.region == ChartRegion.plot) {
                _focusAt(event.plotPosition);
              } else {
                _clear();
              }
            }
          : null,
      onPointerExit: widget.hover ? _clear : null,
      gestures: <Type, GestureRecognizerFactory>{
        if (widget.longPress)
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  debugOwner: this,
                  supportedDevices: const <PointerDeviceKind>{
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                  },
                ),
                (LongPressGestureRecognizer recognizer) {
                  recognizer.onLongPressStart = (LongPressStartDetails d) {
                    _focusAt(_toPlot(d.localPosition));
                  };
                  recognizer.onLongPressMoveUpdate = (LongPressMoveUpdateDetails d) {
                    _focusAt(_toPlot(d.localPosition));
                  };
                  recognizer.onLongPressEnd = (LongPressEndDetails d) => _clear();
                },
              ),
        if (widget.tap)
          TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(debugOwner: this),
            (TapGestureRecognizer recognizer) => recognizer.onTapUp = (TapUpDetails d) {
              final Offset position = _toPlot(d.localPosition);
              final ChartFocus? before = _controller.focus.value;
              _focusAt(position);
              final bool same =
                  _sticky && before != null && _sameTarget(before, _controller.focus.value);
              setState(() => _sticky = !same);
              if (same) _controller.focus.value = null;
            },
          ),
      },
      child: ChartPaint(
        painter: _CrosshairPainter(
          controller: _controller,
          xScale: widget.xScale,
          yScale: widget.yScale,
          vertical: widget.vertical,
          horizontal: widget.horizontal,
          showPoints: widget.showPoints,
          color: widget.color ?? theme.crosshairColor,
          ring: theme.tooltipTextStyle.color ?? const Color(0xFFFFFFFF),
          width: widget.width,
          pointRadius: widget.pointRadius,
        ),
      ),
    );
  }
}

class _CrosshairPainter extends ChartPainter {
  _CrosshairPainter({
    required this.controller,
    required this.xScale,
    required this.yScale,
    required this.vertical,
    required this.horizontal,
    required this.showPoints,
    required this.color,
    required this.ring,
    required this.width,
    required this.pointRadius,
  }) : super(repaint: controller.focus);

  final ChartController controller;
  final Object xScale;
  final Object yScale;
  final bool vertical;
  final bool horizontal;
  final bool showPoints;
  final Color color;
  final Color ring;
  final double width;
  final double pointRadius;

  @override
  void paint(ChartPaintContext context) {
    final ChartFocus? focus = controller.focus.value;
    final ChartView view = context.view;
    if (focus == null || !view.scales.containsKey(xScale)) return;
    final ui.Canvas canvas = context.canvas;
    final Paint line = Paint()
      ..color = color
      ..strokeWidth = width;
    // A linked chart shares the dimension the focus runs along. The other
    // coordinate is the pointer's, which only means something in its chart.
    final bool own = identical(focus.source, controller);
    final bool alongY = focus.mode == ChartHitMode.nearestY;
    final double x = view.scale(xScale).toPixel(focus.x);
    if (vertical && (own || !alongY) && x >= 0 && x <= view.size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, view.size.height), line);
    }
    final double? focusY = focus.y;
    if (horizontal && focusY != null && (own || alongY) && view.scales.containsKey(yScale)) {
      final double y = view.scale(yScale).toPixel(focusY);
      if (y >= 0 && y <= view.size.height) {
        canvas.drawLine(Offset(0, y), Offset(view.size.width, y), line);
      }
    }
    if (!showPoints) return;
    for (final ChartHit hit in controller.hitsFor(
      focus,
      xScale: xScale,
      yScale: yScale,
      view: view,
    )) {
      if (hit.rect != null) continue; // Bars are highlighted by their own shape.
      canvas.drawCircle(hit.position, pointRadius + 1.5, Paint()..color = ring);
      canvas.drawCircle(hit.position, pointRadius, Paint()..color = hit.series?.color ?? color);
    }
  }

  @override
  bool shouldRepaint(_CrosshairPainter oldDelegate) =>
      !identical(oldDelegate.controller, controller) ||
      oldDelegate.xScale != xScale ||
      oldDelegate.yScale != yScale ||
      oldDelegate.vertical != vertical ||
      oldDelegate.horizontal != horizontal ||
      oldDelegate.showPoints != showPoints ||
      oldDelegate.color != color ||
      oldDelegate.ring != ring ||
      oldDelegate.width != width ||
      oldDelegate.pointRadius != pointRadius;
}

/// A widget pinned to the focused value on a `ChartAxis` — the badge that
/// shows the crosshair's value on the axis.
///
/// Put it in `ChartAxis.markers`. It rebuilds [builder] when the focus
/// changes and follows its value in layout.
class ChartCrosshairBadge extends StatelessWidget {
  /// Creates a badge for the focused value along the axis it is placed in.
  const ChartCrosshairBadge({super.key, required this.builder});

  /// Builds the badge for the focused data value.
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    final ChartController controller = ChartScope.of(context).controller;
    final bool horizontal = ChartDockScope.maybeOf(context)?.isHorizontal ?? true;
    return ValueListenableBuilder<ChartFocus?>(
      valueListenable: controller.focus,
      builder: (BuildContext context, ChartFocus? focus, Widget? child) {
        // A linked chart shares the dimension the focus runs along; the other
        // coordinate only means something in the chart the pointer is in.
        final bool own = focus != null && identical(focus.source, controller);
        final bool alongY = focus?.mode == ChartHitMode.nearestY;
        final double? value = focus == null
            ? null
            : (horizontal ? (own || !alongY ? focus.x : null) : (own || alongY ? focus.y : null));
        if (value == null) return const SizedBox.shrink();
        return ChartAxisMarker(value: value, clamp: false, child: builder(context, value));
      },
    );
  }
}
