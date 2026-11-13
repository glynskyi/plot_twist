import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/chart_view.dart';
import '../rendering/view_channel.dart';
import 'chart_scope.dart';

/// Builds widgets from the chart's view, at layout time, and rebuilds them
/// only when a value selected from the view changes.
///
/// [selector] picks what the subtree depends on — the visible tick set, the
/// indices of the visible markers, the data under the pointer. [builder] runs
/// when that value changes (by `==`), not on every pan frame. To move widgets
/// with the data in between rebuilds, return a `ChartStack` of
/// `ChartPositioned` children.
///
/// Works anywhere below a `Chart`.
class ChartLayoutBuilder<T> extends AbstractLayoutBuilder<T> {
  /// Creates a builder that depends on `selector(view)`.
  const ChartLayoutBuilder({super.key, required this.selector, required this.builder});

  /// Picks the value the built subtree depends on. Must be cheap and must
  /// return values with meaningful equality.
  final T Function(ChartView view) selector;

  @override
  final Widget Function(BuildContext context, T value) builder;

  @override
  RenderChartLayoutBuilder<T> createRenderObject(BuildContext context) =>
      RenderChartLayoutBuilder<T>(selector: selector, channel: ChartScope.of(context).channel);

  @override
  void updateRenderObject(BuildContext context, RenderChartLayoutBuilder<T> renderObject) {
    renderObject
      ..selector = selector
      ..channel = ChartScope.of(context).channel;
  }
}

/// Builds widgets from the chart's [ChartView], rebuilding on every change of
/// the view (every pan or zoom frame).
///
/// Prefer [ChartLayoutBuilder] with a narrow selector when the subtree only
/// depends on part of the view.
class ChartViewBuilder extends StatelessWidget {
  /// Creates a builder that depends on the whole view.
  const ChartViewBuilder({super.key, required this.builder});

  /// Builds the subtree for [view].
  final Widget Function(BuildContext context, ChartView view) builder;

  static ChartView _identity(ChartView view) => view;

  @override
  Widget build(BuildContext context) =>
      ChartLayoutBuilder<ChartView>(selector: _identity, builder: builder);
}

/// The render object of [ChartLayoutBuilder].
class RenderChartLayoutBuilder<T> extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<T, RenderBox>,
        ChartViewDependent {
  /// Creates the render object of a [ChartLayoutBuilder].
  RenderChartLayoutBuilder({required this.selector, ChartViewChannel? channel}) {
    this.channel = channel;
  }

  /// Picks the value the subtree depends on.
  T Function(ChartView view) selector;

  T? _selected;
  bool _hasSelected = false;

  @override
  T get layoutInfo => _selected as T;

  @override
  void didChangeChartView(ChartView? oldView, ChartView newView) {
    if (!_hasSelected || selector(newView) != _selected) markNeedsLayout();
  }

  @override
  void performLayout() {
    _selected = selector(chartView);
    _hasSelected = true;
    runLayoutCallback();
    final RenderBox? child = this.child;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = constraints.biggest;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(
      debugCannotComputeDryLayout(
        reason:
            'A ChartLayoutBuilder builds its child during layout, so its size '
            'cannot be computed without laying it out.',
      ),
    );
    return Size.zero;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child?.getDistanceToActualBaseline(baseline);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The child may be a chart stack with widgets outside this box.
    if (child?.hitTest(result, position: position) ?? false) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child != null) context.paintChild(child, offset);
  }
}
