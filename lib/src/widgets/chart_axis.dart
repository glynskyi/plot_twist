import 'package:flutter/widgets.dart';

import '../core/chart_view.dart';
import '../core/ticks.dart';
import '../rendering/render_chart_axis.dart';
import '../rendering/render_chart_layout.dart';
import 'chart_layout_builder.dart';
import 'chart_scope.dart';
import 'chart_theme.dart';

/// Builds the widget shown for one tick of an axis.
typedef ChartTickLabelBuilder = Widget Function(BuildContext context, ChartTick tick);

/// Turns a tick into the text of its label.
typedef ChartTickFormatter = String Function(ChartTick tick);

/// An axis: a line, tick marks and one label widget per tick.
///
/// Put it in a side slot of a `Chart`. Labels are real widgets — pass a
/// [labelBuilder] to show icons, chips or multi-line text — and they are built
/// only for the ticks that are visible, only when the set of ticks changes.
/// While the chart is panned they slide without being rebuilt.
///
/// The axis sizes itself from its labels ([extent]), which is how the chart
/// decides how wide the gutter is.
class ChartAxis extends StatelessWidget {
  /// Creates an axis for [scale]. By default, axes docked left or right show
  /// the y scale and axes docked above or below show the x scale.
  const ChartAxis({
    super.key,
    this.scale,
    this.extent = const ChartAxisExtent.auto(),
    this.labelBuilder,
    this.format,
    this.ticks,
    this.prototype,
    this.markers = const <Widget>[],
    this.tickLength = 4,
    this.minorTickLength = 2,
    this.labelGap = 4,
    this.labelSpacing = 6,
    this.showLine = true,
    this.showLabels = true,
    this.color,
    this.labelStyle,
  });

  /// Id of the scale to show.
  final Object? scale;

  /// How thick the axis is.
  final ChartAxisExtent extent;

  /// Builds the widget for a tick. Defaults to a `Text` of the tick's label.
  final ChartTickLabelBuilder? labelBuilder;

  /// Text for the default labels.
  ///
  /// `tick.label` is already written with as many decimals as the spacing of
  /// the ticks needs, so `(tick) => '${tick.label} m'` adds a unit and stays
  /// correct at every zoom level. Format `tick.value` for anything else.
  final ChartTickFormatter? format;

  /// Tick strategy for this axis only. Prefer setting ticks on the scale, so
  /// grid lines agree with the axis.
  final ChartTicks? ticks;

  /// A widget as large as the largest expected label. The axis reserves room
  /// for it, which keeps the gutter from changing as labels come and go.
  final Widget? prototype;

  /// Widgets pinned to values along the axis, usually [ChartAxisMarker]s.
  final List<Widget> markers;

  /// Length of tick marks. `0` draws none.
  final double tickLength;

  /// Length of the marks at minor ticks. `0` draws none. There are minor
  /// ticks only when the ticks of the scale, or [ticks], have them: see
  /// `LinearTicks.minorCount`.
  final double minorTickLength;

  /// Gap between tick marks and labels.
  final double labelGap;

  /// Minimum room between neighbouring labels; closer labels are hidden.
  final double labelSpacing;

  /// Whether the axis line is drawn.
  final bool showLine;

  /// Whether tick labels are shown.
  final bool showLabels;

  /// Colour of the line and tick marks. Defaults to the chart theme.
  final Color? color;

  /// Text style merged into the theme's label style.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final ChartSide? side = ChartDockScope.maybeOf(context);
    if (side == null) {
      throw FlutterError(
        'ChartAxis must be placed in a side slot of a Chart '
        '(left, top, right or bottom).',
      );
    }
    final Object scaleId = scale ?? (side.isHorizontal ? kChartX : kChartY);
    final ChartThemeData theme = ChartTheme.of(context);
    final TextStyle style = theme.labelStyle.merge(labelStyle);
    final ChartTicks? override = ticks;

    return ChartLayoutBuilder<ChartTickSet>(
      selector: (ChartView view) {
        if (!view.scales.containsKey(scaleId)) return ChartTickSet.empty;
        final ChartScaleView s = view.scale(scaleId);
        if (override == null) return ChartTickSet(s.ticks);
        // The scale completes them: UTC, a logarithm base, band labels.
        return ChartTickSet(s.scale.resolveTicks(override).generate(s.tickContext));
      },
      builder: (BuildContext context, ChartTickSet tickSet) {
        final ChartScope scope = ChartScope.of(context);
        final Widget? reserve = prototype;
        return _ChartAxisBody(
          scope: scope,
          side: side,
          scaleId: scaleId,
          extent: extent,
          tickValues: <double>[for (final ChartTick t in tickSet.ticks) t.value],
          tickLength: tickLength,
          minorTickLength: minorTickLength,
          ticks: override,
          labelGap: labelGap,
          labelSpacing: labelSpacing,
          showLine: showLine,
          color: color ?? theme.axisColor,
          children: <Widget>[
            if (showLabels)
              for (final ChartTick tick in tickSet.ticks)
                _AxisSlot(
                  key: ValueKey<double>(tick.value),
                  kind: ChartAxisChildKind.label,
                  value: tick.value,
                  child: DefaultTextStyle(
                    style: style,
                    child:
                        labelBuilder?.call(context, tick) ??
                        Text(format?.call(tick) ?? tick.label, maxLines: 1, softWrap: false),
                  ),
                ),
            if (reserve != null)
              _AxisSlot(
                kind: ChartAxisChildKind.prototype,
                child: DefaultTextStyle(style: style, child: reserve),
              ),
            ...markers,
          ],
        );
      },
    );
  }
}

/// Pins a widget to a data value on a [ChartAxis] — a value pill, a crosshair
/// badge, a "now" flag.
///
/// The marker follows its value while the chart is panned, without being
/// rebuilt. Use [ChartAxisMarker.resolve] when the value itself depends on the
/// view (for example the value of a series at the edge of the plot).
class ChartAxisMarker extends ParentDataWidget<ChartAxisParentData> {
  /// Pins [child] at [value].
  const ChartAxisMarker({
    super.key,
    required double this.value,
    this.clamp = false,
    required super.child,
  }) : resolver = null;

  /// Pins [child] at the value [resolver] returns for the current view.
  const ChartAxisMarker.resolve({
    super.key,
    required ChartAxisValueResolver this.resolver,
    this.clamp = false,
    required super.child,
  }) : value = null;

  /// The data value the marker sits at.
  final double? value;

  /// Computes the value from the view.
  final ChartAxisValueResolver? resolver;

  /// Whether the marker sticks to the nearest end of the axis when its value
  /// is outside the visible window, instead of disappearing.
  final bool clamp;

  @override
  void applyParentData(RenderObject renderObject) {
    final ChartAxisParentData data = renderObject.parentData! as ChartAxisParentData;
    if (data.kind != ChartAxisChildKind.marker ||
        data.value != value ||
        data.resolver != resolver ||
        data.clamp != clamp) {
      data
        ..kind = ChartAxisChildKind.marker
        ..value = value
        ..resolver = resolver
        ..clamp = clamp;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => ChartAxis;
}

class _AxisSlot extends ParentDataWidget<ChartAxisParentData> {
  const _AxisSlot({super.key, required this.kind, this.value, required super.child});

  final ChartAxisChildKind kind;
  final double? value;

  @override
  void applyParentData(RenderObject renderObject) {
    final ChartAxisParentData data = renderObject.parentData! as ChartAxisParentData;
    if (data.kind != kind || data.value != value || data.resolver != null) {
      data
        ..kind = kind
        ..value = value
        ..resolver = null
        ..clamp = false;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _ChartAxisBody;
}

class _ChartAxisBody extends MultiChildRenderObjectWidget {
  const _ChartAxisBody({
    required this.scope,
    required this.side,
    required this.scaleId,
    required this.extent,
    required this.tickValues,
    required this.tickLength,
    required this.minorTickLength,
    required this.ticks,
    required this.labelGap,
    required this.labelSpacing,
    required this.showLine,
    required this.color,
    super.children,
  });

  final ChartScope scope;
  final ChartSide side;
  final Object scaleId;
  final ChartAxisExtent extent;
  final List<double> tickValues;
  final double tickLength;
  final double minorTickLength;
  final ChartTicks? ticks;
  final double labelGap;
  final double labelSpacing;
  final bool showLine;
  final Color color;

  @override
  RenderChartAxis createRenderObject(BuildContext context) => RenderChartAxis(
    side: side,
    scaleId: scaleId,
    controller: scope.controller,
    hub: scope.hub,
    channel: scope.channel,
    extent: extent,
    tickValues: tickValues,
    tickLength: tickLength,
    minorTickLength: minorTickLength,
    ticks: ticks,
    labelGap: labelGap,
    labelSpacing: labelSpacing,
    showLine: showLine,
    color: color,
  );

  @override
  void updateRenderObject(BuildContext context, RenderChartAxis renderObject) {
    renderObject
      ..side = side
      ..scaleId = scaleId
      ..controller = scope.controller
      ..hub = scope.hub
      ..channel = scope.channel
      ..extent = extent
      ..tickValues = tickValues
      ..tickLength = tickLength
      ..minorTickLength = minorTickLength
      ..ticks = ticks
      ..labelGap = labelGap
      ..labelSpacing = labelSpacing
      ..showLine = showLine
      ..color = color;
  }
}
