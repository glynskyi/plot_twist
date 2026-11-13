import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';

import '../shared/fake.dart';
import '../shared/ui.dart';

/// A6 — Widget markers that exist only while their data is on screen. Forty
/// pins sit on a 2,000-point profile; the builder runs when a pin enters or
/// leaves the window, never while the chart is merely panned.
class PhotoPinsDemo extends StatefulWidget {
  const PhotoPinsDemo({super.key});

  @override
  State<PhotoPinsDemo> createState() => _PhotoPinsDemoState();
}

class _PhotoPinsDemoState extends State<PhotoPinsDemo> {
  // Elevation in metres every 10 m along a 20 km track.
  final ChartData profile = wave(2000, amplitude: 300, period: 700, base: 900, dx: 0.01);

  // One pin every 500 m.
  static const int count = 40;
  static double pinX(int p) => 0.25 + p * 0.5;

  @override
  void dispose() {
    profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Chart(
      x: const .linear(range: .fixed(0, 4)),
      y: const .linear(range: .fit(padding: 0.3)),
      left: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.label} m')],
      bottom: <Widget>[ChartAxis(format: (ChartTick tick) => '${tick.label} km')],
      children: <Widget>[
        const ChartGrid(),
        LineSeries(data: profile, fillColor: scheme.primary.withValues(alpha: 0.12)),
        const ChartPanZoom(),
        ChartLayoutBuilder<(int, int)>(
          // The pins inside the window, plus one on each side.
          selector: (ChartView view) => (
            math.max(0, ((view.x.min - 0.25) / 0.5).floor()),
            math.min(count, ((view.x.max - 0.25) / 0.5).ceil() + 1),
          ),
          builder: (BuildContext context, (int, int) visible) => ChartStack(
            children: <Widget>[
              for (int p = visible.$1; p < visible.$2; p++)
                ChartPositioned(
                  key: ValueKey<int>(p),
                  x: .value(pinX(p)),
                  y: .value(profile.interpolate(pinX(p))!),
                  alignment: .bottomCenter,
                  child: _PhotoPin(index: p),
                ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Pill('${visible.$2 - visible.$1} of $count pin widgets exist'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoPin extends StatelessWidget {
  const _PhotoPin({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final Color color = ChartThemeData.defaultPalette[index % 8];
    // An ordinary Material Tooltip works: the pin is an ordinary widget.
    return Tooltip(
      message: 'Photo ${index + 1}, at ${_PhotoPinsDemoState.pinX(index)} km',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            child: const Icon(Icons.photo_camera, size: 15, color: Colors.white),
          ),
          Container(width: 2, height: 10, color: color),
        ],
      ),
    );
  }
}
