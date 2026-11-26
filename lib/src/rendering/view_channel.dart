import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/chart_view.dart';

/// Carries the current [ChartView] from a chart to every chart-aware render
/// object below it.
///
/// The chart publishes a new view while it lays itself out and tells each
/// [ChartViewDependent] about it, so they repaint or reposition in that same
/// frame — widgets are never rebuilt because the chart was panned or zoomed.
class ChartViewChannel {
  ChartView? _view;
  final Set<ChartViewDependent> _dependents = <ChartViewDependent>{};

  /// Whether the chart has been laid out at least once.
  bool get hasView => _view != null;

  /// The current view.
  ///
  /// Valid during layout, paint and hit testing of anything below the chart.
  ChartView get view {
    final ChartView? result = _view;
    if (result == null) {
      throw FlutterError(
        'The chart view was read before the chart was laid out.\n'
        'A ChartView is only available during layout, paint and hit testing '
        'of widgets below a Chart. In event handlers, use ChartController.view.',
      );
    }
    return result;
  }

  /// Publishes [view]. [inLayoutCallback] must run its argument inside
  /// `RenderObject.invokeLayoutCallback` of the chart. Returns whether the view
  /// changed.
  ///
  /// With [force], dependents are told even when the view is equal to the
  /// last one, for a change they depend on that the view does not show.
  @internal
  bool publish(
    ChartView view,
    void Function(VoidCallback callback) inLayoutCallback, {
    bool force = false,
  }) {
    final ChartView? old = _view;
    if (old == view && !force) return false;
    _view = view;
    if (_dependents.isNotEmpty) {
      inLayoutCallback(() {
        for (final ChartViewDependent dependent in _dependents.toList(growable: false)) {
          if (dependent.attached) dependent.didChangeChartView(old, view);
        }
      });
    }
    return true;
  }
}

/// A render object that depends on the chart's [ChartView].
///
/// Mix this in, set [channel] from your widget (`ChartScope.of(context).channel`)
/// and read [chartView] in `performLayout` and `paint`. Override
/// [didChangeChartView] to say what a view change invalidates: the default is
/// layout; painters should call `markNeedsPaint` instead.
mixin ChartViewDependent on RenderObject {
  ChartViewChannel? _channel;

  /// The channel this object reads the view from.
  ChartViewChannel? get channel => _channel;
  set channel(ChartViewChannel? value) {
    if (identical(value, _channel)) return;
    if (attached) _channel?._dependents.remove(this);
    _channel = value;
    if (attached) {
      value?._dependents.add(this);
      markNeedsLayout();
    }
  }

  /// Whether a view is available.
  bool get hasChartView => _channel?.hasView ?? false;

  /// The chart's current view.
  ChartView get chartView {
    final ChartViewChannel? c = _channel;
    if (c == null) {
      throw FlutterError('$runtimeType has no ChartViewChannel. Is it below a Chart?');
    }
    return c.view;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _channel?._dependents.add(this);
  }

  @override
  void detach() {
    _channel?._dependents.remove(this);
    super.detach();
  }

  /// Called while the chart is being laid out, when its view changed.
  ///
  /// Mark whatever depends on the view as dirty here. Do not read layout
  /// results of other objects.
  void didChangeChartView(ChartView? oldView, ChartView newView) => markNeedsLayout();
}
