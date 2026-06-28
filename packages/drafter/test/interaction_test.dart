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
import 'package:drafter/painting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A renderer that does NOT implement [InteractiveRenderer], to prove graceful
/// degrade (no interaction layer, just the base chart).
class _InertRenderer extends ChartRenderer {
  const _InertRenderer();

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {}
}

ChartScene _sceneWith(List<PlotMark> marks, {CartesianScale? scale}) =>
    ChartScene(
      bounds: ChartBounds.insets(
        const Size(120, 120),
        left: 10,
        top: 10,
        right: 10,
        bottom: 10,
      ),
      scale: scale,
      marks: marks,
    );

Future<void> _pump(WidgetTester tester, Widget chart) async {
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
  group('CartesianScale', () {
    // bounds rect = LTWH(10, 10, 100, 100); bottom = 110.
    final scale = CartesianScale(
      bounds: ChartBounds.insets(
        const Size(120, 120),
        left: 10,
        top: 10,
        right: 10,
        bottom: 10,
      ),
      count: 5,
      minValue: 0,
      maxValue: 100,
    );

    test('maps indices across the full width', () {
      expect(scale.xForIndex(0), 10);
      expect(scale.xForIndex(4), 110);
      expect(scale.xForIndex(2), 60);
    });

    test('maps values with the y-axis inverted', () {
      expect(scale.yForValue(0), 110); // bottom
      expect(scale.yForValue(100), 10); // top
    });

    test('valueForY is the inverse of yForValue', () {
      for (final v in [0.0, 25.0, 60.0, 100.0]) {
        expect(scale.valueForY(scale.yForValue(v)), closeTo(v, 1e-9));
      }
    });

    test('nearestIndex snaps a pixel x to the closest column', () {
      expect(scale.nearestIndex(10), 0);
      expect(scale.nearestIndex(110), 4);
      expect(scale.nearestIndex(58), 2);
      expect(scale.nearestIndex(-50), 0); // clamped
      expect(scale.nearestIndex(999), 4); // clamped
    });

    test('a single column is centered and never divides by zero', () {
      final one = CartesianScale(
        bounds: scale.bounds,
        count: 1,
        minValue: 0,
        maxValue: 10,
      );
      expect(one.xForIndex(0), 60); // center
      expect(one.nearestIndex(999), 0);
    });
  });

  group('ChartHitTest', () {
    PlotMark mark(int i, double x, double y, {Rect? region}) => PlotMark(
      index: i,
      seriesIndex: 0,
      seriesName: '',
      label: 'L$i',
      value: y,
      center: Offset(x, y),
      color: const Color(0xFF000000),
      region: region,
    );

    test('markAt prefers a region that contains the point (bars)', () {
      final scene = _sceneWith([
        mark(0, 20, 100, region: const Rect.fromLTRB(10, 10, 40, 110)),
        mark(1, 80, 100, region: const Rect.fromLTRB(70, 10, 100, 110)),
      ]);
      expect(ChartHitTest.markAt(scene, const Offset(25, 50))?.index, 0);
      expect(ChartHitTest.markAt(scene, const Offset(85, 90))?.index, 1);
    });

    test('markAt falls back to nearest center within radius', () {
      final scene = _sceneWith([mark(0, 20, 20), mark(1, 80, 80)]);
      expect(ChartHitTest.markAt(scene, const Offset(22, 22))?.index, 0);
      // Far from any point → no hit.
      expect(ChartHitTest.markAt(scene, const Offset(200, 200)), isNull);
    });

    test('marksAtIndex returns every series at a column', () {
      final scene = _sceneWith([
        mark(0, 20, 10),
        mark(0, 20, 30),
        mark(1, 80, 50),
      ]);
      expect(ChartHitTest.marksAtIndex(scene, 0).length, 2);
      expect(ChartHitTest.marksAtIndex(scene, 1).length, 1);
    });

    test('rangeBetween spans the inclusive column range', () {
      final scale = CartesianScale(
        bounds: ChartBounds.insets(
          const Size(120, 120),
          left: 10,
          top: 10,
          right: 10,
          bottom: 10,
        ),
        count: 5,
        minValue: 0,
        maxValue: 100,
      );
      final scene = _sceneWith(
        [for (var i = 0; i < 5; i++) mark(i, scale.xForIndex(i), 50)],
        scale: scale,
      );
      final range = ChartHitTest.rangeBetween(scene, 35, 85)!; // ~idx1..idx3
      expect(range.startIndex, 1);
      expect(range.endIndex, 3);
      expect(range.marks.length, 3);
    });

    test('an empty scene yields null/empty queries', () {
      expect(ChartHitTest.nearestIndexAtX(ChartScene.empty, 5), isNull);
      expect(ChartHitTest.markAt(ChartScene.empty, Offset.zero), isNull);
      expect(ChartHitTest.rangeBetween(ChartScene.empty, 0, 1), isNull);
    });
  });

  group('LabelLayout', () {
    test('spread pushes overlapping centers apart by minGap', () {
      final out = LabelLayout.spread([50, 52, 54], 10, 0, 100);
      for (var i = 1; i < out.length; i++) {
        expect(out[i] - out[i - 1], greaterThanOrEqualTo(10 - 1e-9));
      }
    });

    test('spread keeps already-separated centers untouched', () {
      final out = LabelLayout.spread([10, 40, 70], 10, 0, 100);
      expect(out, [10, 40, 70]);
    });

    test('thin drops labels whose boxes would overlap', () {
      // Three labels 20 wide at x=10,15,60: the middle overlaps the first.
      final keep = LabelLayout.thin([10, 15, 60], [20, 20, 20], 2);
      expect(keep, [0, 2]);
    });

    test('thin keeps everything when nothing collides', () {
      final keep = LabelLayout.thin([0, 50, 100], [10, 10, 10], 2);
      expect(keep, [0, 1, 2]);
    });
  });

  group('InteractiveChart widget', () {
    testWidgets('tap selects the nearest datum and fires onSelected', (
      tester,
    ) async {
      ChartSelection? selected;
      // Known geometry: 400x280 → bounds LTWH(40,28,320,224), bottom 252.
      // 4 points, max 40 → xForIndex(2)=40+320*2/3≈253.3, yForValue(30)=84.
      await _pump(
        tester,
        InteractiveChart(
          renderer: LineChartRenderer(
            points: const [
              ChartPoint('A', 10),
              ChartPoint('B', 20),
              ChartPoint('C', 30),
              ChartPoint('D', 40),
            ],
          ),
          interaction: ChartInteraction(
            onSelected: (s) => selected = s,
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(InteractiveChart));
      await tester.tapAt(topLeft + const Offset(253, 84));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.mark.index, 2);
      expect(selected!.mark.value, 30);
    });

    testWidgets('drag fires onRangeSelected with the spanned columns', (
      tester,
    ) async {
      ChartRange? range;
      await _pump(
        tester,
        InteractiveChart(
          renderer: LineChartRenderer(
            points: const [
              ChartPoint('A', 10),
              ChartPoint('B', 20),
              ChartPoint('C', 30),
              ChartPoint('D', 40),
            ],
          ),
          interaction: ChartInteraction(
            rangeSelection: true,
            onRangeSelected: (r) => range = r,
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(InteractiveChart));
      // From near column 0 (x≈40) to near column 3 (x≈360).
      await tester.dragFrom(
        topLeft + const Offset(45, 140),
        const Offset(310, 0),
      );
      await tester.pump();

      expect(range, isNotNull);
      expect(range!.startIndex, 0);
      expect(range!.endIndex, 3);
      expect(range!.marks.length, 4);
    });

    testWidgets('a non-interactive renderer just renders the base chart', (
      tester,
    ) async {
      await _pump(
        tester,
        const InteractiveChart(renderer: _InertRenderer()),
      );
      // No overlay/gesture scaffolding is inserted under the chart.
      expect(find.byType(ChartCanvas), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(InteractiveChart),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });

  group('every chart type builds a valid scene', () {
    const size = Size(420, 300);
    final blue = DrafterColors.blue;
    final teal = DrafterColors.teal;
    const cats = ['A', 'B', 'C', 'D'];
    const points = [
      ChartPoint('A', 10),
      ChartPoint('B', 20),
      ChartPoint('C', 15),
      ChartPoint('D', 30),
    ];
    final series = [
      ChartSeries(name: 'S1', color: blue, values: const [10, 20, 15, 30]),
      ChartSeries(name: 'S2', color: teal, values: const [8, 14, 22, 18]),
    ];
    final slices = [
      PieSlice(value: 30, color: blue, label: 'P1'),
      PieSlice(value: 20, color: teal, label: 'P2'),
      PieSlice(value: 50, color: DrafterColors.violet, label: 'P3'),
    ];

    // name → an InteractiveRenderer over representative data.
    final renderers = <String, InteractiveRenderer>{
      'line': LineChartRenderer(points: points),
      'area': AreaChartRenderer(points: points),
      'stepLine': StepLineChartRenderer(points: points),
      'groupedLine': GroupedLineChartRenderer(series: series, categories: cats),
      'stackedLine': StackedLineChartRenderer(series: series, categories: cats),
      'simpleBar': const SimpleBarChartRenderer(
        bars: [BarItem('A', 10), BarItem('B', 20), BarItem('C', 15)],
      ),
      'groupedBar': GroupedBarChartRenderer(series: series, categories: cats),
      'stackedBar': StackedBarChartRenderer(series: series, categories: cats),
      'histogram': HistogramRenderer(
        values: const [1, 2, 2, 3, 3, 3, 4, 5, 5, 8],
        binCount: 5,
      ),
      'waterfall': const WaterfallChartRenderer(
        steps: [WaterfallStep('S', 20), WaterfallStep('R', -8)],
        initialValue: 10,
        startLabel: 'Start',
        totalLabel: 'Total',
      ),
      'scatter': const ScatterPlotRenderer(
        points: [
          ScatterPoint(x: 10, y: 20),
          ScatterPoint(x: 40, y: 55),
          ScatterPoint(x: 70, y: 30),
        ],
      ),
      'candlestick': CandlestickChartRenderer(
        candles: const [
          Candle(label: 'D1', open: 10, high: 14, low: 9, close: 12),
          Candle(label: 'D2', open: 12, high: 16, low: 11, close: 15),
          Candle(label: 'D3', open: 15, high: 17, low: 13, close: 14),
        ],
      ),
      'pie': PieChartRenderer(slices: slices),
      'donut': DonutChartRenderer(slices: slices),
      'radar': RadarChartRenderer(
        series: [
          RadarSeries(
            color: blue,
            values: const {
              'Speed': 0.8,
              'Power': 0.5,
              'Range': 0.6,
              'Focus': 0.7,
            },
          ),
        ],
      ),
      'polarArea': PolarAreaChartRenderer(
        slices: [
          PolarSlice(label: 'Q1', value: 40, color: blue),
          PolarSlice(label: 'Q2', value: 70, color: teal),
          PolarSlice(label: 'Q3', value: 55, color: DrafterColors.violet),
        ],
      ),
      'sunburst': SunburstChartRenderer(
        roots: [
          SunburstNode(
            label: 'A',
            value: 50,
            color: blue,
            children: [SunburstNode(label: 'A1', value: 30, color: teal)],
          ),
          SunburstNode(label: 'B', value: 30, color: DrafterColors.amber),
        ],
      ),
      'gauge': GaugeChartRenderer(value: 72, label: 'Score'),
      'funnel': FunnelChartRenderer(
        stages: [
          FunnelStage(label: 'Visits', value: 1000, color: blue),
          FunnelStage(label: 'Signups', value: 600, color: teal),
          FunnelStage(label: 'Paid', value: 200, color: DrafterColors.green),
        ],
      ),
      'treemap': TreemapChartRenderer(
        items: [
          TreemapItem(label: 'T1', value: 50, color: blue),
          TreemapItem(label: 'T2', value: 30, color: teal),
          TreemapItem(label: 'T3', value: 20, color: DrafterColors.violet),
        ],
      ),
      'heatmap': HeatmapRenderer(
        contributions: [
          for (var d = 0; d < 30; d++)
            ContributionData(date: DateTime(2026, 6, 1 + d), count: d % 5),
        ],
      ),
      'bullet': const BulletChartRenderer(
        metrics: [
          BulletMetric(
            label: 'Revenue',
            value: 76,
            target: 85,
            ranges: [50, 75, 100],
          ),
        ],
      ),
      'boxPlot': BoxPlotChartRenderer(
        groups: [
          BoxGroup(
            label: 'G1',
            min: 10,
            q1: 30,
            median: 48,
            q3: 66,
            max: 88,
            color: blue,
          ),
        ],
      ),
      'bubble': BubbleChartRenderer(
        series: [
          [
            BubbleData(x: 10, y: 20, size: 3, color: blue),
            BubbleData(x: 40, y: 55, size: 5, color: teal),
          ],
        ],
      ),
      'gantt': const GanttChartRenderer(
        tasks: [
          GanttTask(name: 'Design', startMonth: 0, duration: 2),
          GanttTask(name: 'Build', startMonth: 2, duration: 3),
        ],
      ),
      'sankey': SankeyChartRenderer(
        nodes: const [
          SankeyNode(
            id: 'a',
            label: 'Src',
            column: 0,
            color: Color(0xFF4C8DF6),
          ),
          SankeyNode(
            id: 'b',
            label: 'Dst',
            column: 1,
            color: Color(0xFF2FC4C0),
          ),
        ],
        links: const [SankeyLink(from: 'a', to: 'b', value: 30)],
      ),
      'streamGraph': StreamGraphChartRenderer(series: series, categories: cats),
    };

    for (final entry in renderers.entries) {
      final name = entry.key;
      final renderer = entry.value;
      test('$name: marks have finite centers and valid fields', () {
        final scene = renderer.buildScene(size);
        final marks = scene.marks;
        expect(marks, isNotEmpty, reason: '$name produced no marks');
        for (final m in marks) {
          expect(
            m.center.dx.isFinite && m.center.dy.isFinite,
            isTrue,
            reason: '$name has a non-finite center',
          );
          expect(
            m.value.isFinite,
            isTrue,
            reason: '$name has a non-finite value',
          );
        }
      });
    }
  });
}
