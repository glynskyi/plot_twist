/// Composable, extensible charts for Flutter.
///
/// A [Chart] is a stack in data space: series, real widgets and behaviors are
/// ordinary children that share one coordinate snapshot (a [ChartView]) per
/// frame. Panning and zooming move things during layout and paint — widgets
/// are never rebuilt because the view changed.
library;

export 'src/behaviors/animated_chart_data.dart';
export 'src/behaviors/chart_crosshair.dart';
export 'src/behaviors/chart_loader.dart';
export 'src/behaviors/chart_pan_zoom.dart';
export 'src/behaviors/chart_tooltip.dart';
export 'src/core/chart_controller.dart';
export 'src/core/chart_view.dart';
export 'src/core/range.dart';
export 'src/core/scale.dart';
export 'src/core/scale_controller.dart' hide ChartExtentSource;
export 'src/core/series.dart';
export 'src/core/ticks.dart';
export 'src/data/chart_data.dart';
export 'src/interaction/pan_zoom_recognizer.dart';
export 'src/interaction/pointer_hub.dart';
export 'src/layers/chart_data_labels.dart';
export 'src/layers/chart_grid.dart';
export 'src/layers/chart_legend.dart';
export 'src/layers/chart_reference_line.dart';
export 'src/rendering/render_chart_axis.dart';
export 'src/rendering/render_chart_layout.dart';
export 'src/rendering/render_chart_stack.dart';
export 'src/rendering/view_channel.dart';
export 'src/series/bar_series.dart';
export 'src/series/candlestick_series.dart';
export 'src/series/line_series.dart';
export 'src/series/scatter_series.dart';
export 'src/widgets/chart.dart';
export 'src/widgets/chart_axis.dart';
export 'src/widgets/chart_gesture_detector.dart';
export 'src/widgets/chart_layout_builder.dart';
export 'src/widgets/chart_paint.dart';
export 'src/widgets/chart_scope.dart';
export 'src/widgets/chart_stack.dart';
export 'src/widgets/chart_theme.dart';
