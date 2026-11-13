import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Frame timings for the heaviest demos, in profile mode:
///
///     fvm flutter drive --profile -d macos \
///       --target=test_driver/perf.dart --driver=test_driver/perf_test.dart
///
/// Each step is traced and summarised with `TimelineSummary`; the summaries
/// are written to `build/perf_summary.json` and the key numbers printed.
Future<void> main() async {
  final FlutterDriver driver = await FlutterDriver.connect();
  final Map<String, Map<String, dynamic>> results = <String, Map<String, dynamic>>{};

  Future<void> measure(String name, String command) async {
    final Timeline timeline = await driver.traceAction(() => driver.requestData(command));
    results[name] = TimelineSummary.summarize(timeline).summaryJson;
  }

  try {
    await driver.requestData('a10');
    await measure('a10_wheel_zoom', 'zoom');
    await driver.requestData('zoom-in');
    await measure('a10_pan', 'pan');
    await driver.requestData('a15');
    await measure('a15_live', 'wait');
    await driver.requestData('a26');
    await measure('a26_wheel_zoom', 'zoom-out');
    await driver.requestData('candles');
    await measure('candles_100k_wheel_zoom', 'zoom');
    await driver.requestData('zoom-in');
    await measure('candles_100k_pan', 'pan');
  } finally {
    await driver.close();
  }

  File('build/perf_summary.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  const List<String> keys = <String>[
    'frame_count',
    'average_frame_build_time_millis',
    '90th_percentile_frame_build_time_millis',
    '99th_percentile_frame_build_time_millis',
    'worst_frame_build_time_millis',
    'average_frame_rasterizer_time_millis',
    '90th_percentile_frame_rasterizer_time_millis',
    '99th_percentile_frame_rasterizer_time_millis',
    'worst_frame_rasterizer_time_millis',
    'missed_frame_build_budget_count',
    'missed_frame_rasterizer_budget_count',
  ];
  for (final MapEntry<String, Map<String, dynamic>> entry in results.entries) {
    stdout.writeln('== ${entry.key}');
    for (final String key in keys) {
      stdout.writeln('  $key: ${entry.value[key]}');
    }
  }
}
