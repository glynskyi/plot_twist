// Renders the media used to show plot_twist: a still of every demo in light
// and dark, frame sequences of scripted interactions, and two link-preview
// cards. It is not part of the test suite. Run `tool/make_media.sh`, which
// runs this file and turns the frames into GIFs, MP4s and PNGs with ffmpeg.
//
// Unlike the test suite, this turns real shadows on and leaves out the
// gallery's frame, so the images look like the app does.
import 'dart:io';
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
Widget _stage(Demo demo, Brightness brightness, GlobalKey key) => RepaintBoundary(
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
              child: MaterialChartTheme(child: Builder(builder: demo.builder)),
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
  _Recorder(this.tester, this.key, this.name);

  final WidgetTester tester;
  final GlobalKey key;
  final String name;
  final TestPointer mouse = TestPointer(7, PointerDeviceKind.mouse);
  int _count = 0;

  Rect get plot => tester.getRect(find.byType(Chart, skipOffstage: false).first);

  Offset at(double fx, double fy, [Rect? rect]) {
    final Rect r = rect ?? plot;
    return Offset(r.left + r.width * fx, r.top + r.height * fy);
  }

  Future<void> shoot() async {
    await tester.pump(frame);
    await _capture(
      tester,
      key,
      '${out.path}/frames/$name/${(_count++).toString().padLeft(4, '0')}.png',
    );
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

  Future<void> wheel(Offset at, double dy, int steps, {int framesPerStep = 2}) async {
    pointer.value = at;
    await tester.sendEventToBinding(mouse.hover(at));
    for (int i = 0; i < steps; i++) {
      await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
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

  Future<void> tap(Offset at) async {
    pointer.value = at;
    await tester.sendEventToBinding(mouse.hover(at));
    await tester.tapAt(at);
  }

  /// Writes the crop that keeps only the charts, for clips whose demo shows
  /// controls or readouts that mean nothing in a recording.
  void cropToCharts() {
    Rect? bounds;
    for (final Element chart in find.byType(Chart, skipOffstage: false).evaluate()) {
      final RenderBox box = chart.renderObject! as RenderBox;
      final Rect rect = box.localToGlobal(Offset.zero) & box.size;
      bounds = bounds?.expandToInclude(rect) ?? rect;
    }
    final double ratio = tester.view.devicePixelRatio;
    final Rect px = bounds!.inflate(8).intersect(Offset.zero & tester.view.physicalSize / ratio);
    int even(double v) => (v * ratio).round() ~/ 2 * 2;
    File('${out.path}/frames/$name/crop.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('${even(px.width)}:${even(px.height)}:${even(px.left)}:${even(px.top)}');
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
        if (crop) recorder.cropToCharts();
        await script(recorder);
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
