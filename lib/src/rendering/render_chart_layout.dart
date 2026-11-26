import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/chart_controller.dart';
import '../core/chart_view.dart';
import '../core/scale_controller.dart';
import '../interaction/pointer_hub.dart';
import 'view_channel.dart';

/// A side of the plot area that can hold docked widgets such as axes.
enum ChartSide {
  /// Left of the plot.
  left,

  /// Above the plot.
  top,

  /// Right of the plot.
  right,

  /// Below the plot.
  bottom;

  /// Whether docks on this side run along the horizontal edge of the plot.
  bool get isHorizontal => this == top || this == bottom;
}

/// Parent data of the children of [RenderChartLayout].
class ChartLayoutParentData extends ContainerBoxParentData<RenderBox> {
  /// The side the child is docked to; null for the plot itself.
  ChartSide? side;
}

/// The root render object of a chart.
///
/// It lays out the docks around the plot, resolves the [ChartView] for the
/// frame, publishes it through the [ChartViewChannel] and routes pointer
/// events to the [ChartPointerHub].
class RenderChartLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ChartLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, ChartLayoutParentData>
    implements MouseTrackerAnnotation {
  /// Creates the root render object of a chart.
  RenderChartLayout({
    required ChartController controller,
    required ChartViewChannel channel,
    required ChartPointerHub hub,
    Set<Object> horizontalScales = const <Object>{kChartX},
    bool isolate = true,
    Size fallbackSize = const Size(320, 200),
  }) : _controller = controller,
       _channel = channel,
       _hub = hub,
       _horizontalScales = horizontalScales,
       _isolate = isolate,
       _fallbackSize = fallbackSize;

  // Number of charts currently inside performLayout. While it is positive no
  // other chart may be marked dirty.
  static int _layoutDepth = 0;

  /// The controller whose scales this chart shows.
  ChartController get controller => _controller;
  ChartController _controller;
  set controller(ChartController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.removeRenderListener(_handleControllerChanged);
    _controller = value;
    if (attached) _controller.addRenderListener(_handleControllerChanged);
    markNeedsLayout();
  }

  /// The channel the view is published on.
  ChartViewChannel get channel => _channel;
  ChartViewChannel _channel;
  set channel(ChartViewChannel value) {
    if (identical(value, _channel)) return;
    _channel = value;
    markNeedsLayout();
  }

  /// The hub pointer events are routed to.
  ChartPointerHub get hub => _hub;
  ChartPointerHub _hub;
  set hub(ChartPointerHub value) {
    if (identical(value, _hub)) return;
    if (attached) _hub.onChanged = null;
    _hub = value;
    if (attached) _hub.onChanged = _handleHubChanged;
  }

  /// Ids of the scales that run horizontally. All others run vertically.
  Set<Object> get horizontalScales => _horizontalScales;
  Set<Object> _horizontalScales;
  set horizontalScales(Set<Object> value) {
    if (setEquals(value, _horizontalScales)) return;
    _horizontalScales = value;
    markNeedsLayout();
  }

  /// Whether the chart paints into its own layer.
  bool get isolate => _isolate;
  bool _isolate;
  set isolate(bool value) {
    if (value == _isolate) return;
    _isolate = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// The size used along an axis in which the chart is unconstrained.
  Size get fallbackSize => _fallbackSize;
  Size _fallbackSize;
  set fallbackSize(Size value) {
    if (value == _fallbackSize) return;
    _fallbackSize = value;
    markNeedsLayout();
  }

  EdgeInsets _gutters = EdgeInsets.zero;
  Rect _plotRect = Rect.zero;
  bool _deferredDirtyScheduled = false;
  // Whether a gesture or animation was moving a scale at the last layout, and
  // whether the next publish must reach the dependents although the view is
  // unchanged.
  bool _wasInteracting = false;
  bool _forcePublish = false;

  /// The plot area in this render object's coordinates.
  Rect get plotRect => _plotRect;

  @override
  bool get isRepaintBoundary => _isolate;

  @override
  bool get sizedByParent => true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ChartLayoutParentData) child.parentData = ChartLayoutParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addRenderListener(_handleControllerChanged);
    _hub.onChanged = _handleHubChanged;
  }

  @override
  void detach() {
    _controller.removeRenderListener(_handleControllerChanged);
    _hub.onChanged = null;
    super.detach();
  }

  void _handleHubChanged() {
    if (attached) markNeedsPaint(); // Refreshes mouse tracking on the next frame.
  }

  void _handleControllerChanged() {
    if (!attached) return;
    if (_layoutDepth > 0) {
      // Something changed while a chart was laying out (for example a series
      // was built lazily). Dirtying render objects now is illegal, so do it
      // right after this frame.
      if (_deferredDirtyScheduled) return;
      _deferredDirtyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        _deferredDirtyScheduled = false;
        if (attached) markNeedsLayout();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
      return;
    }
    markNeedsLayout();
  }

  // ------------------------------------------------------------- layout

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    Size(
      constraints.hasBoundedWidth ? constraints.maxWidth : _fallbackSize.width,
      constraints.hasBoundedHeight ? constraints.maxHeight : _fallbackSize.height,
    ),
  );

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _fallbackSize.width;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => _fallbackSize.height;

  ChartView _buildView(Size plotSize, EdgeInsets gutters) {
    final Map<Object, ChartScaleView> scales = <Object, ChartScaleView>{};
    for (final Object id in _controller.scaleIds.toList(growable: false)) {
      final ChartScaleController c = _controller.scale(id);
      final bool horizontal = _horizontalScales.contains(id);
      scales[id] = ChartScaleView(
        id: id,
        scale: c.scale,
        scaledMin: c.scaledMin,
        scaledMax: c.scaledMax,
        extent: horizontal ? plotSize.width : plotSize.height,
        direction: horizontal ? Axis.horizontal : Axis.vertical,
      );
    }
    return ChartView(
      size: plotSize,
      chartRect: Rect.fromLTWH(-gutters.left, -gutters.top, size.width, size.height),
      scales: scales,
    );
  }

  void _publish(Size plotSize, EdgeInsets gutters) {
    _channel.publish(
      _buildView(plotSize, gutters),
      (VoidCallback callback) => invokeLayoutCallback<BoxConstraints>((_) => callback()),
      force: _forcePublish,
    );
    _forcePublish = false;
  }

  @override
  void performLayout() {
    // Axes keep their gutter while a gesture or animation runs, so the plot
    // does not twitch. When it ends the view may be just as it was; tell the
    // axes anyway, so a gutter can shrink to its labels.
    final bool interacting = _controller.isInteracting;
    _forcePublish = _wasInteracting && !interacting;
    _wasInteracting = interacting;
    _layoutDepth++;
    try {
      int revision = _controller.revision;
      _layoutChildren();
      // A series built lazily during layout may have changed automatic
      // ranges; run once more so this frame is already consistent.
      if (_controller.revision != revision) {
        revision = _controller.revision;
        _layoutChildren();
      }
    } finally {
      _layoutDepth--;
    }
    _controller.commitView(_channel.view);
  }

  void _layoutChildren() {
    final List<RenderBox> lefts = <RenderBox>[];
    final List<RenderBox> tops = <RenderBox>[];
    final List<RenderBox> rights = <RenderBox>[];
    final List<RenderBox> bottoms = <RenderBox>[];
    RenderBox? plot;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      switch ((child.parentData! as ChartLayoutParentData).side) {
        case ChartSide.left:
          lefts.add(child);
        case ChartSide.top:
          tops.add(child);
        case ChartSide.right:
          rights.add(child);
        case ChartSide.bottom:
          bottoms.add(child);
        case null:
          plot = child;
      }
    }

    double measureHorizontal(List<RenderBox> docks, double width) {
      double total = 0;
      for (final RenderBox dock in docks) {
        dock.layout(
          BoxConstraints(minWidth: width, maxWidth: width, maxHeight: size.height),
          parentUsesSize: true,
        );
        total += dock.size.height;
      }
      return total;
    }

    double measureVertical(List<RenderBox> docks, double height) {
      double total = 0;
      for (final RenderBox dock in docks) {
        dock.layout(
          BoxConstraints(minHeight: height, maxHeight: height, maxWidth: size.width),
          parentUsesSize: true,
        );
        total += dock.size.width;
      }
      return total;
    }

    Size plotSizeFor(EdgeInsets g) =>
        Size(math.max(0, size.width - g.horizontal), math.max(0, size.height - g.vertical));

    // Start from last frame's gutters: while they do not change, one pass is
    // enough. Docks are measured against the published view, so iterate until
    // the plot size they imply is the one they were measured with.
    EdgeInsets gutters = _gutters;
    Size plotSize = plotSizeFor(gutters);
    bool converged = false;
    for (int pass = 0; pass < 3 && !converged; pass++) {
      _publish(plotSize, gutters);
      final double top = measureHorizontal(tops, plotSize.width);
      final double bottom = measureHorizontal(bottoms, plotSize.width);
      final double plotHeight = math.max(0, size.height - top - bottom);
      final double left = measureVertical(lefts, plotHeight);
      final double right = measureVertical(rights, plotHeight);
      final EdgeInsets measured = EdgeInsets.fromLTRB(left, top, right, bottom);
      final Size measuredPlot = plotSizeFor(measured);
      converged = measuredPlot == plotSize && measured == gutters;
      gutters = measured;
      plotSize = measuredPlot;
    }
    if (!converged) {
      // Out of passes: settle on the last measurement. Everything dirtied by
      // this publish still gets laid out; dock sizes are taken as they come.
      _publish(plotSize, gutters);
      measureHorizontal(tops, plotSize.width);
      measureHorizontal(bottoms, plotSize.width);
      measureVertical(lefts, plotSize.height);
      measureVertical(rights, plotSize.height);
    }
    _gutters = gutters;
    _plotRect = Offset(gutters.left, gutters.top) & plotSize;

    plot?.layout(BoxConstraints.tight(plotSize));

    // Position children. Lists are in visual order: left to right, top to
    // bottom.
    double x = 0;
    for (final RenderBox dock in lefts) {
      (dock.parentData! as ChartLayoutParentData).offset = Offset(x, gutters.top);
      x += dock.size.width;
    }
    x = _plotRect.right;
    for (final RenderBox dock in rights) {
      (dock.parentData! as ChartLayoutParentData).offset = Offset(x, gutters.top);
      x += dock.size.width;
    }
    double y = 0;
    for (final RenderBox dock in tops) {
      (dock.parentData! as ChartLayoutParentData).offset = Offset(gutters.left, y);
      y += dock.size.height;
    }
    y = _plotRect.bottom;
    for (final RenderBox dock in bottoms) {
      (dock.parentData! as ChartLayoutParentData).offset = Offset(gutters.left, y);
      y += dock.size.height;
    }
    if (plot != null) (plot.parentData! as ChartLayoutParentData).offset = _plotRect.topLeft;
  }

  // -------------------------------------------------------------- paint

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  // ------------------------------------------------------- hit testing

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The plot may host widgets that overflow into the gutters, so children
    // are tested even where this box has no visible content of its own.
    final bool hitChild = hitTestChildren(result, position: position);
    if (hitChild || (_hub.hasHandlers && size.contains(position))) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  ChartRegion _regionAt(Offset position) {
    if (_plotRect.contains(position)) return ChartRegion.plot;
    final bool insideX = position.dx >= _plotRect.left && position.dx < _plotRect.right;
    final bool insideY = position.dy >= _plotRect.top && position.dy < _plotRect.bottom;
    if (insideY) return position.dx < _plotRect.left ? ChartRegion.left : ChartRegion.right;
    if (insideX) return position.dy < _plotRect.top ? ChartRegion.top : ChartRegion.bottom;
    return ChartRegion.corner;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (!_hub.hasHandlers) return;
    final Offset local = globalToLocal(event.position);
    final ChartRegion region = _regionAt(local);
    _hub.dispatch(
      ChartPointerEvent(
        event: event,
        plotPosition: local - _plotRect.topLeft,
        region: region,
        axisScale: region == ChartRegion.plot ? null : _hub.axisScaleAt(event.position),
      ),
    );
  }

  // --------------------------------------------- MouseTrackerAnnotation

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => _handleExit;

  void _handleExit(PointerExitEvent event) => _hub.dispatchExit();

  @override
  MouseCursor get cursor => MouseCursor.defer;

  @override
  bool get validForMouseTracker => attached && _hub.wantsHover;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect>('plotRect', _plotRect));
    properties.add(DiagnosticsProperty<EdgeInsets>('gutters', _gutters));
  }
}
