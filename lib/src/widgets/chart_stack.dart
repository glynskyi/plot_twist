import 'package:flutter/widgets.dart';

import '../core/chart_view.dart';
import '../rendering/render_chart_stack.dart';
import 'chart_scope.dart';

/// A stack over the plot area of a chart.
///
/// Children fill the plot unless wrapped in [ChartPositioned], which places
/// them from data coordinates. A `Chart` puts its `children` in a
/// `ChartStack`; use one yourself to return several positioned widgets from a
/// builder. A `ChartStack` must cover the plot area exactly.
class ChartStack extends MultiChildRenderObjectWidget {
  /// Creates a chart stack.
  const ChartStack({super.key, super.children});

  @override
  RenderChartStack createRenderObject(BuildContext context) =>
      RenderChartStack(channel: ChartScope.of(context).channel);

  @override
  void updateRenderObject(BuildContext context, RenderChartStack renderObject) {
    renderObject.channel = ChartScope.of(context).channel;
  }
}

/// Places a widget in a chart from data coordinates.
///
/// The position is recomputed during layout whenever the chart is panned,
/// zoomed or resized — the [child] is not rebuilt.
///
/// ```dart
/// // A chip sitting on a data point.
/// ChartPositioned(x: .value(12), y: .value(3.4), alignment: .bottomCenter, child: chip)
///
/// // Pinned to the right edge of the plot at a data height.
/// ChartPositioned(x: .end, y: .value(last), overflow: .visible, child: pill)
///
/// // Stretched over a data range (null edges are the plot's edges).
/// ChartPositioned.span(x1: .value(from), x2: .value(to), child: shade)
///
/// // Anywhere the view says.
/// ChartPositioned.resolve(position: (view) => view.toPixel(x, f(x)), child: dot)
/// ```
class ChartPositioned extends ParentDataWidget<ChartStackParentData> {
  /// Places [child] at the point `(x, y)`.
  ///
  /// [alignment] says which point of the child sits on the anchor:
  /// `Alignment.bottomCenter` puts the child above it.
  const ChartPositioned({
    super.key,
    ChartAnchor this.x = ChartAnchor.center,
    ChartAnchor this.y = ChartAnchor.center,
    this.alignment = Alignment.center,
    this.offset = Offset.zero,
    this.fit = ChartPositionedFit.none,
    this.overflow = ChartOverflow.hide,
    this.xScale = kChartX,
    this.yScale = kChartY,
    required super.child,
  }) : x2 = null,
       y2 = null,
       position = null,
       _isSpan = false;

  /// Stretches [child] over the rectangle between the given edges. Null edges
  /// are the edges of the plot.
  const ChartPositioned.span({
    super.key,
    ChartAnchor? x1,
    this.x2,
    ChartAnchor? y1,
    this.y2,
    this.overflow = ChartOverflow.clip,
    this.xScale = kChartX,
    this.yScale = kChartY,
    required super.child,
  }) : x = x1,
       y = y1,
       position = null,
       alignment = Alignment.center,
       offset = Offset.zero,
       fit = ChartPositionedFit.none,
       _isSpan = true;

  /// Places [child] where [position] says, given the current view. Return
  /// null from [position] to hide the child.
  const ChartPositioned.resolve({
    super.key,
    required ChartPositionResolver this.position,
    this.alignment = Alignment.center,
    this.offset = Offset.zero,
    this.fit = ChartPositionedFit.none,
    this.overflow = ChartOverflow.hide,
    required super.child,
  }) : x = null,
       y = null,
       x2 = null,
       y2 = null,
       xScale = kChartX,
       yScale = kChartY,
       _isSpan = false;

  /// Horizontal anchor, or the left edge of a span.
  final ChartAnchor? x;

  /// Vertical anchor, or the top edge of a span.
  final ChartAnchor? y;

  /// Right edge of a span.
  final ChartAnchor? x2;

  /// Bottom edge of a span.
  final ChartAnchor? y2;

  /// Computes the position from the view, instead of [x] and [y].
  final ChartPositionResolver? position;

  /// Which point of the child sits on the anchor.
  final Alignment alignment;

  /// Extra shift in logical pixels.
  final Offset offset;

  /// How the child is kept inside the plot.
  final ChartPositionedFit fit;

  /// What happens when the child leaves the plot.
  final ChartOverflow overflow;

  /// Scale used for horizontal anchors.
  final Object xScale;

  /// Scale used for vertical anchors.
  final Object yScale;

  final bool _isSpan;

  ChartPlacement get _placement {
    if (_isSpan) {
      return ChartPlacement.span(
        x: x,
        x2: x2,
        y: y,
        y2: y2,
        overflow: overflow,
        xScale: xScale,
        yScale: yScale,
      );
    }
    final ChartPositionResolver? resolver = position;
    if (resolver != null) {
      return ChartPlacement.resolve(
        resolver: resolver,
        alignment: alignment,
        offset: offset,
        fit: fit,
        overflow: overflow,
      );
    }
    return ChartPlacement.point(
      x: x!,
      y: y!,
      alignment: alignment,
      offset: offset,
      fit: fit,
      overflow: overflow,
      xScale: xScale,
      yScale: yScale,
    );
  }

  @override
  void applyParentData(RenderObject renderObject) {
    final ChartStackParentData data = renderObject.parentData! as ChartStackParentData;
    final ChartPlacement placement = _placement;
    if (data.placement != placement) {
      data.placement = placement;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => ChartStack;
}
