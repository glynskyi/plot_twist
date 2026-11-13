import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Builds the content of a tooltip for the data points the user points at.
typedef ChartTooltipBuilder = Widget Function(BuildContext context, List<ChartHit> hits);

/// Shows a widget next to the data the user points at.
///
/// The tooltip follows `ChartController.focus` (set by `ChartCrosshair`, or by
/// your own code). Its content is an ordinary widget built by [builder] — it
/// can hold images, charts or buttons — and is rebuilt only when the
/// pointed-at data changes; while the chart is panned it just moves.
///
/// It flips to the other side of the point when it would leave the plot. With
/// [overlay] it is shown in the app's `Overlay` instead, so it can extend
/// beyond the chart and is never clipped by it.
class ChartTooltip extends StatelessWidget {
  /// Creates a tooltip.
  const ChartTooltip({
    super.key,
    this.builder,
    this.xScale = kChartX,
    this.alignment = Alignment.bottomCenter,
    this.offset = const Offset(0, -12),
    this.interactive = false,
    this.overlay = false,
  });

  /// Builds the content. Defaults to a compact list of series values.
  final ChartTooltipBuilder? builder;

  /// Id of the horizontal scale the focus is on.
  final Object xScale;

  /// Which point of the tooltip sits on the anchor. The default puts the
  /// tooltip above the point.
  final Alignment alignment;

  /// Extra shift away from the anchor, in logical pixels.
  final Offset offset;

  /// Whether the tooltip receives pointer events (for buttons inside it).
  final bool interactive;

  /// Whether the tooltip is shown in the nearest `Overlay`.
  final bool overlay;

  static Offset? _anchor(List<ChartHit> hits) {
    if (hits.isEmpty) return null;
    // The topmost point, so the tooltip clears every series.
    ChartHit top = hits.first;
    for (final ChartHit hit in hits) {
      if (hit.position.dy < top.position.dy) top = hit;
    }
    return top.position;
  }

  @override
  Widget build(BuildContext context) {
    final ChartController controller = ChartScope.of(context).controller;
    return ValueListenableBuilder<ChartFocus?>(
      valueListenable: controller.focus,
      builder: (BuildContext context, ChartFocus? focus, Widget? child) {
        if (focus == null) return const SizedBox.shrink();
        List<ChartHit> hitsIn(ChartView view) =>
            controller.hitsAt(focus.x, xScale: xScale, view: view);
        return ChartLayoutBuilder<ChartHitSet>(
          selector: (ChartView view) => ChartHitSet(hitsIn(view)),
          builder: (BuildContext context, ChartHitSet set) {
            if (set.isEmpty) return const SizedBox.shrink();
            Widget content = (builder ?? defaultBuilder)(context, set.hits);
            if (!interactive) content = IgnorePointer(child: content);
            if (overlay) {
              return ChartStack(
                children: <Widget>[
                  ChartPositioned.resolve(
                    position: (ChartView view) => _anchor(hitsIn(view)),
                    child: _OverlayTooltip(alignment: alignment, offset: offset, child: content),
                  ),
                ],
              );
            }
            return ChartStack(
              children: <Widget>[
                ChartPositioned.resolve(
                  position: (ChartView view) => _anchor(hitsIn(view)),
                  alignment: alignment,
                  offset: offset,
                  fit: ChartPositionedFit.flip,
                  overflow: ChartOverflow.visible,
                  child: content,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The default tooltip content: one line per series.
  static Widget defaultBuilder(BuildContext context, List<ChartHit> hits) {
    final ChartThemeData theme = ChartTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.tooltipColor,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: DefaultTextStyle(
          style: theme.tooltipTextStyle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final ChartHit hit in hits)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (hit.series?.color != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SizedBox.square(
                          dimension: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: hit.series!.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    if (hit.series?.label != null) Text('${hit.series!.label}: '),
                    Text(formatNumber(hit.y)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shows [child] in the nearest Overlay, positioned relative to this widget
// (which is itself placed on the data point by the chart).
class _OverlayTooltip extends StatefulWidget {
  const _OverlayTooltip({required this.alignment, required this.offset, required this.child});

  final Alignment alignment;
  final Offset offset;
  final Widget child;

  @override
  State<_OverlayTooltip> createState() => _OverlayTooltipState();
}

class _OverlayTooltipState extends State<_OverlayTooltip> {
  final OverlayPortalController _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _portal,
    overlayChildBuilder: (BuildContext context, OverlayChildLayoutInfo info) {
      final Offset anchor = MatrixUtils.transformPoint(info.childPaintTransform, Offset.zero);
      return Positioned.fill(
        child: CustomSingleChildLayout(
          delegate: _TooltipLayout(
            anchor: anchor,
            alignment: widget.alignment,
            offset: widget.offset,
          ),
          child: widget.child,
        ),
      );
    },
    child: const SizedBox.shrink(),
  );
}

class _TooltipLayout extends SingleChildLayoutDelegate {
  const _TooltipLayout({required this.anchor, required this.alignment, required this.offset});

  final Offset anchor;
  final Alignment alignment;
  final Offset offset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    Offset place(Alignment a, Offset o) => anchor - a.alongSize(childSize) + o;
    Offset position = place(alignment, offset);
    if (position.dy < 0 || position.dy + childSize.height > size.height) {
      final Offset flipped = place(
        Alignment(alignment.x, -alignment.y),
        Offset(offset.dx, -offset.dy),
      );
      if (flipped.dy >= 0 && flipped.dy + childSize.height <= size.height) position = flipped;
    }
    if (position.dx < 0 || position.dx + childSize.width > size.width) {
      final Offset flipped = place(
        Alignment(-alignment.x, alignment.y),
        Offset(-offset.dx, offset.dy),
      );
      if (flipped.dx >= 0 && flipped.dx + childSize.width <= size.width) {
        position = Offset(flipped.dx, position.dy);
      }
    }
    return Offset(
      childSize.width <= size.width
          ? position.dx.clamp(0, size.width - childSize.width)
          : position.dx,
      childSize.height <= size.height
          ? position.dy.clamp(0, size.height - childSize.height)
          : position.dy,
    );
  }

  @override
  bool shouldRelayout(_TooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.alignment != alignment ||
      oldDelegate.offset != offset;
}
