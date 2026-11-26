import 'package:flutter/widgets.dart';

import '../core/chart_controller.dart';
import '../interaction/pointer_hub.dart';
import '../rendering/render_chart_layout.dart';
import '../rendering/view_channel.dart';

/// Gives everything below a `Chart` access to that chart.
///
/// Chart-aware widgets look this up to find the [controller] (state and
/// queries), the [channel] (the per-frame view, for render objects) and the
/// [hub] (pointer events, for behaviors).
class ChartScope extends InheritedWidget {
  /// Creates a scope. A `Chart` does this for you.
  const ChartScope({
    super.key,
    required this.controller,
    required this.channel,
    required this.hub,
    required super.child,
  });

  /// The chart's controller.
  final ChartController controller;

  /// The channel the chart publishes its view on.
  final ChartViewChannel channel;

  /// The hub that routes pointer events to behaviors.
  final ChartPointerHub hub;

  /// The scope of the closest chart above [context].
  static ChartScope of(BuildContext context) {
    final ChartScope? scope = maybeOf(context);
    if (scope == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No ChartScope found.'),
        ErrorDescription(
          '${context.widget.runtimeType} must be placed below a Chart: in its children, '
          'in one of its side slots, or anywhere inside those.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scope;
  }

  /// The scope of the closest chart above [context], or null.
  static ChartScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChartScope>();

  @override
  bool updateShouldNotify(ChartScope oldWidget) =>
      !identical(oldWidget.controller, controller) ||
      !identical(oldWidget.channel, channel) ||
      !identical(oldWidget.hub, hub);
}

/// Tells a widget docked beside the plot which side it is on.
class ChartDockScope extends InheritedWidget {
  /// Creates a dock scope. A `Chart` does this for every docked widget.
  const ChartDockScope({super.key, required this.side, required super.child});

  /// The side of the plot the subtree is docked to.
  final ChartSide side;

  /// The side the closest dock above [context] is on, or null if [context] is
  /// not inside a dock.
  static ChartSide? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChartDockScope>()?.side;

  @override
  bool updateShouldNotify(ChartDockScope oldWidget) => oldWidget.side != side;
}

/// How a series is drawn while it appears. See `ChartAppear`.
enum ChartAppearEffect {
  /// Grows along y from the zero line, or from the edge of the plot nearest
  /// to it. Right for columns and areas. Strokes are stretched while it
  /// lasts. In a polar chart the series grows out of the centre.
  growY,

  /// Grows along x from the zero line, or from the edge of the plot nearest
  /// to it. Right for bars that lie. In a polar chart the series grows out
  /// of the centre.
  growX,

  /// Is uncovered along the x scale, from its low end. Right for lines. In a
  /// polar chart the series is uncovered around the centre, from the start
  /// angle: right for a pie.
  reveal,

  /// Fades in.
  fade,
}

/// Tells the series layers below it how far they have appeared.
///
/// `ChartAppear` provides one. Every `ChartPaint` below it that paints a
/// listed series draws itself through [effect] at [progress], which runs
/// from 0 (nothing to see) to 1 (drawn as usual). Grids, crosshairs and
/// reference lines are not series and are left alone.
class ChartAppearScope extends InheritedWidget {
  /// Creates a scope. A `ChartAppear` does this for you.
  const ChartAppearScope({
    super.key,
    required this.progress,
    required this.effect,
    required super.child,
  });

  /// How far the series have appeared, from 0 to 1.
  final Animation<double> progress;

  /// How a series that has partly appeared is drawn.
  final ChartAppearEffect effect;

  /// The closest scope above [context], or null.
  static ChartAppearScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChartAppearScope>();

  @override
  bool updateShouldNotify(ChartAppearScope oldWidget) =>
      !identical(oldWidget.progress, progress) || oldWidget.effect != effect;
}
