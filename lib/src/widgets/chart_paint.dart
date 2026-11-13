import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/chart_controller.dart';
import '../core/chart_view.dart';
import '../core/range.dart';
import '../core/series.dart';
import '../rendering/view_channel.dart';
import 'chart_scope.dart';

/// What a [ChartPainter] paints with.
class ChartPaintContext {
  /// Creates a paint context.
  ChartPaintContext({required this.canvas, required this.view});

  /// The canvas, with its origin at the top-left corner of the plot.
  final Canvas canvas;

  /// The chart's view for this frame.
  final ChartView view;

  /// Size of the plot area.
  Size get size => view.size;
}

/// Paints one layer of a chart, like a `CustomPainter` that knows the chart's
/// coordinate system.
///
/// The layer is repainted when the chart's view changes, when [shouldRepaint]
/// says a new painter differs, and when the `repaint` listenable fires.
abstract class ChartPainter extends Listenable {
  /// Creates a painter that repaints whenever [repaint] notifies.
  const ChartPainter({Listenable? repaint}) : _repaint = repaint;

  final Listenable? _repaint;

  @override
  void addListener(VoidCallback listener) => _repaint?.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _repaint?.removeListener(listener);

  /// Paints the layer. Use `context.view` to turn data into pixels.
  void paint(ChartPaintContext context);

  /// Whether this painter paints differently from [oldDelegate].
  bool shouldRepaint(covariant ChartPainter oldDelegate);

  /// Whether a pointer at the plot-local [position] hits something this
  /// painter drew. Returning true stops layers underneath from being hit.
  bool hitTest(Offset position, ChartView view) => false;
}

/// A [ChartPainter] that draws data.
///
/// Implementing the data methods is what plugs a custom series into the rest
/// of the chart: [bounds] feeds automatic ranges, [collectHits] feeds
/// tooltips, crosshairs and selection, [valueAt] lets overlays follow the
/// drawn curve.
abstract class ChartSeriesPainter extends ChartPainter {
  /// Creates a series painter plotted on [xScale] and [yScale].
  ///
  /// [data] notifies when the data changes: the layer is repainted and
  /// automatic ranges are recomputed. [repaint] only repaints.
  const ChartSeriesPainter({
    super.repaint,
    Listenable? data,
    this.xScale = kChartX,
    this.yScale = kChartY,
  }) : _data = data;

  final Listenable? _data;

  /// Id of the horizontal scale.
  final Object xScale;

  /// Id of the vertical scale.
  final Object yScale;

  /// The extent of the data, optionally restricted to what lies inside
  /// [xWindow] or [yWindow].
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow});

  /// The y value of the drawn series at [x], or null.
  double? valueAt(double x) => null;

  /// Adds the data points matching [query] to [hits].
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {}

  /// Whether the data extent may differ from [oldDelegate]'s. Defaults to
  /// [shouldRepaint].
  bool shouldRescale(covariant ChartSeriesPainter oldDelegate) => shouldRepaint(oldDelegate);
}

/// A layer of a chart painted by a [ChartPainter].
///
/// With a [ChartSeriesPainter] the layer also registers as a series, using
/// [id], [label] and [color] as its metadata.
class ChartPaint extends LeafRenderObjectWidget {
  /// Creates a painted chart layer.
  const ChartPaint({
    super.key,
    required this.painter,
    this.id,
    this.label,
    this.color,
    this.visible = true,
    this.clip = true,
    this.isolate = true,
  });

  /// The delegate that paints the layer.
  final ChartPainter painter;

  /// Whether the layer is shown. A hidden series stays in
  /// `ChartController.series` but is not painted, hit or auto-ranged.
  final bool visible;

  /// Identifier of the series, for `ChartController.seriesById`.
  final Object? id;

  /// Name of the series, for legends and tooltips.
  final String? label;

  /// Representative colour of the series, for legends and tooltips.
  final Color? color;

  /// Whether painting is clipped to the plot area.
  final bool clip;

  /// Whether the layer gets its own compositing layer, so repainting it does
  /// not repaint its siblings. Turn off for very many tiny charts.
  final bool isolate;

  @override
  RenderChartPaint createRenderObject(BuildContext context) {
    final ChartScope scope = ChartScope.of(context);
    return RenderChartPaint(
      painter: painter,
      controller: scope.controller,
      channel: scope.channel,
      id: id,
      label: label,
      color: color,
      visible: visible,
      clip: clip,
      isolate: isolate,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderChartPaint renderObject) {
    final ChartScope scope = ChartScope.of(context);
    renderObject
      ..controller = scope.controller
      ..channel = scope.channel
      ..painter = painter
      ..setMetadata(id: id, label: label, color: color)
      ..visible = visible
      ..clip = clip
      ..isolate = isolate;
  }
}

/// The render object of [ChartPaint].
class RenderChartPaint extends RenderBox with ChartViewDependent implements ChartSeries {
  /// Creates the render object of a [ChartPaint].
  RenderChartPaint({
    required ChartPainter painter,
    required ChartController controller,
    ChartViewChannel? channel,
    Object? id,
    String? label,
    Color? color,
    bool visible = true,
    bool clip = true,
    bool isolate = true,
  }) : _painter = painter,
       _controller = controller,
       _id = id,
       _label = label,
       _color = color,
       _visible = visible,
       _clip = clip,
       _isolate = isolate {
    this.channel = channel;
  }

  /// The delegate that paints the layer.
  ChartPainter get painter => _painter;
  ChartPainter _painter;
  set painter(ChartPainter value) {
    final ChartPainter old = _painter;
    if (identical(old, value)) return;
    _painter = value;
    if (attached) {
      _unsubscribe(old);
      _subscribe(value);
    }
    final bool sameType = value.runtimeType == old.runtimeType;
    if (!sameType || value.shouldRepaint(old)) markNeedsPaint();
    if (!attached) return;
    final bool wasSeries = old is ChartSeriesPainter;
    final bool isSeries = value is ChartSeriesPainter;
    if (wasSeries && !isSeries) {
      _controller.unregisterSeries(this);
    } else if (!wasSeries && isSeries) {
      _controller.registerSeries(this);
    } else if (old is ChartSeriesPainter && value is ChartSeriesPainter) {
      if (!sameType ||
          old.xScale != value.xScale ||
          old.yScale != value.yScale ||
          value.shouldRescale(old)) {
        _controller.seriesChanged(this);
      }
    }
  }

  /// The controller the series registers with.
  ChartController get controller => _controller;
  ChartController _controller;
  set controller(ChartController value) {
    if (identical(value, _controller)) return;
    final bool registered = attached && _painter is ChartSeriesPainter;
    if (registered) _controller.unregisterSeries(this);
    _controller = value;
    if (registered) _controller.registerSeries(this);
  }

  Object? _id;
  String? _label;
  Color? _color;

  /// Updates the series metadata.
  void setMetadata({Object? id, String? label, Color? color}) {
    if (id == _id && label == _label && color == _color) return;
    _id = id;
    _label = label;
    _color = color;
    if (attached && _painter is ChartSeriesPainter) _controller.seriesChanged(this);
  }

  @override
  bool get visible => _visible;
  bool _visible;
  set visible(bool value) {
    if (value == _visible) return;
    _visible = value;
    markNeedsPaint();
    if (attached && _painter is ChartSeriesPainter) _controller.seriesChanged(this);
  }

  /// Whether painting is clipped to the plot area.
  bool get clip => _clip;
  bool _clip;
  set clip(bool value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

  /// Whether the layer paints into its own compositing layer.
  bool get isolate => _isolate;
  bool _isolate;
  set isolate(bool value) {
    if (value == _isolate) return;
    _isolate = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  void _handleDataChanged() {
    markNeedsPaint();
    _controller.seriesChanged(this);
  }

  void _subscribe(ChartPainter painter) {
    painter.addListener(markNeedsPaint);
    if (painter is ChartSeriesPainter) painter._data?.addListener(_handleDataChanged);
  }

  void _unsubscribe(ChartPainter painter) {
    painter.removeListener(markNeedsPaint);
    if (painter is ChartSeriesPainter) painter._data?.removeListener(_handleDataChanged);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _subscribe(_painter);
    if (_painter is ChartSeriesPainter) _controller.registerSeries(this);
  }

  @override
  void detach() {
    _unsubscribe(_painter);
    if (_painter is ChartSeriesPainter) _controller.unregisterSeries(this);
    super.detach();
  }

  @override
  void didChangeChartView(ChartView? oldView, ChartView newView) => markNeedsPaint();

  @override
  bool get isRepaintBoundary => _isolate;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) =>
      _visible && hasChartView && _painter.hitTest(position, chartView);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_visible || !hasChartView) return;
    final ChartView view = chartView;
    final Canvas canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (_clip) canvas.clipRect(Offset.zero & view.size);
    _painter.paint(ChartPaintContext(canvas: canvas, view: view));
    canvas.restore();
  }

  // --------------------------------------------------------- ChartSeries

  @override
  Object? get id => _id;

  @override
  String? get label => _label;

  @override
  Color? get color => _color;

  @override
  Object get xScale => (_painter as ChartSeriesPainter).xScale;

  @override
  Object get yScale => (_painter as ChartSeriesPainter).yScale;

  @override
  ChartDataBounds? bounds({ChartRange? xWindow, ChartRange? yWindow}) {
    final ChartPainter p = _painter;
    return _visible && p is ChartSeriesPainter
        ? p.bounds(xWindow: xWindow, yWindow: yWindow)
        : null;
  }

  @override
  double? valueAt(double x) {
    final ChartPainter p = _painter;
    return _visible && p is ChartSeriesPainter ? p.valueAt(x) : null;
  }

  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    final ChartPainter p = _painter;
    if (_visible && p is ChartSeriesPainter) p.collectHits(query, hits);
  }
}
