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
