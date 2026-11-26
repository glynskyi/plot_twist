import 'package:flutter/widgets.dart';

import '../../plot_twist.dart';

/// Animates the series below it into view when they are first shown: bars
/// grow, a line is uncovered.
///
/// Wrap a series, or a whole chart:
///
/// ```dart
/// ChartAppear(child: Chart(children: [BarSeries(data: sales)]))
///
/// Chart(children: [
///   BarSeries(data: sales),
///   ChartAppear(effect: ChartAppearEffect.reveal, child: LineSeries(data: trend)),
/// ])
/// ```
///
/// Only the painting of the series is animated. The data, the ranges of the
/// scales and what a crosshair finds are final from the first frame, so the
/// axes stand still while the series come in. It works with every series,
/// also with a painter of your own. Grids, crosshairs and reference lines are
/// not animated.
///
/// The animation plays once, when this widget enters the tree; give it a new
/// `key` to play it again. It is skipped when the platform asks for reduced
/// motion (`MediaQuery.disableAnimations`).
///
/// To animate from one data set to another, use `AnimatedChartData`.
class ChartAppear extends StatefulWidget {
  /// Creates an appear animation for the series in [child].
  const ChartAppear({
    super.key,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.delay = Duration.zero,
    this.effect = ChartAppearEffect.growY,
    required this.child,
  });

  /// Length of the animation.
  final Duration duration;

  /// Easing of the animation.
  final Curve curve;

  /// How long the series stay hidden before the animation starts.
  final Duration delay;

  /// How a series is drawn while it appears.
  final ChartAppearEffect effect;

  /// A series, a chart, or anything that contains series.
  final Widget child;

  @override
  State<ChartAppear> createState() => _ChartAppearState();
}

class _ChartAppearState extends State<ChartAppear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late Animation<double> _progress;
  bool _started = false;

  // One controller runs through the delay and the animation.
  void _configure() {
    final Duration total = widget.delay + widget.duration;
    _controller.duration = total;
    final double start = total > Duration.zero
        ? widget.delay.inMicroseconds / total.inMicroseconds
        : 0;
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(start.clamp(0.0, 1.0), 1, curve: widget.curve),
    );
  }

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The first place where the reduce-motion setting can be read.
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || _controller.duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ChartAppear oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.delay != widget.delay ||
        oldWidget.curve != widget.curve) {
      setState(_configure);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChartAppearScope(progress: _progress, effect: widget.effect, child: widget.child);
}
