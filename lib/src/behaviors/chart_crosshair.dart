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
class ChartCrosshair extends StatefulWidget {
  /// Creates a crosshair.
  const ChartCrosshair({
    super.key,
    this.xScale = kChartX,
    this.yScale = kChartY,
    this.snap = true,
    this.vertical = true,
    this.horizontal = false,
    this.showPoints = true,
    this.hover = true,
    this.longPress = true,
    this.tap = false,
    this.color,
    this.width = 1,
    this.pointRadius = 4,
  });

  /// Id of the horizontal scale.
  final Object xScale;

  /// Id of the vertical scale.
  final Object yScale;

  /// Whether the focus snaps to the nearest data point along x.
  final bool snap;

  /// Whether a vertical line is drawn at the focus.
  final bool vertical;

  /// Whether a horizontal line is drawn at the pointer's height. Only shown
  /// in the chart the pointer is in.
  final bool horizontal;

  /// Whether a dot is drawn on each series at the focus.
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
    double x = view.scale(widget.xScale).toValue(plotPosition.dx);
    if (widget.snap) {
      final List<ChartHit> hits = _controller.hitTest(plotPosition);
      if (hits.isNotEmpty) x = hits.first.x;
    }
    final double? y = view.scales.containsKey(widget.yScale)
        ? view.scale(widget.yScale).toValue(plotPosition.dy)
        : null;
    _controller.focus.value = ChartFocus(x: x, y: y, source: _controller);
  }

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
              final bool same = _sticky && before != null && before.x == _controller.focus.value?.x;
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
    final double x = view.scale(xScale).toPixel(focus.x);
    if (vertical && x >= 0 && x <= view.size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, view.size.height), line);
    }
    final double? focusY = focus.y;
    if (horizontal &&
        focusY != null &&
        identical(focus.source, controller) &&
        view.scales.containsKey(yScale)) {
      final double y = view.scale(yScale).toPixel(focusY);
      canvas.drawLine(Offset(0, y), Offset(view.size.width, y), line);
    }
    if (!showPoints) return;
    for (final ChartHit hit in controller.hitsAt(focus.x, xScale: xScale, view: view)) {
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
        final double? value = focus == null
            ? null
            : (horizontal ? focus.x : (identical(focus.source, controller) ? focus.y : null));
        if (value == null) return const SizedBox.shrink();
        return ChartAxisMarker(value: value, clamp: false, child: builder(context, value));
      },
    );
  }
}
