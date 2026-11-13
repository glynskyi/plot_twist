import 'package:flutter/widgets.dart';

import '../core/chart_controller.dart';
import '../core/chart_view.dart';
import '../core/scale.dart';
import '../interaction/pointer_hub.dart';
import '../rendering/render_chart_layout.dart';
import '../rendering/view_channel.dart';
import 'chart_scope.dart';
import 'chart_stack.dart';

/// A chart: a plot area whose children share one data-space coordinate
/// system, surrounded by optional docks for axes and other chrome.
///
/// Everything in a chart is an ordinary widget:
///
///  * [children] are stacked over the plot. Series, grids and behaviors fill
///    it; `ChartPositioned` children are placed from data coordinates; any
///    other widget is simply laid out over the plot, like in a `Stack`.
///  * [left], [top], [right] and [bottom] dock widgets beside the plot —
///    usually `ChartAxis`, but any widget works. Lists are in visual order.
///  * [x], [y] and [scales] configure the dimensions. The live visible window
///    belongs to the [controller]; passing an equal scale on rebuild never
///    resets it.
///
/// A chart fills the space it is given. Panning and zooming are opt-in: add a
/// `ChartPanZoom` to [children].
class Chart extends StatefulWidget {
  /// Creates a chart.
  const Chart({
    super.key,
    this.controller,
    this.x = const LinearScale(),
    this.y = const LinearScale(),
    this.scales = const <Object, ChartScale>{},
    this.xScales = const <Object, ChartScale>{},
    this.left = const <Widget>[],
    this.top = const <Widget>[],
    this.right = const <Widget>[],
    this.bottom = const <Widget>[],
    this.children = const <Widget>[],
    this.isolate = true,
    this.fallbackSize = const Size(320, 200),
    this.semanticLabel,
  });

  /// Controls and observes the chart. Created internally when null.
  final ChartController? controller;

  /// The default horizontal scale, with id [kChartX].
  final ChartScale x;

  /// The default vertical scale, with id [kChartY].
  final ChartScale y;

  /// Additional vertical scales by id — for example a second Y axis.
  final Map<Object, ChartScale> scales;

  /// Additional horizontal scales by id.
  final Map<Object, ChartScale> xScales;

  /// Widgets docked left of the plot, from the outside in.
  final List<Widget> left;

  /// Widgets docked above the plot, from the outside in.
  final List<Widget> top;

  /// Widgets docked right of the plot, from the plot outwards.
  final List<Widget> right;

  /// Widgets docked below the plot, from the plot outwards.
  final List<Widget> bottom;

  /// The layers of the plot, painted in order (later children on top).
  final List<Widget> children;

  /// Whether the chart paints into its own compositing layer. Turn off when
  /// showing very many small charts.
  final bool isolate;

  /// The size used along an axis in which the chart is unconstrained.
  final Size fallbackSize;

  /// A description of the chart for assistive technologies.
  final String? semanticLabel;

  @override
  State<Chart> createState() => _ChartState();
}

class _ChartState extends State<Chart> with TickerProviderStateMixin {
  final ChartViewChannel _channel = ChartViewChannel();
  final ChartPointerHub _hub = ChartPointerHub();
  ChartController? _ownController;
  late ChartController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? (_ownController = ChartController());
    _controller.attachVsync(this);
    _configure();
  }

  @override
  void didUpdateWidget(Chart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ChartController next = widget.controller ?? (_ownController ??= ChartController());
    if (!identical(next, _controller)) {
      _controller.detachVsync(this);
      _controller = next;
      _controller.attachVsync(this);
    }
    _configure();
  }

  void _configure() {
    _controller.configure(<Object, ChartScale>{
      kChartX: widget.x,
      kChartY: widget.y,
      ...widget.scales,
      ...widget.xScales,
    });
  }

  @override
  void dispose() {
    _controller.detachVsync(this);
    _ownController?.dispose();
    super.dispose();
  }

  static Widget _dock(ChartSide side, Widget child) => _ChartSlot(
    side: side,
    child: ChartDockScope(side: side, child: child),
  );

  @override
  Widget build(BuildContext context) {
    Widget result = ChartScope(
      controller: _controller,
      channel: _channel,
      hub: _hub,
      child: _ChartLayout(
        controller: _controller,
        channel: _channel,
        hub: _hub,
        horizontalScales: <Object>{kChartX, ...widget.xScales.keys},
        isolate: widget.isolate,
        fallbackSize: widget.fallbackSize,
        children: <Widget>[
          for (final Widget w in widget.left) _dock(ChartSide.left, w),
          for (final Widget w in widget.top) _dock(ChartSide.top, w),
          for (final Widget w in widget.right) _dock(ChartSide.right, w),
          for (final Widget w in widget.bottom) _dock(ChartSide.bottom, w),
          _ChartSlot(side: null, child: ChartStack(children: widget.children)),
        ],
      ),
    );
    final String? label = widget.semanticLabel;
    if (label != null) {
      result = Semantics(container: true, label: label, child: result);
    }
    return result;
  }
}

class _ChartSlot extends ParentDataWidget<ChartLayoutParentData> {
  const _ChartSlot({required this.side, required super.child});

  final ChartSide? side;

  @override
  void applyParentData(RenderObject renderObject) {
    final ChartLayoutParentData data = renderObject.parentData! as ChartLayoutParentData;
    if (data.side != side) {
      data.side = side;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _ChartLayout;
}

class _ChartLayout extends MultiChildRenderObjectWidget {
  const _ChartLayout({
    required this.controller,
    required this.channel,
    required this.hub,
    required this.horizontalScales,
    required this.isolate,
    required this.fallbackSize,
    super.children,
  });

  final ChartController controller;
  final ChartViewChannel channel;
  final ChartPointerHub hub;
  final Set<Object> horizontalScales;
  final bool isolate;
  final Size fallbackSize;

  @override
  RenderChartLayout createRenderObject(BuildContext context) => RenderChartLayout(
    controller: controller,
    channel: channel,
    hub: hub,
    horizontalScales: horizontalScales,
    isolate: isolate,
    fallbackSize: fallbackSize,
  );

  @override
  void updateRenderObject(BuildContext context, RenderChartLayout renderObject) {
    renderObject
      ..controller = controller
      ..channel = channel
      ..hub = hub
      ..horizontalScales = horizontalScales
      ..isolate = isolate
      ..fallbackSize = fallbackSize;
  }
}
