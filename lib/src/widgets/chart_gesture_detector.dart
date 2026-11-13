import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../interaction/pointer_hub.dart';
import 'chart_scope.dart';

/// Decides whether the pointer that produced [event] is offered to a
/// detector's gesture recognizers.
typedef ChartPointerFilter = bool Function(ChartPointerEvent event);

/// Listens to gestures over a whole chart — plot and gutters — from anywhere
/// in its children.
///
/// This is the building block for chart behaviors. It works like a
/// `RawGestureDetector` wrapped around the chart: interactive widgets inside
/// the chart get first chance in the gesture arena, several detectors coexist,
/// and their recognizers compete normally with each other and with parent
/// scrollables.
///
/// Put it in `Chart.children`. It paints nothing itself; [child] (if any) is
/// laid out as a normal layer.
class ChartGestureDetector extends StatefulWidget {
  /// Creates a gesture detector registered with the chart's pointer hub.
  const ChartGestureDetector({
    super.key,
    this.gestures = const <Type, GestureRecognizerFactory>{},
    this.acceptPointer,
    this.onPointerDown,
    this.onPointerSignal,
    this.onPointerHover,
    this.onPointerExit,
    this.child,
  });

  /// Recognizer factories, as for `RawGestureDetector.gestures`.
  final Map<Type, GestureRecognizerFactory> gestures;

  /// Which pointers [gestures] see. Defaults to pointers that go down over
  /// the plot area.
  final ChartPointerFilter? acceptPointer;

  /// Called for every pointer that goes down on the chart.
  final void Function(ChartPointerEvent event)? onPointerDown;

  /// Called for mouse-wheel and trackpad scroll/scale signals.
  final void Function(ChartPointerEvent event)? onPointerSignal;

  /// Called while a mouse pointer moves over the chart without buttons down.
  final void Function(ChartPointerEvent event)? onPointerHover;

  /// Called when a hovering pointer leaves the chart.
  final VoidCallback? onPointerExit;

  /// An optional layer to show.
  final Widget? child;

  @override
  State<ChartGestureDetector> createState() => _ChartGestureDetectorState();
}

class _ChartGestureDetectorState extends State<ChartGestureDetector>
    implements ChartPointerHandler {
  Map<Type, GestureRecognizer> _recognizers = const <Type, GestureRecognizer>{};
  ChartPointerHub? _hub;

  @override
  void initState() {
    super.initState();
    _syncRecognizers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ChartPointerHub hub = ChartScope.of(context).hub;
    if (!identical(hub, _hub)) {
      _hub?.removeHandler(this);
      _hub = hub..addHandler(this);
    }
  }

  @override
  void didUpdateWidget(ChartGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRecognizers();
    final bool hoverBefore = oldWidget.onPointerHover != null || oldWidget.onPointerExit != null;
    if (hoverBefore != wantsHover) _hub?.handlerChanged();
  }

  void _syncRecognizers() {
    final Map<Type, GestureRecognizer> old = _recognizers;
    final Map<Type, GestureRecognizer> next = <Type, GestureRecognizer>{};
    for (final MapEntry<Type, GestureRecognizerFactory> entry in widget.gestures.entries) {
      final GestureRecognizer recognizer = old[entry.key] ?? entry.value.constructor();
      entry.value.initializer(recognizer);
      next[entry.key] = recognizer;
    }
    for (final MapEntry<Type, GestureRecognizer> entry in old.entries) {
      if (!next.containsKey(entry.key)) entry.value.dispose();
    }
    _recognizers = next;
  }

  @override
  void dispose() {
    _hub?.removeHandler(this);
    for (final GestureRecognizer recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  bool _accepts(ChartPointerEvent event) =>
      widget.acceptPointer?.call(event) ?? event.region == ChartRegion.plot;

  @override
  void handleChartPointerEvent(ChartPointerEvent event) {
    final PointerEvent raw = event.event;
    if (raw is PointerDownEvent) {
      widget.onPointerDown?.call(event);
      if (_recognizers.isNotEmpty && _accepts(event)) {
        for (final GestureRecognizer recognizer in _recognizers.values) {
          recognizer.addPointer(raw);
        }
      }
    } else if (raw is PointerPanZoomStartEvent) {
      if (_recognizers.isNotEmpty && _accepts(event)) {
        for (final GestureRecognizer recognizer in _recognizers.values) {
          recognizer.addPointerPanZoom(raw);
        }
      }
    } else if (raw is PointerSignalEvent) {
      widget.onPointerSignal?.call(event);
    } else if (raw is PointerHoverEvent) {
      widget.onPointerHover?.call(event);
    }
  }

  @override
  void handleChartPointerExit() => widget.onPointerExit?.call();

  @override
  bool get wantsHover => widget.onPointerHover != null || widget.onPointerExit != null;

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

/// Keeps the chart's behaviors (panning, crosshair, ...) away from gestures
/// that start on [child].
///
/// Wrap a widget inside the chart that handles its own drags — a draggable
/// handle, a slider — so that dragging it does not also pan the chart.
class ChartGestureShield extends StatelessWidget {
  /// Creates a gesture shield around [child].
  const ChartGestureShield({super.key, required this.child});

  /// The widget whose gestures stay its own.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ChartPointerHub hub = ChartScope.of(context).hub;
    return Listener(
      onPointerDown: (PointerDownEvent event) => hub.shield(event.pointer),
      onPointerPanZoomStart: (PointerPanZoomStartEvent event) => hub.shield(event.pointer),
      child: child,
    );
  }
}
