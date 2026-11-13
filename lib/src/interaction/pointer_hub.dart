import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

/// The part of a chart a pointer is over.
enum ChartRegion {
  /// The plot area.
  plot,

  /// The gutter left of the plot.
  left,

  /// The gutter above the plot.
  top,

  /// The gutter right of the plot.
  right,

  /// The gutter below the plot.
  bottom,

  /// A corner between two gutters.
  corner,
}

/// A pointer event delivered to chart behaviors, with chart context.
@immutable
class ChartPointerEvent {
  /// Creates a chart pointer event.
  const ChartPointerEvent({
    required this.event,
    required this.plotPosition,
    required this.region,
    this.axisScale,
  });

  /// The raw pointer event.
  final PointerEvent event;

  /// The pointer position in plot-local coordinates.
  final Offset plotPosition;

  /// Where in the chart the pointer is.
  final ChartRegion region;

  /// The id of the scale whose axis is under the pointer, if any.
  final Object? axisScale;
}

/// Receives pointer events from the chart's pointer hub.
abstract class ChartPointerHandler {
  /// Called for every pointer event the chart is hit by: downs, hovers,
  /// signals and trackpad gesture starts, anywhere over the plot or gutters.
  void handleChartPointerEvent(ChartPointerEvent event);

  /// Called when a hovering pointer leaves the chart.
  void handleChartPointerExit() {}

  /// Whether this handler needs hover (mouse move) events.
  bool get wantsHover => false;
}

/// Routes pointer events from the chart's root to its behaviors.
///
/// Behaviors registered here act like one gesture detector wrapped around the
/// whole chart: interactive widgets inside the chart get first chance in the
/// gesture arena, and a drag that starts on top of a marker still reaches the
/// pan behavior.
class ChartPointerHub {
  final List<ChartPointerHandler> _handlers = <ChartPointerHandler>[];
  final Map<RenderBox, Object> _axes = <RenderBox, Object>{};
  final Set<int> _shielded = <int>{};

  /// Keeps chart behaviors away from [pointer] until it is lifted.
  ///
  /// Call this from the pointer-down handler of a widget inside the chart
  /// that handles the gesture itself, such as a draggable handle. See
  /// `ChartGestureShield`.
  void shield(int pointer) => _shielded.add(pointer);

  /// Called when handlers are added or removed.
  @internal
  VoidCallback? onChanged;

  /// Whether any behavior is registered.
  bool get hasHandlers => _handlers.isNotEmpty;

  /// Whether any behavior wants hover events.
  bool get wantsHover => _handlers.any((ChartPointerHandler h) => h.wantsHover);

  /// Registers [handler]. Handlers are called in registration order.
  void addHandler(ChartPointerHandler handler) {
    _handlers.add(handler);
    onChanged?.call();
  }

  /// Removes [handler].
  void removeHandler(ChartPointerHandler handler) {
    if (_handlers.remove(handler)) onChanged?.call();
  }

  /// Call when a handler's [ChartPointerHandler.wantsHover] changed.
  void handlerChanged() => onChanged?.call();

  /// Tells the hub that [box] draws the axis of scale [scaleId], so gestures
  /// over it can be attributed to that scale.
  void registerAxis(RenderBox box, Object scaleId) => _axes[box] = scaleId;

  /// Removes an axis registered with [registerAxis].
  void unregisterAxis(RenderBox box) => _axes.remove(box);

  /// The scale id of the axis under a global [position], if any.
  Object? axisScaleAt(Offset position) {
    for (final MapEntry<RenderBox, Object> entry in _axes.entries) {
      final RenderBox box = entry.key;
      if (!box.attached || !box.hasSize) continue;
      if ((Offset.zero & box.size).contains(box.globalToLocal(position))) return entry.value;
    }
    return null;
  }

  /// Delivers [event] to every handler.
  @internal
  void dispatch(ChartPointerEvent event) {
    final PointerEvent raw = event.event;
    if (raw is PointerUpEvent || raw is PointerCancelEvent || raw is PointerPanZoomEndEvent) {
      _shielded.remove(raw.pointer);
    } else if (_shielded.contains(raw.pointer)) {
      return;
    }
    for (final ChartPointerHandler handler in List<ChartPointerHandler>.of(_handlers)) {
      handler.handleChartPointerEvent(event);
    }
  }

  /// Tells every handler the hovering pointer left the chart.
  @internal
  void dispatchExit() {
    for (final ChartPointerHandler handler in List<ChartPointerHandler>.of(_handlers)) {
      handler.handleChartPointerExit();
    }
  }
}
