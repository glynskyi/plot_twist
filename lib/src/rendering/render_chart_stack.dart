import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/chart_view.dart';
import 'view_channel.dart';

/// Where one coordinate of a positioned child comes from.
///
/// Mix kinds freely per dimension — for example `x: .start` with
/// `y: .value(42)` pins a widget to the left edge of the plot at a data
/// height. Subclass to add your own kind.
abstract class ChartAnchor {
  /// Const constructor for subclasses.
  const ChartAnchor();

  /// A data value on the dimension's scale.
  const factory ChartAnchor.value(double value) = ChartValueAnchor;

  /// A fraction of the plot: `0` is its left/top edge, `1` its right/bottom.
  const factory ChartAnchor.fraction(double fraction) = ChartFractionAnchor;

  /// Logical pixels from the left/top edge of the plot.
  const factory ChartAnchor.pixels(double pixels) = ChartPixelAnchor;

  /// Logical pixels from the right/bottom edge of the plot.
  const factory ChartAnchor.fromEnd(double pixels) = ChartEndAnchor;

  /// The left/top edge of the plot.
  static const ChartAnchor start = ChartFractionAnchor(0);

  /// The middle of the plot.
  static const ChartAnchor center = ChartFractionAnchor(0.5);

  /// The right/bottom edge of the plot.
  static const ChartAnchor end = ChartFractionAnchor(1);

  /// The plot-local pixel coordinate along [scale], or null to hide the child.
  double? resolve(ChartScaleView scale);
}

/// An anchor at a data value.
class ChartValueAnchor extends ChartAnchor {
  /// Creates an anchor at [value].
  const ChartValueAnchor(this.value);

  /// The data value.
  final double value;

  @override
  double? resolve(ChartScaleView scale) {
    final double pixel = scale.toPixel(value);
    return pixel.isFinite ? pixel : null;
  }

  @override
  bool operator ==(Object other) => other is ChartValueAnchor && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// An anchor at a fraction of the plot.
class ChartFractionAnchor extends ChartAnchor {
  /// Creates an anchor at [fraction] of the plot extent.
  const ChartFractionAnchor(this.fraction);

  /// `0` is the left/top edge, `1` the right/bottom edge.
  final double fraction;

  @override
  double? resolve(ChartScaleView scale) => scale.extent * fraction;

  @override
  bool operator ==(Object other) => other is ChartFractionAnchor && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;
}

/// An anchor a number of pixels from the start edge of the plot.
class ChartPixelAnchor extends ChartAnchor {
  /// Creates an anchor [pixels] from the left/top edge.
  const ChartPixelAnchor(this.pixels);

  /// Distance from the left/top edge.
  final double pixels;

  @override
  double? resolve(ChartScaleView scale) => pixels;

  @override
  bool operator ==(Object other) => other is ChartPixelAnchor && other.pixels == pixels;

  @override
  int get hashCode => pixels.hashCode;
}

/// An anchor a number of pixels from the end edge of the plot.
class ChartEndAnchor extends ChartAnchor {
  /// Creates an anchor [pixels] from the right/bottom edge.
  const ChartEndAnchor(this.pixels);

  /// Distance from the right/bottom edge.
  final double pixels;

  @override
  double? resolve(ChartScaleView scale) => scale.extent - pixels;

  @override
  bool operator ==(Object other) => other is ChartEndAnchor && other.pixels == pixels;

  @override
  int get hashCode => pixels.hashCode;
}

/// What happens to a positioned child that leaves the plot area.
enum ChartOverflow {
  /// Always painted, even over the gutters and axes.
  visible,

  /// Painted, but cut off at the edge of the plot.
  clip,

  /// Not painted at all while its anchor is outside the plot.
  hide,
}

/// How a positioned child is kept inside the plot.
enum ChartPositionedFit {
  /// Left where its anchor and alignment put it.
  none,

  /// Mirrored to the other side of its anchor when it would overflow, then
  /// shifted inside if it still does. Right for tooltips.
  flip,

  /// Shifted just enough to stay inside.
  clamp,
}

/// Computes a plot-local position from the current view. Return null to hide
/// the child.
typedef ChartPositionResolver = Offset? Function(ChartView view);

/// Where and how a child of a chart stack is placed.
@immutable
class ChartPlacement {
  /// Places a child at a point.
  const ChartPlacement.point({
    required ChartAnchor this.x,
    required ChartAnchor this.y,
    this.alignment = Alignment.center,
    this.offset = Offset.zero,
    this.fit = ChartPositionedFit.none,
    this.overflow = ChartOverflow.hide,
    this.xScale = kChartX,
    this.yScale = kChartY,
  }) : resolver = null,
       x2 = null,
       y2 = null,
       isSpan = false;

  /// Places a child at a position computed from the view.
  const ChartPlacement.resolve({
    required ChartPositionResolver this.resolver,
    this.alignment = Alignment.center,
    this.offset = Offset.zero,
    this.fit = ChartPositionedFit.none,
    this.overflow = ChartOverflow.hide,
  }) : x = null,
       y = null,
       x2 = null,
       y2 = null,
       xScale = kChartX,
       yScale = kChartY,
       isSpan = false;

  /// Stretches a child over a rectangle. Null edges are the plot's edges.
  const ChartPlacement.span({
    this.x,
    this.x2,
    this.y,
    this.y2,
    this.overflow = ChartOverflow.clip,
    this.xScale = kChartX,
    this.yScale = kChartY,
  }) : resolver = null,
       alignment = Alignment.center,
       offset = Offset.zero,
       fit = ChartPositionedFit.none,
       isSpan = true;

  /// Horizontal anchor (or left edge of a span).
  final ChartAnchor? x;

  /// Vertical anchor (or top edge of a span).
  final ChartAnchor? y;

  /// Right edge of a span.
  final ChartAnchor? x2;

  /// Bottom edge of a span.
  final ChartAnchor? y2;

  /// Callback computing the position, instead of [x] and [y].
  final ChartPositionResolver? resolver;

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

  /// Whether the child is stretched over a rectangle.
  final bool isSpan;

  @override
  bool operator ==(Object other) =>
      other is ChartPlacement &&
      other.x == x &&
      other.y == y &&
      other.x2 == x2 &&
      other.y2 == y2 &&
      other.resolver == resolver &&
      other.alignment == alignment &&
      other.offset == offset &&
      other.fit == fit &&
      other.overflow == overflow &&
      other.xScale == xScale &&
      other.yScale == yScale &&
      other.isSpan == isSpan;

  @override
  int get hashCode =>
      Object.hash(x, y, x2, y2, resolver, alignment, offset, fit, overflow, xScale, yScale, isSpan);
}

/// Parent data of the children of [RenderChartStack].
class ChartStackParentData extends ContainerBoxParentData<RenderBox> {
  /// Where the child goes; null makes it fill the plot.
  ChartPlacement? placement;

  bool _visible = true;
}

/// Lays children out over the plot area of a chart.
///
/// Children without a [ChartPlacement] fill the plot, like in a `Stack` with
/// `StackFit.expand`. Children with one are sized by themselves and placed
/// from data coordinates during layout — so when the chart is panned or
/// zoomed they move without their widgets being rebuilt.
class RenderChartStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ChartStackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, ChartStackParentData>,
        ChartViewDependent {
  /// Creates a chart stack reading the view from [channel].
  RenderChartStack({ChartViewChannel? channel}) {
    this.channel = channel;
  }

  bool _hasPlacedChildren = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ChartStackParentData) child.parentData = ChartStackParentData();
  }

  @override
  void didChangeChartView(ChartView? oldView, ChartView newView) {
    // Children that fill the plot look after themselves; only data-anchored
    // children need this stack to run layout again.
    if (_hasPlacedChildren) markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  static const double _edgeTolerance = 0.5;

  @override
  void performLayout() {
    size = constraints.biggest;
    _hasPlacedChildren = false;
    final Rect plot = Offset.zero & size;
    ChartView? view;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final ChartStackParentData data = child.parentData! as ChartStackParentData;
      final ChartPlacement? placement = data.placement;
      if (placement == null) {
        child.layout(BoxConstraints.tight(size));
        data.offset = Offset.zero;
        data._visible = true;
        continue;
      }
      _hasPlacedChildren = true;
      view ??= chartView;
      if (placement.isSpan) {
        _layoutSpan(child, data, placement, view, plot);
      } else {
        _layoutPoint(child, data, placement, view, plot);
      }
    }
  }

  void _layoutSpan(
    RenderBox child,
    ChartStackParentData data,
    ChartPlacement placement,
    ChartView view,
    Rect plot,
  ) {
    final ChartScaleView xs = view.scale(placement.xScale);
    final ChartScaleView ys = view.scale(placement.yScale);
    final double? left = placement.x == null ? plot.left : placement.x!.resolve(xs);
    final double? right = placement.x2 == null ? plot.right : placement.x2!.resolve(xs);
    final double? top = placement.y == null ? plot.top : placement.y!.resolve(ys);
    final double? bottom = placement.y2 == null ? plot.bottom : placement.y2!.resolve(ys);
    if (left == null || right == null || top == null || bottom == null) {
      child.layout(const BoxConstraints.tightFor(width: 0, height: 0));
      data._visible = false;
      return;
    }
    Rect rect = Rect.fromPoints(Offset(left, top), Offset(right, bottom));
    // Nothing outside the chart is ever visible, and huge children are costly.
    rect = rect.intersect(view.chartRect.inflate(1));
    final bool visible =
        rect.width > 0 &&
        rect.height > 0 &&
        (placement.overflow == ChartOverflow.visible || rect.overlaps(plot));
    data._visible = visible;
    if (!visible) {
      child.layout(const BoxConstraints.tightFor(width: 0, height: 0));
      return;
    }
    child.layout(BoxConstraints.tight(rect.size));
    data.offset = rect.topLeft;
  }

  void _layoutPoint(
    RenderBox child,
    ChartStackParentData data,
    ChartPlacement placement,
    ChartView view,
    Rect plot,
  ) {
    child.layout(BoxConstraints.loose(view.chartRect.size), parentUsesSize: true);
    Offset? anchor;
    final ChartPositionResolver? resolver = placement.resolver;
    if (resolver != null) {
      anchor = resolver(view);
    } else {
      final double? x = placement.x!.resolve(view.scale(placement.xScale));
      final double? y = placement.y!.resolve(view.scale(placement.yScale));
      if (x != null && y != null) anchor = Offset(x, y);
    }
    if (anchor == null || !anchor.isFinite) {
      data._visible = false;
      return;
    }
    if (placement.overflow == ChartOverflow.hide &&
        !plot.inflate(_edgeTolerance).contains(anchor)) {
      data._visible = false;
      return;
    }
    data._visible = true;
    final Size childSize = child.size;
    Offset topLeftFor(Alignment alignment, Offset offset) =>
        anchor! - alignment.alongSize(childSize) + offset;

    Offset topLeft = topLeftFor(placement.alignment, placement.offset);
    if (placement.fit != ChartPositionedFit.none) {
      if (placement.fit == ChartPositionedFit.flip) {
        Alignment alignment = placement.alignment;
        Offset offset = placement.offset;
        if (topLeft.dx < plot.left || topLeft.dx + childSize.width > plot.right) {
          final Offset flipped = topLeftFor(
            Alignment(-alignment.x, alignment.y),
            Offset(-offset.dx, offset.dy),
          );
          if (flipped.dx >= plot.left && flipped.dx + childSize.width <= plot.right) {
            alignment = Alignment(-alignment.x, alignment.y);
            offset = Offset(-offset.dx, offset.dy);
          }
        }
        topLeft = topLeftFor(alignment, offset);
        if (topLeft.dy < plot.top || topLeft.dy + childSize.height > plot.bottom) {
          final Offset flipped = topLeftFor(
            Alignment(alignment.x, -alignment.y),
            Offset(offset.dx, -offset.dy),
          );
          if (flipped.dy >= plot.top && flipped.dy + childSize.height <= plot.bottom) {
            alignment = Alignment(alignment.x, -alignment.y);
            offset = Offset(offset.dx, -offset.dy);
          }
        }
        topLeft = topLeftFor(alignment, offset);
      }
      // Shift inside when the child fits at all.
      double dx = topLeft.dx;
      double dy = topLeft.dy;
      if (childSize.width <= plot.width) {
        dx = dx.clamp(plot.left, plot.right - childSize.width);
      }
      if (childSize.height <= plot.height) {
        dy = dy.clamp(plot.top, plot.bottom - childSize.height);
      }
      topLeft = Offset(dx, dy);
    }
    data.offset = topLeft;
  }

  @override
  bool paintsChild(RenderBox child) => (child.parentData! as ChartStackParentData)._visible;

  @override
  void paint(PaintingContext context, Offset offset) {
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final ChartStackParentData data = child.parentData! as ChartStackParentData;
      if (!data._visible) continue;
      if (data.placement?.overflow == ChartOverflow.clip) {
        final RenderBox clipped = child;
        context.pushClipRect(
          needsCompositing,
          offset,
          Offset.zero & size,
          (PaintingContext context, Offset offset) =>
              context.paintChild(clipped, data.offset + offset),
        );
      } else {
        context.paintChild(child, data.offset + offset);
      }
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Placed children may sit outside this box (in a gutter), so the usual
    // bounds check is skipped.
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final bool inside = size.contains(position);
    for (RenderBox? child = lastChild; child != null; child = childBefore(child)) {
      final ChartStackParentData data = child.parentData! as ChartStackParentData;
      if (!data._visible) continue;
      final ChartPlacement? placement = data.placement;
      if (!inside && (placement == null || placement.overflow == ChartOverflow.clip)) continue;
      final bool isHit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            child!.hitTest(result, position: transformed),
      );
      if (isHit) return true;
    }
    return false;
  }
}
