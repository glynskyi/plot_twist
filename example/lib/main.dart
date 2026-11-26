import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'demos/a01_viewport_inspector.dart';
import 'demos/a02_star_map.dart';
import 'demos/a03_edge_crossing.dart';
import 'demos/a04_rich_tooltip.dart';
import 'demos/a05_infinite_history.dart';
import 'demos/a06_photo_pins.dart';
import 'demos/a07_widget_axis.dart';
import 'demos/a08_custom_series.dart';
import 'demos/a09_coexistence.dart';
import 'demos/a10_million_points.dart';
import 'demos/a11_weather_combo.dart';
import 'demos/a12_crosshair.dart';
import 'demos/a13_auto_fit.dart';
import 'demos/a14_scales.dart';
import 'demos/a15_live.dart';
import 'demos/a16_linked_panes.dart';
import 'demos/a17_annotations.dart';
import 'demos/a18_accessibility.dart';
import 'demos/a19_transitions.dart';
import 'demos/a20_legend.dart';
import 'demos/a21_donut.dart';
import 'demos/a22_styling.dart';
import 'demos/a23_navigator.dart';
import 'demos/a24_sparklines.dart';
import 'demos/a25_export.dart';
import 'demos/a26_candlesticks.dart';
import 'shared/ui.dart';

/// One demo per aspect a chart package has to get right.
final List<Demo> demos = <Demo>[
  Demo(
    'A1',
    'Viewport controller',
    'The visible range is a value you can read, set, animate and listen to.',
    'a01_viewport_inspector.dart',
    (_) => const ViewportInspectorDemo(),
  ),
  Demo(
    'A2',
    '2D pan and zoom',
    'Drag, pinch or scroll, drag an axis to stretch it, double-tap to reset. Hover picks the nearest star.',
    'a02_star_map.dart',
    (_) => const StarMapDemo(),
  ),
  Demo(
    'A3',
    'Edge-crossing marker',
    'A dot where the line crosses the Y axis. It stays on the axis while you scroll.',
    'a03_edge_crossing.dart',
    (_) => const EdgeCrossingDemo(),
  ),
  Demo(
    'A4',
    'Widgets as tooltips',
    'Tap a point: the tooltip is a card with an avatar, a chart and a working button.',
    'a04_rich_tooltip.dart',
    (_) => const RichTooltipDemo(),
  ),
  Demo(
    'A5',
    'Infinite history',
    'Scroll left: older data loads before you get there, and nothing jumps when it arrives.',
    'a05_infinite_history.dart',
    (_) => const InfiniteHistoryDemo(),
  ),
  Demo(
    'A6',
    'Lazy widget markers',
    'Forty widget pins on 2,000 points; only the visible ones exist.',
    'a06_photo_pins.dart',
    (_) => const PhotoPinsDemo(),
  ),
  Demo(
    'A7',
    'Widgets as axis labels',
    'Tick labels are widgets, and the axis sizes itself to fit them.',
    'a07_widget_axis.dart',
    (_) => const WidgetAxisDemo(),
  ),
  Demo(
    'A8',
    'Custom series',
    'A sleep hypnogram written in the app. Tooltip and automatic ranges just work.',
    'a08_custom_series.dart',
    (_) => const CustomSeriesDemo(),
  ),
  Demo(
    'A9',
    'Gestures that coexist',
    'Charts inside a scrolling page and a PageView, plus a custom long-press measure tool.',
    'a09_coexistence.dart',
    (_) => const CoexistenceDemo(),
  ),
  Demo(
    'A10',
    'One million points',
    'Pan and zoom a million-point line.',
    'a10_million_points.dart',
    (_) => const MillionPointsDemo(),
  ),
  Demo(
    'A11',
    'Mixed series, two Y axes',
    'Bars, a line and floating bars in one plot, on two scales. They grow in when first shown.',
    'a11_weather_combo.dart',
    (_) => const WeatherComboDemo(),
  ),
  Demo(
    'A12',
    'Crosshair as shared state',
    'Hover or long-press: crosshair, axis badges, tooltip and the table follow one value.',
    'a12_crosshair.dart',
    (_) => const CrosshairDemo(),
  ),
  Demo(
    'A13',
    'Auto-fit Y',
    'Y fits the visible data as you pan. Drag the Y axis to take over.',
    'a13_auto_fit.dart',
    (_) => const AutoFitDemo(),
  ),
  Demo(
    'A14',
    'Pluggable scales',
    'Time ticks that change unit, a log toggle with minor ticks, and a custom scale that skips weekends.',
    'a14_scales.dart',
    (_) => const ScalesDemo(),
  ),
  Demo(
    'A15',
    'Live data',
    'An ECG at 250 Hz that follows the newest sample until you pan away.',
    'a15_live.dart',
    (_) => const LiveDemo(),
  ),
  Demo(
    'A16',
    'Linked charts',
    'Three charts sharing one X scale, one crosshair and one gutter width.',
    'a16_linked_panes.dart',
    (_) => const LinkedPanesDemo(),
  ),
  Demo(
    'A17',
    'Editable annotations',
    'Drag the threshold and the ends of the trend line.',
    'a17_annotations.dart',
    (_) => const AnnotationsDemo(),
  ),
  Demo(
    'A18',
    'Accessibility',
    'A summary label, a semantics node per bar, and arrow-key navigation.',
    'a18_accessibility.dart',
    (_) => const AccessibilityDemo(),
  ),
  Demo(
    'A19',
    'Animated transitions',
    'Switch the period and the bars morph into the new data. Lay them down; their labels follow.',
    'a19_transitions.dart',
    (_) => const TransitionsDemo(),
  ),
  Demo(
    'A20',
    'Legend outside the chart',
    'Tap a legend item to hide a series, long-press to show only that one.',
    'a20_legend.dart',
    (_) => const LegendDemo(),
  ),
  Demo(
    'A21',
    'Non-Cartesian content',
    'A donut with a widget centre, widget callouts and a hover tooltip.',
    'a21_donut.dart',
    (_) => const DonutDemo(),
  ),
  Demo(
    'A22',
    'Data-driven styling',
    'Colour by value, a dashed forecast and theme switching.',
    'a22_styling.dart',
    (_) => const StylingDemo(),
  ),
  Demo(
    'A23',
    'Navigator by composition',
    'A range selector made from a second chart and one positioned widget.',
    'a23_navigator.dart',
    (_) => const NavigatorDemo(),
  ),
  Demo(
    'A24',
    'Many small charts',
    'Five hundred sparklines in a scrolling list.',
    'a24_sparklines.dart',
    (_) => const SparklinesDemo(),
  ),
  Demo(
    'A25',
    'Export',
    'Capture the chart, widgets included, as a 3× PNG.',
    'a25_export.dart',
    (_) => const ExportDemo(),
  ),
  Demo(
    'A26',
    'Candlesticks',
    'Daily candles with volume. The last candle trades live. Zoom out to see 5,000 trading days.',
    'a26_candlesticks.dart',
    (_) => const CandlesticksDemo(),
  ),
];

void main() => runApp(const GalleryApp());

/// The index of the demo a route such as `/a10` names, or null.
int? demoIndexOf(String? route) {
  final int index = demos.indexWhere((Demo demo) => demo.route == route);
  return index < 0 ? null : index;
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  static Route<void> _route(String? name) {
    final int? index = demoIndexOf(name);
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: index == null ? '/' : name),
      builder: (_) => Gallery(initial: index),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'plot_twist gallery',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF3F6FB5)),
    darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF3F6FB5), brightness: Brightness.dark),
    // On the web, a link such as `#/a10` opens that demo.
    onGenerateInitialRoutes: (String name) => <Route<void>>[_route(name)],
    onGenerateRoute: (RouteSettings settings) => _route(settings.name),
  );
}

class Gallery extends StatefulWidget {
  const Gallery({super.key, this.initial});

  /// The index of the demo a link asked for, if any.
  final int? initial;

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  late int selected = widget.initial ?? 2;

  // On a narrow screen, a link to a demo opens that demo's page once.
  late bool _openLinkedDemo = widget.initial != null;

  void _select(int index) {
    setState(() => selected = index);
    SystemNavigator.routeInformationUpdated(uri: Uri(path: demos[index].route), replace: true);
  }

  void _open(Demo demo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: demo.route),
        builder: (_) => DemoPage(demo: demo),
      ),
    );
  }

  Widget _list(BuildContext context, {required bool wide}) => ListView.builder(
    itemCount: demos.length,
    itemBuilder: (BuildContext context, int index) {
      final Demo demo = demos[index];
      return ListTile(
        dense: true,
        selected: wide && index == selected,
        leading: SizedBox(width: 32, child: Text(demo.id)),
        title: Text(demo.title),
        onTap: () => wide ? _select(index) : _open(demo),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 900;
        if (!wide && _openLinkedDemo) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _open(demos[selected]);
          });
        }
        _openLinkedDemo = false;
        if (!wide) {
          return Scaffold(
            appBar: AppBar(title: const Text('plot_twist')),
            body: _list(context, wide: false),
          );
        }
        final Demo demo = demos[selected];
        return Scaffold(
          appBar: AppBar(title: Text('plot_twist  ·  ${demo.id} ${demo.title}')),
          body: Row(
            children: <Widget>[
              SizedBox(width: 280, child: _list(context, wide: true)),
              const VerticalDivider(width: 1),
              Expanded(child: DemoPage(demo: demo, showAppBar: false)),
            ],
          ),
        );
      },
    );
  }
}
