import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../core/chart_controller.dart';
import '../core/chart_view.dart';
import '../core/ticks.dart';
import '../interaction/pointer_hub.dart';
import 'render_chart_layout.dart';
import 'view_channel.dart';

/// Keeps the axes of several charts equally thick, so their plots line up.
///
/// Give the same group to the axes on the same side of each chart with
/// `ChartAxisExtent.shared`. Every axis is then as thick as the thickest one
/// needs to be.
class ChartGutterGroup extends ChangeNotifier {
  final Map<Object, double> _needs = <Object, double>{};
  double _extent = 0;
  bool _scheduled = false;
  bool _disposed = false;

  /// The thickness all axes of the group use.
  double get extent => _extent;

  void _update() {
    if (_disposed) return;
    double extent = 0;
    for (final double v in _needs.values) {
      extent = math.max(extent, v);
    }
    if (extent == _extent) return;
    _extent = extent;
    // Reported during layout: tell the other axes after this frame.
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _report(Object axis, double needed) {
    if (_needs[axis] == needed) return;
    _needs[axis] = needed;
    _update();
  }

  void _remove(Object axis) {
    if (_needs.remove(axis) != null) _update();
  }
}

/// How thick an axis is across its direction.
@immutable
class ChartAxisExtent {
  /// As thick as its labels need, rounded up to a multiple of [step] so it
  /// does not jitter. Grows immediately; shrinks only while the chart is idle.
  const ChartAxisExtent.auto({this.min = 0, this.step = 4}) : size = null, group = null;

  /// Exactly [size] logical pixels thick.
  const ChartAxisExtent.fixed(double this.size) : min = 0, step = 1, group = null;

  /// As thick as the thickest axis in [group] needs, so the plots of several
  /// charts line up.
  const ChartAxisExtent.shared(ChartGutterGroup this.group, {this.min = 0, this.step = 4})
    : size = null;

  /// The group this axis shares its thickness with, if any.
  final ChartGutterGroup? group;

  /// Fixed thickness, or null when measured.
  final double? size;

  /// Smallest measured thickness.
  final double min;

  /// Measured thickness is rounded up to a multiple of this.
  final double step;

  @override
  bool operator ==(Object other) =>
      other is ChartAxisExtent &&
      other.size == size &&
      other.min == min &&
      other.step == step &&
      identical(other.group, group);

  @override
  int get hashCode => Object.hash(size, min, step, group);
}

/// The role of a child of [RenderChartAxis].
enum ChartAxisChildKind {
  /// A tick label: sizes the axis and takes part in overlap hiding.
  label,

  /// A marker pinned to a value: floats over the labels.
  marker,

  /// An invisible child used only to reserve thickness.
  prototype,
}

/// Computes the data value a marker sits at. Return null to hide the marker.
typedef ChartAxisValueResolver = double? Function(ChartView view);

/// Parent data of the children of [RenderChartAxis].
class ChartAxisParentData extends ContainerBoxParentData<RenderBox> {
  /// What the child is.
  ChartAxisChildKind kind = ChartAxisChildKind.label;

  /// The data value the child is placed at.
  double? value;

  /// Computes the value from the view, instead of [value].
  ChartAxisValueResolver? resolver;

  /// Whether a marker whose value is outside the window sticks to the nearest
  /// end of the axis instead of disappearing.
  bool clamp = false;

  bool _visible = true;
}

/// Draws an axis and places its label and marker widgets along it.
///
/// Labels are positioned from tick values during layout, so they slide with
/// the data without being rebuilt. The axis reports its thickness from its
/// labels, which is how the chart sizes the gutter.
class RenderChartAxis extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ChartAxisParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, ChartAxisParentData>,
        ChartViewDependent {
  /// Creates an axis render object.
  RenderChartAxis({
    required ChartSide side,
    required Object scaleId,
    required this.controller,
    required ChartPointerHub hub,
    ChartViewChannel? channel,
    ChartAxisExtent extent = const ChartAxisExtent.auto(),
    List<double> tickValues = const <double>[],
    double tickLength = 4,
    double minorTickLength = 2,
    ChartTicks? ticks,
    double labelGap = 4,
    double labelSpacing = 6,
    bool showLine = true,
    Color color = const Color(0x59000000),
    double lineWidth = 1,
  }) : _side = side,
       _scaleId = scaleId,
       _hub = hub,
       _extent = extent,
       _tickValues = tickValues,
       _tickLength = tickLength,
       _minorTickLength = minorTickLength,
       _ticks = ticks,
       _labelGap = labelGap,
       _labelSpacing = labelSpacing,
       _showLine = showLine,
       _color = color,
       _lineWidth = lineWidth {
    this.channel = channel;
  }

  /// The side of the plot the axis is docked to.
  ChartSide get side => _side;
  ChartSide _side;
  set side(ChartSide value) {
    if (value == _side) return;
    _side = value;
    markNeedsLayout();
  }

  /// Id of the scale the axis shows.
  Object get scaleId => _scaleId;
  Object _scaleId;
  set scaleId(Object value) {
    if (value == _scaleId) return;
    _scaleId = value;
    if (attached) _hub.registerAxis(this, value);
    markNeedsLayout();
  }

  /// The chart's controller (used to know when the chart is idle).
  ChartController controller;

  /// The hub the axis registers its area with.
  ChartPointerHub get hub => _hub;
  ChartPointerHub _hub;
  set hub(ChartPointerHub value) {
    if (identical(value, _hub)) return;
    if (attached) _hub.unregisterAxis(this);
    _hub = value;
    if (attached) _hub.registerAxis(this, _scaleId);
  }

  /// How thick the axis is.
  ChartAxisExtent get extent => _extent;
  ChartAxisExtent _extent;
  set extent(ChartAxisExtent value) {
    if (value == _extent) return;
    if (attached && !identical(value.group, _extent.group)) {
      _extent.group?.removeListener(markNeedsLayout);
      _extent.group?._remove(this);
      value.group?.addListener(markNeedsLayout);
    }
    _extent = value;
    _measured = 0;
    markNeedsLayout();
  }

  /// Data values at which tick marks are drawn.
  List<double> get tickValues => _tickValues;
  List<double> _tickValues;
  set tickValues(List<double> value) {
    if (listEquals(value, _tickValues)) return;
    _tickValues = value;
    markNeedsPaint();
  }

  /// Length of tick marks. `0` draws none.
  /// Length of the marks at minor ticks.
  double get minorTickLength => _minorTickLength;
  double _minorTickLength;
  set minorTickLength(double value) {
    if (value == _minorTickLength) return;
    _minorTickLength = value;
    markNeedsPaint();
  }

  /// The ticks of this axis, when they are not the ones of its scale.
  ChartTicks? get ticks => _ticks;
  ChartTicks? _ticks;
  set ticks(ChartTicks? value) {
    if (value == _ticks) return;
    _ticks = value;
    markNeedsPaint();
  }

  // The minor ticks of [scale], or of the ticks given to this axis. They are
  // read while painting, so they follow the window without a rebuild.
  List<double> _minorTicks(ChartScaleView scale) {
    final ChartTicks? own = _ticks;
    if (own == null) return scale.minorTicks;
    final ChartTicks resolved = scale.scale.resolveTicks(own);
    final ChartTickContext context = scale.tickContext;
    return resolved.generateMinor(context, resolved.generate(context));
  }

  double get tickLength => _tickLength;
  double _tickLength;
  set tickLength(double value) {
    if (value == _tickLength) return;
    _tickLength = value;
    markNeedsLayout();
  }

  /// Gap between tick marks and labels.
  double get labelGap => _labelGap;
  double _labelGap;
  set labelGap(double value) {
    if (value == _labelGap) return;
    _labelGap = value;
    markNeedsLayout();
  }

  /// Minimum room between neighbouring labels; closer ones are hidden.
  double get labelSpacing => _labelSpacing;
  double _labelSpacing;
  set labelSpacing(double value) {
    if (value == _labelSpacing) return;
    _labelSpacing = value;
    markNeedsLayout();
  }

  /// Whether the axis line is drawn.
  bool get showLine => _showLine;
  bool _showLine;
  set showLine(bool value) {
    if (value == _showLine) return;
    _showLine = value;
    markNeedsPaint();
  }

  /// Colour of the line and tick marks.
  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  /// Width of the line and tick marks.
  double get lineWidth => _lineWidth;
  double _lineWidth;
  set lineWidth(double value) {
    if (value == _lineWidth) return;
    _lineWidth = value;
    markNeedsPaint();
  }

  double _measured = 0;

  bool get _horizontal => _side.isHorizontal;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ChartAxisParentData) child.parentData = ChartAxisParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _hub.registerAxis(this, _scaleId);
    _extent.group?.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _hub.unregisterAxis(this);
    _extent.group?.removeListener(markNeedsLayout);
    _extent.group?._remove(this);
    super.detach();
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    final double main = _horizontal ? constraints.maxWidth : constraints.maxHeight;
    final double maxCross = _horizontal ? constraints.maxHeight : constraints.maxWidth;
    final double chrome = _tickLength + _labelGap;
    final double labelRoom = math.max(0, maxCross - chrome);
    final BoxConstraints childConstraints = _horizontal
        ? BoxConstraints(maxWidth: main.isFinite ? main : double.infinity, maxHeight: labelRoom)
        : BoxConstraints(maxWidth: labelRoom, maxHeight: main.isFinite ? main : double.infinity);

    double labelCross = 0;
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final ChartAxisParentData data = child.parentData! as ChartAxisParentData;
      child.layout(childConstraints, parentUsesSize: true);
      if (data.kind != ChartAxisChildKind.marker) {
        labelCross = math.max(labelCross, _horizontal ? child.size.height : child.size.width);
      }
    }

    double cross;
    final double? fixed = _extent.size;
    if (fixed != null) {
      cross = fixed;
    } else {
      final double needed = math.max(
        _extent.min,
        labelCross > 0 ? labelCross + chrome : _tickLength,
      );
      final double step = _extent.step > 0 ? _extent.step : 1;
      final double stepped = (needed / step).ceilToDouble() * step;
      // Growing is immediate; shrinking waits until the gesture or animation
      // is over, so the plot does not twitch while panning.
      if (stepped > _measured || !controller.isInteracting) _measured = stepped;
      cross = _measured;
      final ChartGutterGroup? group = _extent.group;
      if (group != null) {
        group._report(this, cross);
        cross = math.max(cross, group.extent);
      }
    }
    cross = cross.clamp(0, maxCross.isFinite ? maxCross : cross).toDouble();
    size = constraints.constrain(_horizontal ? Size(main, cross) : Size(cross, main));

    if (!hasChartView || !chartView.scales.containsKey(_scaleId)) {
      for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
        (child.parentData! as ChartAxisParentData)._visible = false;
      }
      return;
    }
    final ChartView view = chartView;
    final ChartScaleView scale = view.scale(_scaleId);

    // Place labels, then hide the ones that would collide.
    final List<RenderBox> labels = <RenderBox>[];
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final ChartAxisParentData data = child.parentData! as ChartAxisParentData;
      if (data.kind == ChartAxisChildKind.prototype) {
        data._visible = false;
        continue;
      }
      double? value = data.resolver != null ? data.resolver!(view) : data.value;
      if (value != null && data.kind == ChartAxisChildKind.marker && data.clamp) {
        value = value.clamp(math.min(scale.min, scale.max), math.max(scale.min, scale.max));
      }
      final double? pixel = value == null ? null : scale.toPixel(value);
      if (pixel == null || !pixel.isFinite || pixel < -0.5 || pixel > main + 0.5) {
        data._visible = false;
        continue;
      }
      data._visible = true;
      final double childMain = _horizontal ? child.size.width : child.size.height;
      final double childCross = _horizontal ? child.size.height : child.size.width;
      // Centre on the value, but keep edge labels inside the axis.
      double start = pixel - childMain / 2;
      if (childMain <= main) start = start.clamp(0, main - childMain).toDouble();
      final double across = switch (_side) {
        ChartSide.bottom || ChartSide.right => chrome,
        ChartSide.top || ChartSide.left => cross - chrome - childCross,
      };
      data.offset = _horizontal ? Offset(start, across) : Offset(across, start);
      if (data.kind == ChartAxisChildKind.label) labels.add(child);
    }
    labels.sort((RenderBox a, RenderBox b) => _mainStart(a).compareTo(_mainStart(b)));
    double lastEnd = double.negativeInfinity;
    for (final RenderBox label in labels) {
      final double start = _mainStart(label);
      final double length = _horizontal ? label.size.width : label.size.height;
      if (start < lastEnd + _labelSpacing) {
        (label.parentData! as ChartAxisParentData)._visible = false;
      } else {
        lastEnd = start + length;
      }
    }
  }

  double _mainStart(RenderBox child) {
    final Offset offset = (child.parentData! as ChartAxisParentData).offset;
    return _horizontal ? offset.dx : offset.dy;
  }

  @override
  bool paintsChild(RenderBox child) => (child.parentData! as ChartAxisParentData)._visible;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (hasChartView && chartView.scales.containsKey(_scaleId)) {
      final ChartScaleView scale = chartView.scale(_scaleId);
      final Canvas canvas = context.canvas;
      final Paint paint = Paint()
        ..color = _color
        ..strokeWidth = _lineWidth
        ..style = PaintingStyle.stroke;
      // The edge of this box that touches the plot.
      final Offset a;
      final Offset b;
      final Offset tick;
      switch (_side) {
        case ChartSide.bottom:
          a = offset;
          b = offset + Offset(size.width, 0);
          tick = Offset(0, _tickLength);
        case ChartSide.top:
          a = offset + Offset(0, size.height);
          b = offset + Offset(size.width, size.height);
          tick = Offset(0, -_tickLength);
        case ChartSide.left:
          a = offset + Offset(size.width, 0);
          b = offset + Offset(size.width, size.height);
          tick = Offset(-_tickLength, 0);
        case ChartSide.right:
          a = offset;
          b = offset + Offset(0, size.height);
          tick = Offset(_tickLength, 0);
      }
      if (_showLine) canvas.drawLine(a, b, paint);
      if (_tickLength > 0) {
        final double main = _horizontal ? size.width : size.height;
        for (final double value in _tickValues) {
          final double pixel = scale.toPixel(value);
          if (!pixel.isFinite || pixel < -0.5 || pixel > main + 0.5) continue;
          final Offset p = a + (_horizontal ? Offset(pixel, 0) : Offset(0, pixel));
          canvas.drawLine(p, p + tick, paint);
        }
      }
      if (_minorTickLength > 0) {
        final double main = _horizontal ? size.width : size.height;
        final Offset mark = tick == Offset.zero
            ? switch (_side) {
                ChartSide.bottom => Offset(0, _minorTickLength),
                ChartSide.top => Offset(0, -_minorTickLength),
                ChartSide.left => Offset(-_minorTickLength, 0),
                ChartSide.right => Offset(_minorTickLength, 0),
              }
            : tick * (_minorTickLength / _tickLength);
        for (final double value in _minorTicks(scale)) {
          final double pixel = scale.toPixel(value);
          if (!pixel.isFinite || pixel < -0.5 || pixel > main + 0.5) continue;
          final Offset p = a + (_horizontal ? Offset(pixel, 0) : Offset(0, pixel));
          canvas.drawLine(p, p + mark, paint);
        }
      }
    }
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final ChartAxisParentData data = child.parentData! as ChartAxisParentData;
      if (data._visible) context.paintChild(child, data.offset + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (RenderBox? child = lastChild; child != null; child = childBefore(child)) {
      final ChartAxisParentData data = child.parentData! as ChartAxisParentData;
      if (!data._visible) continue;
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
