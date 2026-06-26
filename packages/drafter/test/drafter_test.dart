/*
 * Designed and developed by 2024 androidpoet (Ranbir Singh)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'package:drafter/drafter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounts [chart] inside a sized, themed scaffold and lets its entrance
/// animation settle — the shared harness for every smoke test below.
Future<void> _pumpChart(WidgetTester tester, Widget chart) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DrafterTheme(
        colors: DrafterThemeColors.light,
        child: Center(
          child: SizedBox(width: 400, height: 280, child: chart),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // A representative chart from each family — if any renderer throws while
  // laying out or painting, the test fails. Cheap, broad coverage.
  final cases = <String, Widget>{
    'LineChart': LineChart(
      points: const [
        ChartPoint('Jan', 40),
        ChartPoint('Feb', 65),
        ChartPoint('Mar', 30),
        ChartPoint('Apr', 80),
      ],
    ),
    'AreaChart': AreaChart(
      points: const [
        ChartPoint('A', 12),
        ChartPoint('B', 48),
        ChartPoint('C', 33),
      ],
    ),
    'SimpleBarChart': const SimpleBarChart(
      bars: [
        BarItem('A', 20),
        BarItem('B', 55),
        BarItem('C', 40),
      ],
    ),
    'PieChart': PieChart(
      slices: [
        PieSlice(value: 30, color: DrafterColors.blue, label: 'A'),
        PieSlice(value: 20, color: DrafterColors.teal, label: 'B'),
        PieSlice(value: 50, color: DrafterColors.violet, label: 'C'),
      ],
    ),
    'GaugeChart': const GaugeChart(value: 72, label: 'Score'),
    'ScatterPlot': const ScatterPlot(
      points: [
        ScatterPoint(x: 10, y: 20),
        ScatterPoint(x: 40, y: 55),
        ScatterPoint(x: 80, y: 30),
      ],
    ),
    'RadarChart': RadarChart(
      series: [
        RadarSeries(
          color: DrafterColors.blue,
          values: const {'Speed': 0.6, 'Power': 0.8, 'Range': 0.4},
        ),
      ],
    ),
  };

  for (final entry in cases.entries) {
    final name = entry.key;
    final chart = entry.value;
    testWidgets('$name renders without throwing', (tester) async {
      await _pumpChart(tester, chart);
      expect(tester.takeException(), isNull);
      expect(find.byWidget(chart), findsOneWidget);
    });
  }

  testWidgets('charts expose an accessibility label via Semantics', (
    tester,
  ) async {
    await _pumpChart(
      tester,
      PieChart(
        slices: [
          PieSlice(value: 1, color: DrafterColors.blue, label: 'Only'),
        ],
      ),
    );
    // Every chart wraps its renderer in a Semantics node with a label.
    expect(find.bySemanticsLabel(RegExp('.+')), findsWidgets);
  });

  test('DrafterThemeColors light and dark are distinct and value-equal', () {
    expect(DrafterThemeColors.light, isNot(equals(DrafterThemeColors.dark)));
    expect(DrafterThemeColors.light.isDark, isFalse);
    expect(DrafterThemeColors.dark.isDark, isTrue);
    expect(
      DrafterThemeColors.light.colorAt(0),
      equals(DrafterThemeColors.light.colorAt(DrafterColors.palette.length)),
    );
  });

  test(
    'changing only the palette makes the theme unequal (recolors charts)',
    () {
      final a = DrafterThemeColors.light;
      final b = DrafterThemeColors(
        palette: [DrafterColors.coral, DrafterColors.green],
        grid: a.grid,
        label: a.label,
        surface: a.surface,
        isDark: a.isDark,
      );
      expect(a == b, isFalse, reason: 'palette must participate in ==');
      expect(a.hashCode == b.hashCode, isFalse);
    },
  );

  testWidgets('ScatterPlot.values builds points from (x, y) pairs', (
    tester,
  ) async {
    await _pumpChart(
      tester,
      ScatterPlot.values(values: const [(1, 2), (3, 4), (5, 6)]),
    );
    expect(tester.takeException(), isNull);
  });

  test('colorAt on an empty palette falls back instead of throwing', () {
    final empty = DrafterThemeColors(
      palette: const [],
      grid: DrafterColors.gridLight,
      label: DrafterColors.labelLight,
      surface: DrafterColors.surfaceLight,
      isDark: false,
    );
    expect(() => empty.colorAt(0), returnsNormally);
    expect(() => empty.colorAt(7), returnsNormally);
  });
}
