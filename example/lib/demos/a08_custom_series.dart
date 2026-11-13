import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/ui.dart';

class Stage {
  const Stage(this.start, this.end, this.level);

  /// Minutes since falling asleep.
  final double start;
  final double end;

  /// 0 deep, 1 light, 2 REM, 3 awake.
  final int level;
}

const List<String> stageNames = <String>['Deep', 'Light', 'REM', 'Awake'];

/// A8 — A series type the package does not have, written in the app: a sleep
/// hypnogram. Implementing [bounds] and [collectHits] is all it takes for
/// automatic ranges, the crosshair, the tooltip and the legend to work with it.
class HypnogramPainter extends ChartSeriesPainter {
  const HypnogramPainter(this.stages, this.colors);

  final List<Stage> stages;
  final List<Color> colors;

  @override
  void paint(ChartPaintContext context) {
    final ChartView view = context.view;
    Stage? previous;
    for (final Stage s in stages) {
      if (s.end >= view.x.min && s.start <= view.x.max) {
        final Rect bar = view.toRect(s.start, s.level - 0.3, s.end, s.level + 0.3);
        final Paint paint = Paint()..color = colors[s.level];
        context.canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(4)), paint);
        if (previous != null) {
          context.canvas.drawLine(
            view.toPixel(s.start, previous.level.toDouble()),
            view.toPixel(s.start, s.level.toDouble()),
            paint..strokeWidth = 1.5,
          );
        }
      }
      previous = s;
    }
  }

  @override
  ChartDataBounds bounds({ChartRange? xWindow, ChartRange? yWindow}) => ChartDataBounds(
    x: ChartRange(stages.first.start, stages.last.end),
    y: const ChartRange(-0.6, 3.6),
  );

  @override
  void collectHits(ChartHitQuery query, List<ChartHit> hits) {
    final double x = query.view.x.toValue(query.position.dx);
    for (final Stage s in stages) {
      if (x < s.start || x > s.end) continue;
      final double middle = (s.start + s.end) / 2;
      final Offset top = query.view.toPixel(middle, s.level + 0.3);
      hits.add(ChartHit(x: middle, y: s.level.toDouble(), position: top, distance: 0, datum: s));
    }
  }

  @override
  bool shouldRepaint(HypnogramPainter oldDelegate) =>
      oldDelegate.stages != stages || oldDelegate.colors != colors;
}

class CustomSeriesDemo extends StatelessWidget {
  const CustomSeriesDemo({super.key});

  static final List<Stage> night = _night();

  // (minutes, stage) for one night.
  static List<Stage> _night() {
    double t = 0;
    return <Stage>[
      for (final (double minutes, int level) in const <(double, int)>[
        (12, 3), (25, 1), (48, 0), (20, 1), (22, 2), (35, 1), (40, 0), (15, 1), (30, 2), //
        (8, 3), (45, 1), (28, 0), (25, 1), (38, 2), (30, 1), (10, 3),
      ])
        Stage(t, t += minutes, level),
    ];
  }

  static String _clock(double minutes) =>
      '${(23 + minutes ~/ 60) % 24}:${(minutes % 60).round().toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
    ];
    return Chart(
      y: const .linear(ticks: FixedTicks(<double>[0, 1, 2, 3])),
      left: <Widget>[ChartAxis(format: (ChartTick tick) => stageNames[tick.value.round()])],
      bottom: <Widget>[ChartAxis(format: (ChartTick tick) => _clock(tick.value))],
      children: <Widget>[
        const ChartGrid(vertical: false),
        ChartPaint(id: 'sleep', label: 'Sleep', painter: HypnogramPainter(night, colors)),
        const ChartPanZoom(),
        const ChartCrosshair(showPoints: false),
        ChartTooltip(
          builder: (BuildContext context, List<ChartHit> hits) {
            final Stage s = hits.first.datum! as Stage;
            return Pill(
              '${stageNames[s.level]} · ${(s.end - s.start).round()} min from ${_clock(s.start)}',
              color: colors[s.level],
            );
          },
        ),
      ],
    );
  }
}
