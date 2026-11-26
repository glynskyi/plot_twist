import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Builds the legend item of [series].
typedef ChartLegendItemBuilder = Widget Function(BuildContext context, ChartSeries series);

/// Builds the legend item of one [entry] of [series], such as a slice of a
/// pie.
typedef ChartLegendEntryBuilder =
    Widget Function(BuildContext context, ChartSeries series, ChartSeriesEntry entry);

/// A legend: the colour and the label of every series of a chart.
///
/// ```dart
/// Chart(
///   top: const [ChartLegend()],
///   children: [LineSeries(data: north, label: 'North'), …],
/// )
/// ```
///
/// In a side slot of a `Chart`, or anywhere below it, the legend finds the
/// chart by itself. Elsewhere, give it the chart's [controller].
///
/// It lists the series the controller lists, in the order they are painted,
/// and leaves out those without a `label`. A hidden series stays in the
/// legend, dimmed. The legend does not hide series itself: [onSeriesTap]
/// tells you which one was tapped, and you decide what `visible` is.
///
/// A series whose parts have names of their own, as the slices of a
/// `PieSeries` with `labels` do, gets one item per part instead; taps on
/// those are reported to [onEntryTap].
class ChartLegend extends StatelessWidget {
  /// Creates a legend.
  const ChartLegend({
    super.key,
    this.controller,
    this.direction,
    this.alignment = WrapAlignment.start,
    this.spacing = 12,
    this.runSpacing = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    this.swatchSize = 10,
    this.textStyle,
    this.itemBuilder,
    this.entryBuilder,
    this.onSeriesTap,
    this.onSeriesLongPress,
    this.onEntryTap,
  });

  /// The controller of the chart. Needed only outside that chart.
  final ChartController? controller;

  /// Whether the items form rows or columns. Defaults to rows, and to
  /// columns in a slot left or right of the plot. Items that do not fit wrap.
  final Axis? direction;

  /// How the items of a row or column are placed along it.
  final WrapAlignment alignment;

  /// Space between two items.
  final double spacing;

  /// Space between two rows or columns of items.
  final double runSpacing;

  /// Space around the legend.
  final EdgeInsetsGeometry padding;

  /// Diameter of the dot in the colour of the series.
  final double swatchSize;

  /// Text style merged into the label style of the chart theme.
  final TextStyle? textStyle;

  /// Builds an item, instead of a dot and the label. Taps on it are still
  /// reported.
  final ChartLegendItemBuilder? itemBuilder;

  /// Called when an item is tapped. Typically toggles the `visible` of that
  /// series in your state.
  final void Function(ChartSeries series)? onSeriesTap;

  /// Called when an item is long-pressed.
  final void Function(ChartSeries series)? onSeriesLongPress;

  /// Builds the item of one part of a series, such as a slice of a pie,
  /// instead of a dot and the label. Taps on it are still reported.
  final ChartLegendEntryBuilder? entryBuilder;

  /// Called when the item of one part of a series is tapped: a slice of a
  /// pie.
  final void Function(ChartSeries series, ChartSeriesEntry entry)? onEntryTap;

  @override
  Widget build(BuildContext context) {
    final ChartController? chart = controller ?? ChartScope.maybeOf(context)?.controller;
    if (chart == null) {
      throw FlutterError(
        'ChartLegend found no chart.\n'
        'Place it in a side slot of a Chart or below one, or give it the '
        'ChartController of the chart it describes.',
      );
    }
    final ChartSide? side = ChartDockScope.maybeOf(context);
    final Axis axis =
        direction ?? (side == null || side.isHorizontal ? Axis.horizontal : Axis.vertical);
    final TextStyle style = ChartTheme.of(context).labelStyle.merge(textStyle);
    return ListenableBuilder(
      listenable: chart.seriesListenable,
      // Built during layout: by then the series of this frame are in the
      // chart, so the legend is complete on the first frame it is shown.
      builder: (BuildContext context, Widget? child) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Padding(
          padding: padding,
          child: DefaultTextStyle(
            style: style,
            child: Wrap(
              direction: axis,
              alignment: alignment,
              spacing: spacing,
              runSpacing: runSpacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final ChartSeries series in chart.series)
                  if (series.entries.isNotEmpty) ...<Widget>[
                    for (final ChartSeriesEntry entry in series.entries)
                      if (entry.label != null) _entry(context, series, entry),
                  ] else if (series.label != null)
                    _item(context, series),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // A dot in [color] and [label], dimmed when what it stands for is hidden.
  Widget _swatch(Color? color, String label, bool visible) => Opacity(
    opacity: visible ? 1 : 0.4,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: swatchSize,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, maxLines: 1, softWrap: false),
      ],
    ),
  );

  static Widget _tappable(Widget item, VoidCallback? onTap, VoidCallback? onLongPress) {
    if (onTap == null && onLongPress == null) return item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Semantics(button: true, child: item),
      ),
    );
  }

  Widget _item(BuildContext context, ChartSeries series) {
    final void Function(ChartSeries series)? tap = onSeriesTap;
    final void Function(ChartSeries series)? longPress = onSeriesLongPress;
    return KeyedSubtree(
      key: ObjectKey(series),
      child: _tappable(
        itemBuilder?.call(context, series) ?? _swatch(series.color, series.label!, series.visible),
        tap == null ? null : () => tap(series),
        longPress == null ? null : () => longPress(series),
      ),
    );
  }

  Widget _entry(BuildContext context, ChartSeries series, ChartSeriesEntry entry) {
    final void Function(ChartSeries series, ChartSeriesEntry entry)? tap = onEntryTap;
    return KeyedSubtree(
      key: ValueKey<(ChartSeries, int)>((series, entry.index)),
      child: _tappable(
        entryBuilder?.call(context, series, entry) ??
            _swatch(entry.color, entry.label!, series.visible && entry.visible),
        tap == null ? null : () => tap(series, entry),
        null,
      ),
    );
  }
}
