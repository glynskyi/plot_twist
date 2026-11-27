// Renders the media used to show plot_twist: a still of every demo in light
// and dark, frame sequences of scripted interactions, the clips of the
// README's grid of chart types, and two link-preview cards. It is not part of
// the test suite. Run `tool/make_media.sh`, which runs this file and turns the
// frames into GIFs, MP4s, WebPs and PNGs.
//
// Unlike the test suite, this turns real shadows on and leaves out the
// gallery's frame, so the images look like the app does.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plot_twist/plot_twist.dart';
import 'package:plot_twist_example/main.dart';
import 'package:plot_twist_example/shared/ui.dart';

final Directory out = Directory('build/media');

/// One frame of a clip: 25 frames a second.
const Duration frame = Duration(milliseconds: 40);

Future<void> _loadFonts() async {
  final String fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$fonts/$name').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(read('Roboto-Regular.ttf'))
        ..addFont(read('Roboto-Medium.ttf'))
        ..addFont(read('Roboto-Bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

ThemeData _theme(Brightness brightness) => ThemeData(
  colorSchemeSeed: const Color(0xFF3F6FB5),
  brightness: brightness,
  fontFamily: 'Roboto',
);

Demo _demo(String id) => demos.firstWhere((Demo demo) => demo.id == id);

/// Where the simulated pointer is. The clips draw it as a translucent dot.
final ValueNotifier<Offset?> pointer = ValueNotifier<Offset?>(null);

class _PointerDot extends StatelessWidget {
  const _PointerDot();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Offset?>(
    valueListenable: pointer,
    builder: (BuildContext context, Offset? at, Widget? child) => at == null
        ? const SizedBox.shrink()
        : Positioned(left: at.dx - 14, top: at.dy - 14, child: child!),
    child: IgnorePointer(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x403F6FB5),
          border: Border.all(color: const Color(0xB03F6FB5), width: 2),
        ),
      ),
    ),
  );
}

/// A demo on its own, without the gallery's title, summary and buttons.
/// [wrap], if given, wraps the demo.
Widget _stage(
  Demo demo,
  Brightness brightness,
  GlobalKey key, {
  Widget Function(Widget demo)? wrap,
}) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(brightness),
    home: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MaterialChartTheme(
                child: Builder(
                  builder: (BuildContext context) =>
                      wrap == null ? demo.builder(context) : wrap(demo.builder(context)),
                ),
              ),
            ),
          ),
          const _PointerDot(),
        ],
      ),
    ),
  ),
);

/// A link-preview card: the name and what it does beside a live demo.
Widget _card(Demo demo, GlobalKey key) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    home: Builder(
      builder: (BuildContext context) {
        final TextTheme text = Theme.of(context).textTheme;
        final ColorScheme colors = Theme.of(context).colorScheme;
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(48, 40, 32, 32),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'plot_twist',
                        style: text.displaySmall!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Composable charts for Flutter', style: text.headlineSmall),
                      const SizedBox(height: 24),
                      for (final String line in <String>[
                        'Any widget as a tooltip, marker or axis label',
                        'Pan and zoom a million points',
                        'Lazy history, live data, candlesticks',
                        'MIT, widgets layer only',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('·  $line', style: text.titleMedium),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: MaterialChartTheme(child: Builder(builder: demo.builder)),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ),
);

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
  });
}

/// Records a clip: every call advances time by [frame] and writes a frame.
class _Recorder {
  _Recorder(this.tester, this.key, this.name, {this.folder = 'frames'});

  final WidgetTester tester;
  final GlobalKey key;
  final String name;

  /// The folder under [out] that holds a folder of frames per clip.
  final String folder;
  final TestPointer mouse = TestPointer(7, PointerDeviceKind.mouse);
  int _count = 0;

  String get _dir => '${out.path}/$folder/$name';

  Rect get plot => tester.getRect(find.byType(Chart, skipOffstage: false).first);

  Offset at(double fx, double fy, [Rect? rect]) {
    final Rect r = rect ?? plot;
    return Offset(r.left + r.width * fx, r.top + r.height * fy);
  }

  Future<void> shoot() async {
    await tester.pump(frame);
    await _capture(tester, key, '$_dir/${(_count++).toString().padLeft(4, '0')}.png');
  }

  Future<void> hold(int frames) async {
    for (int i = 0; i < frames; i++) {
      await shoot();
    }
  }

  Future<void> hover(Offset from, Offset to, int frames) async {
    for (int i = 0; i <= frames; i++) {
      final Offset p = Offset.lerp(from, to, Curves.easeInOut.transform(i / frames))!;
      pointer.value = p;
      await tester.sendEventToBinding(mouse.hover(p));
      await shoot();
    }
  }

  /// Turns the mouse wheel at [at]. Without [hover], the mouse does not move
  /// there first, so the chart shows no crosshair or tooltip.
  Future<void> wheel(
    Offset at,
    double dy,
    int steps, {
    int framesPerStep = 2,
    bool hover = true,
  }) async {
    pointer.value = at;
    if (hover) await tester.sendEventToBinding(mouse.hover(at));
    for (int i = 0; i < steps; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          viewId: tester.view.viewId,
          device: mouse.device,
          position: at,
          scrollDelta: Offset(0, dy),
        ),
      );
      await hold(framesPerStep);
    }
  }

  Future<void> drag(Offset from, Offset to, int frames) async {
    pointer.value = from;
    final TestGesture touch = await tester.startGesture(from);
    await shoot();
    for (int i = 1; i <= frames; i++) {
      final Offset p = Offset.lerp(from, to, Curves.easeInOut.transform(i / frames))!;
      pointer.value = p;
      await touch.moveTo(p);
      await shoot();
    }
    await touch.up();
    pointer.value = null;
  }

  /// A tap, by default where the mouse already is. Without [hover], it is a
  /// touch alone, which shows no Material tooltip on the button it taps.
  Future<void> tap(Offset at, {bool hover = true}) async {
    pointer.value = at;
    if (hover) await tester.sendEventToBinding(mouse.hover(at));
    await tester.tapAt(at);
  }

  /// Two taps 80 ms apart, which return a zoomed chart to its range. Without
  /// [hover], they are touches alone.
  Future<void> doubleTap(Offset at, {bool hover = true}) async {
    await tap(at, hover: hover);
    await hold(2);
    await tap(at, hover: hover);
  }

  /// Hovers along [path], which maps 0 to 1 to a position, in [frames] steps.
  Future<void> hoverAlong(Offset Function(double t) path, int frames) async {
    for (int i = 0; i <= frames; i++) {
      final Offset p = path(i / frames);
      pointer.value = p;
      await tester.sendEventToBinding(mouse.hover(p));
      await shoot();
    }
  }

  /// The pointer goes away: hover effects end and the dot disappears.
  Future<void> leave() async {
    pointer.value = null;
    await tester.sendEventToBinding(mouse.removePointer());
  }

  /// Writes the crop that keeps only [target] and [margin] around it, for
  /// clips whose demo shows controls or readouts that mean nothing in a
  /// recording. With [square], the crop is a square around the same centre,
  /// and it has to fit on the stage.
  void cropTo(Finder target, {EdgeInsets margin = const EdgeInsets.all(8), bool square = false}) {
    Rect? bounds;
    for (final Element element in target.evaluate()) {
      final RenderBox box = element.renderObject! as RenderBox;
      final Rect rect = box.localToGlobal(Offset.zero) & box.size;
      bounds = bounds?.expandToInclude(rect) ?? rect;
    }
    final double ratio = tester.view.devicePixelRatio;
    final Rect stage = Offset.zero & tester.view.physicalSize / ratio;
    Rect crop = margin.inflateRect(bounds!);
    if (square) {
      final double side = math.max(crop.width, crop.height);
      crop = Rect.fromCenter(center: crop.center, width: side, height: side);
      expect(
        crop.left >= -0.5 && crop.top >= -0.5 && crop.right <= stage.right + 0.5,
        isTrue,
        reason: 'The square crop $crop of $name does not fit on the stage $stage.',
      );
      expect(crop.bottom <= stage.bottom + 0.5, isTrue, reason: 'The crop of $name is too tall.');
    }
    final Rect px = crop.intersect(stage);
    int even(double v) => (v * ratio).round() ~/ 2 * 2;
    int width = even(px.width);
    int height = even(px.height);
    if (square) width = height = math.min(width, height);
    File('$_dir/crop.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('$width:$height:${even(px.left)}:${even(px.top)}');
  }
}

typedef _Script = Future<void> Function(_Recorder r);

/// The clips: which demo, what the pointer does, and whether to crop.
final Map<String, (String, bool, _Script)> clips = <String, (String, bool, _Script)>{
  'a02-pan-zoom': (
    'A2',
    true,
    (_Recorder r) async {
      await r.hold(8);
      await r.wheel(r.at(0.6, 0.45), -60, 14);
      await r.drag(r.at(0.6, 0.45), r.at(0.35, 0.65), 30);
      await r.wheel(r.at(0.5, 0.5), 60, 10);
      await r.hold(10);
    },
  ),
  'a03-edge-crossing': (
    'A3',
    false,
    (_Recorder r) async {
      await r.hold(8);
      await r.drag(r.at(0.75, 0.5), r.at(0.3, 0.5), 45);
      await r.hold(10);
      await r.drag(r.at(0.3, 0.5), r.at(0.6, 0.5), 35);
      await r.hold(10);
    },
  ),
  'a04-widget-tooltip': (
    'A4',
    false,
    (_Recorder r) async {
      await r.hold(5);
      await r.hover(r.at(0.12, 0.5), r.at(0.62, 0.5), 50);
      await r.tap(r.at(0.62, 0.5));
      await r.hold(12);
      await r.drag(r.at(0.75, 0.8), r.at(0.55, 0.8), 25);
      await r.hold(15);
    },
  ),
  'a10-million-points': (
    'A10',
    true,
    (_Recorder r) async {
      await r.hold(8);
      await r.wheel(r.at(0.55, 0.5), -70, 18);
      await r.drag(r.at(0.6, 0.5), r.at(0.35, 0.5), 30);
      await r.wheel(r.at(0.5, 0.5), 70, 18);
      await r.hold(8);
    },
  ),
  'a11-combo': (
    'A11',
    false,
    (_Recorder r) async {
      await r.hold(5);
      await r.hover(r.at(0.08, 0.45), r.at(0.92, 0.45), 90);
      await r.hold(10);
    },
  ),
  'a15-live-ecg': (
    'A15',
    false,
    (_Recorder r) async {
      await r.hold(60);
      await r.drag(r.at(0.45, 0.5), r.at(0.8, 0.5), 25);
      await r.hold(25);
    },
  ),
  'a16-linked': (
    'A16',
    true,
    (_Recorder r) async {
      await r.hold(5);
      await r.drag(r.at(0.7, 0.5), r.at(0.4, 0.5), 35);
      await r.hold(5);
      await r.hover(r.at(0.15, 0.5), r.at(0.85, 0.5), 60);
      await r.hold(8);
    },
  ),
  'a26-candles': (
    'A26',
    false,
    (_Recorder r) async {
      await r.hold(15);
      await r.wheel(r.at(0.7, 0.5), 80, 14);
      await r.hold(8);
      await r.wheel(r.at(0.85, 0.5), -80, 14);
      await r.hover(r.at(0.5, 0.45), r.at(0.88, 0.4), 40);
      await r.hold(15);
    },
  ),
};

/// A clip of the README's grid of chart types.
///
/// The grid shows a clip 232 px wide. So that its labels stay readable, the
/// demo is laid out about as big as a chart in a phone app, and the clip keeps
/// a square around one chart. Each clip ends as it began, so its loop does not
/// jump.
class _GridClip {
  const _GridClip(
    this.demo,
    this.script, {
    this.size = const Size(340, 340),
    this.target,
    this.margin = const EdgeInsets.all(8),
    this.fromMount = false,
    this.wrap,
  });

  /// The id of the demo.
  final String demo;

  final _Script script;

  /// The stage, in logical pixels.
  final Size size;

  /// What the clip keeps; the whole stage when null.
  final Finder Function()? target;

  /// The room kept around [target].
  final EdgeInsets margin;

  /// Whether recording starts at the first frame, so an appear animation shows.
  final bool fromMount;

  /// Wraps the demo, to hide what means nothing in a clip.
  final Widget Function(Widget demo)? wrap;
}

Finder _chart() => find.byType(Chart, skipOffstage: false);
Finder _polar(int index) => find.byType(PolarChart, skipOffstage: false).at(index);

/// A21's three charts stand one above the other on a tall stage, so a square
/// around one of them keeps its neighbours out.
const Size _tall = Size(400, 1000);

/// The clips of the grid, by the name of their file.
final Map<String, _GridClip> _gridClips = <String, _GridClip>{
  'line': _GridClip(
    'A10',
    (_Recorder r) async {
      await r.hold(6);
      await r.wheel(r.at(0.65, 0.5), -70, 12, framesPerStep: 3);
      await r.drag(r.at(0.65, 0.5), r.at(0.3, 0.5), 20);
      await r.hold(6);
      await r.doubleTap(r.at(0.5, 0.5));
      await r.hold(10);
      await r.leave();
      await r.hold(6);
    },
    // The readout above the chart measures real frames, which a test does not
    // have. Its text is hidden and the crop starts just below the switch, so
    // the label of a tick at the top of the plot is not cut. The stage makes
    // that crop square.
    size: const Size(340, 390),
    target: _chart,
    margin: const EdgeInsets.fromLTRB(8, 7, 8, 8),
    wrap: (Widget demo) => DefaultTextStyle.merge(
      style: const TextStyle(color: Color(0x00000000)),
      child: demo,
    ),
  ),
  'area': _GridClip('A6', (_Recorder r) async {
    await r.hold(8);
    await r.drag(r.at(0.8, 0.55), r.at(0.2, 0.55), 40);
    await r.hold(8);
    await r.drag(r.at(0.2, 0.55), r.at(0.8, 0.55), 40);
    await r.hold(8);
  }, target: _chart),
  'bar': _GridClip(
    'A19',
    (_Recorder r) async {
      await r.hold(8);
      for (final Finder button in <Finder>[
        find.text('Month'),
        find.text('Year'),
        find.byIcon(Icons.rotate_90_degrees_cw),
        find.text('Week'),
        find.byIcon(Icons.rotate_90_degrees_cw),
      ]) {
        await r.tap(r.tester.getCenter(button), hover: false);
        await r.hold(18);
      }
      pointer.value = null;
      await r.hold(4);
    },
    // The period switch and the button stay in the clip, and they need a
    // wider stage than the other demos.
    size: const Size(372, 372),
  ),
  'combo': _GridClip(
    'A11',
    (_Recorder r) async {
      await r.hold(30);
      await r.hover(r.at(0.1, 0.5), r.at(0.9, 0.5), 60);
      await r.hold(10);
      await r.leave();
      await r.hold(12);
    },
    target: _chart,
    fromMount: true,
  ),
  // A frame that moves the whole sky of 50,000 stars costs more than ten that
  // only move the crosshair, so the clip zooms in with one flick of the
  // wheel, hovers, and goes back with a double tap.
  'scatter': _GridClip('A2', (_Recorder r) async {
    final Offset at = r.at(0.6, 0.45);
    await r.hold(6);
    await r.wheel(at, -60, 10, framesPerStep: 1);
    await r.hold(4);
    await r.hover(at, r.at(0.4, 0.6), 24);
    await r.hover(r.at(0.4, 0.6), at, 20);
    await r.doubleTap(at);
    await r.hold(8);
    await r.leave();
    await r.hold(8);
  }, target: _chart),
  // The candle tooltip is wider than a chart this small, so this clip leaves
  // it out: the mouse only turns the wheel and the way back is a touch double
  // tap, so no crosshair shows. It zooms out to the whole history and back
  // while trades arrive.
  'candlestick': _GridClip('A26', (_Recorder r) async {
    await r.hold(10);
    await r.wheel(r.at(0.7, 0.5), 80, 12, hover: false);
    await r.hold(12);
    await r.doubleTap(r.at(0.7, 0.5), hover: false);
    pointer.value = null;
    await r.hold(30);
  }, target: _chart),
  'doughnut': _GridClip(
    'A21',
    (_Recorder r) async {
      final Rect chart = r.tester.getRect(_polar(0));
      final double legend = r.tester.getRect(find.byType(ChartLegend).first).top;
      final Offset centre = Offset(chart.center.dx, (chart.top + legend) / 2);
      final double radius = (math.min(chart.width, legend - chart.top) - 20) / 2;
      // Travel's slice is the third, around eight o'clock, in the middle of the ring.
      final Offset slice = centre + Offset.fromDirection(math.pi * 0.877, radius * 0.8);
      final Offset entry = r.tester.getCenter(find.text('Travel'));
      await r.hold(25);
      await r.tap(entry);
      await r.hold(8);
      await r.hover(entry, slice, 20);
      await r.hold(16);
      await r.hover(slice, entry, 16);
      await r.tap(entry);
      await r.hold(8);
      await r.leave();
      await r.hold(10);
    },
    size: _tall,
    target: () => _polar(0),
    margin: EdgeInsets.zero,
    fromMount: true,
  ),
  'gauge': _GridClip(
    'A21',
    (_Recorder r) async {
      final Rect slider = r.tester.getRect(find.byType(Slider));
      // The track starts and ends 24 px inside the slider.
      Offset at(double value) =>
          Offset(slider.left + 24 + (slider.width - 48) * value / 100, slider.center.dy);
      await r.hold(8);
      await r.drag(at(72), at(96), 18);
      await r.hold(12);
      await r.drag(at(96), at(24), 30);
      await r.hold(12);
      await r.drag(at(24), at(72), 18);
      await r.hold(10);
      expect(find.text('72%'), findsOneWidget, reason: 'The gauge ends where it began.');
    },
    size: _tall,
    target: () => _polar(1),
    margin: EdgeInsets.zero,
  ),
  'radar': _GridClip(
    'A21',
    (_Recorder r) async {
      final Rect chart = r.tester.getRect(_polar(2));
      final double legend = r.tester.getRect(find.byType(ChartLegend).last).top;
      final Offset centre = Offset(chart.center.dx, (chart.top + legend) / 2);
      final double radius = 0.25 * math.min(chart.width, legend - chart.top);
      // Once round, clockwise from Speed at the top.
      Offset round(double t) =>
          centre + Offset.fromDirection(-math.pi / 2 + 2 * math.pi * t, radius);
      await r.hold(6);
      await r.hoverAlong(round, 100);
      await r.hold(6);
      await r.leave();
      await r.hold(8);
    },
    size: _tall,
    target: () => _polar(2),
    margin: EdgeInsets.zero,
  ),
};

void main() {
  setUpAll(_loadFonts);

  // Real shadows instead of the test framework's outlines. The framework checks
  // that the flag is back to true when a test body ends, so each body restores it.
  Future<void> withShadows(Future<void> Function() body) async {
    debugDisableShadows = false;
    try {
      await body();
    } finally {
      debugDisableShadows = true;
    }
  }

  for (final Demo demo in demos) {
    for (final Brightness brightness in Brightness.values) {
      final String name = '${demo.id.toLowerCase()}-${brightness.name}';
      testWidgets(
        'still $name',
        (WidgetTester tester) => withShadows(() async {
          tester.view.physicalSize = const Size(2000, 1240);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final GlobalKey key = GlobalKey();
          await tester.pumpWidget(_stage(demo, brightness, key));
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 600));
          final Rect plot = tester.getRect(find.byType(Chart, skipOffstage: false).first);
          final TestPointer mouse = TestPointer(9, PointerDeviceKind.mouse);
          await tester.sendEventToBinding(
            mouse.hover(Offset(plot.left + plot.width * 0.62, plot.top + plot.height * 0.5)),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await _capture(tester, key, '${out.path}/stills/$name.png');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        }),
      );
    }
  }

  for (final MapEntry<String, (String, bool, _Script)> clip in clips.entries) {
    testWidgets(
      'clip ${clip.key}',
      (WidgetTester tester) => withShadows(() async {
        tester.view.physicalSize = const Size(1800, 1120);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final (String id, bool crop, _Script script) = clip.value;
        final GlobalKey key = GlobalKey();
        pointer.value = null;
        await tester.pumpWidget(_stage(_demo(id), Brightness.light, key));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        final _Recorder recorder = _Recorder(tester, key, clip.key);
        if (crop) recorder.cropTo(find.byType(Chart, skipOffstage: false));
        await script(recorder);
        pointer.value = null;
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      }),
    );
  }

  for (final MapEntry<String, _GridClip> entry in _gridClips.entries) {
    testWidgets(
      'grid ${entry.key}',
      (WidgetTester tester) => withShadows(() async {
        final _GridClip clip = entry.value;
        tester.view.physicalSize = clip.size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final GlobalKey key = GlobalKey();
        pointer.value = null;
        await tester.pumpWidget(_stage(_demo(clip.demo), Brightness.light, key, wrap: clip.wrap));
        if (!clip.fromMount) {
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 600));
        }
        final Finder? target = clip.target?.call();
        final _Recorder recorder = _Recorder(tester, key, entry.key, folder: 'grid')
          ..cropTo(
            target ?? find.byKey(key),
            margin: target == null ? EdgeInsets.zero : clip.margin,
            square: true,
          );
        await clip.script(recorder);
        pointer.value = null;
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      }),
    );
  }

  for (final (String name, Size size) in <(String, Size)>[
    ('og', const Size(1200, 630)),
    ('social-preview', const Size(1280, 640)),
  ]) {
    testWidgets(
      'card $name',
      (WidgetTester tester) => withShadows(() async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final GlobalKey key = GlobalKey();
        await tester.pumpWidget(_card(_demo('A26'), key));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        await _capture(tester, key, '${out.path}/cards/$name@2x.png');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      }),
    );
  }
}
