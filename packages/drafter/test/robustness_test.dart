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
import 'dart:ui' as ui;

import 'package:drafter/drafter.dart';
import 'package:drafter/painting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises a renderer's full `draw()` body at several reveal values on a real
/// `Canvas` (a recorder), so every staggered/animated branch runs. A throw here
/// — a non-finite Canvas coordinate (debug assert) or a `toInt()` on a
/// non-finite (UnsupportedError, even in release) — fails the test.
void _draw(ChartRenderer r, {Size size = const Size(420, 300)}) {
  for (final progress in const [0.0, 0.35, 1.0]) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    r.draw(canvas, size, DrafterThemeColors.light, progress);
    recorder.endRecording().dispose();
  }
}

/// Builds the hit-test scene (when the renderer is interactive) and asserts no
/// mark carries a non-finite pixel position — the invariant that keeps the
/// trackball/highlight geometry (and the Canvas) crash-safe. A mark's [value]
/// may legitimately echo a non-finite *input* (the tooltip formatter renders it
/// safely); only the geometry must always be finite.
void _scene(ChartRenderer r, {Size size = const Size(420, 300)}) {
  if (r is! InteractiveRenderer) return;
  final scene = (r as InteractiveRenderer).buildScene(size);
  for (final m in scene.marks) {
    expect(
      m.center.dx.isFinite && m.center.dy.isFinite,
      isTrue,
      reason: 'non-finite center',
    );
  }
}

void _drawAndScene(ChartRenderer r) {
  _draw(r);
  _scene(r);
}

const _blue = Color(0xFF4C8DF6);
const _teal = Color(0xFF2FC4C0);
const _violet = Color(0xFF7C6BF2);

// A NaN and an Infinity, to smuggle non-finite values into every value-based
// renderer's ingestion path.
const double _nan = double.nan;
const double _inf = double.infinity;

void main() {
  // ---------------------------------------------------------------------------
  // Healthy data: every renderer draws across the full reveal + builds a scene.
  // This runs each draw() body (the bulk of the painting code) end to end.
  // ---------------------------------------------------------------------------
  group('renderers draw across the reveal without throwing', () {
    const points = [
      ChartPoint('A', 10),
      ChartPoint('B', 20),
      ChartPoint('C', 15),
      ChartPoint('D', 30),
    ];
    const cats = ['A', 'B', 'C', 'D'];
    final series = [
      const ChartSeries(name: 'S1', color: _blue, values: [10, 20, 15, 30]),
      const ChartSeries(name: 'S2', color: _teal, values: [8, 14, 22, 18]),
    ];
    const slices = [
      PieSlice(value: 30, color: _blue, label: 'P1'),
      PieSlice(value: 20, color: _teal, label: 'P2'),
      PieSlice(value: 50, color: _violet, label: 'P3'),
    ];

    final renderers = <String, ChartRenderer>{
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
        values: [1, 2, 2, 3, 3, 3, 4, 5, 5, 8],
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
        movingAverages: const [MovingAverage(period: 2, color: _violet)],
      ),
      'pie': const PieChartRenderer(slices: slices),
      'donut': const DonutChartRenderer(slices: slices),
      'radar': const RadarChartRenderer(
        series: [
          RadarSeries(
            color: _blue,
            values: {'Speed': 0.8, 'Power': 0.5, 'Range': 0.6, 'Focus': 0.7},
          ),
        ],
      ),
      'polarArea': const PolarAreaChartRenderer(
        slices: [
          PolarSlice(label: 'Q1', value: 40, color: _blue),
          PolarSlice(label: 'Q2', value: 70, color: _teal),
          PolarSlice(label: 'Q3', value: 55, color: _violet),
        ],
      ),
      'sunburst': const SunburstChartRenderer(
        roots: [
          SunburstNode(
            label: 'A',
            value: 50,
            color: _blue,
            children: [SunburstNode(label: 'A1', value: 30, color: _teal)],
          ),
          SunburstNode(label: 'B', value: 30, color: _violet),
        ],
      ),
      'gauge': GaugeChartRenderer(value: 72, label: 'Score'),
      'funnel': const FunnelChartRenderer(
        stages: [
          FunnelStage(label: 'Visits', value: 1000, color: _blue),
          FunnelStage(label: 'Signups', value: 600, color: _teal),
          FunnelStage(label: 'Paid', value: 200, color: _violet),
        ],
      ),
      'treemap': TreemapChartRenderer(
        items: [
          const TreemapItem(label: 'T1', value: 50, color: _blue),
          const TreemapItem(label: 'T2', value: 30, color: _teal),
          const TreemapItem(label: 'T3', value: 20, color: _violet),
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
      'boxPlot': const BoxPlotChartRenderer(
        groups: [
          BoxGroup(
            label: 'G1',
            min: 10,
            q1: 30,
            median: 48,
            q3: 66,
            max: 88,
            color: _blue,
          ),
        ],
      ),
      'bubble': const BubbleChartRenderer(
        series: [
          [
            BubbleData(x: 10, y: 20, size: 3, color: _blue),
            BubbleData(x: 40, y: 55, size: 5, color: _teal),
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
          SankeyNode(id: 'a', label: 'Src', column: 0, color: _blue),
          SankeyNode(id: 'b', label: 'Dst', column: 1, color: _teal),
        ],
        links: const [SankeyLink(from: 'a', to: 'b', value: 30)],
      ),
      'streamGraph': StreamGraphChartRenderer(series: series, categories: cats),
    };

    test('covers all 27 renderer types', () {
      expect(renderers.length, 27);
    });

    for (final entry in renderers.entries) {
      test('${entry.key} draws + builds a scene', () {
        _drawAndScene(entry.value);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Edge inputs: empty, single, all-equal/zero, negative — no renderer should
  // throw, divide-by-zero into a non-finite coordinate, or crash on a `reduce`.
  // ---------------------------------------------------------------------------
  group('renderers survive empty data', () {
    final empties = <String, ChartRenderer>{
      'line': LineChartRenderer(points: []),
      'area': AreaChartRenderer(points: []),
      'stepLine': StepLineChartRenderer(points: []),
      'groupedLine': const GroupedLineChartRenderer(series: []),
      'stackedLine': const StackedLineChartRenderer(series: []),
      'simpleBar': const SimpleBarChartRenderer(bars: []),
      'groupedBar': const GroupedBarChartRenderer(series: []),
      'stackedBar': const StackedBarChartRenderer(series: []),
      'histogram': HistogramRenderer(values: [], binCount: 5),
      'waterfall': const WaterfallChartRenderer(steps: []),
      'scatter': const ScatterPlotRenderer(points: []),
      'candlestick': CandlestickChartRenderer(candles: const []),
      'pie': const PieChartRenderer(slices: []),
      'donut': const DonutChartRenderer(slices: []),
      'radar': const RadarChartRenderer(series: []),
      'polarArea': const PolarAreaChartRenderer(slices: []),
      'sunburst': const SunburstChartRenderer(roots: []),
      'funnel': const FunnelChartRenderer(stages: []),
      'treemap': TreemapChartRenderer(items: []),
      'heatmap': HeatmapRenderer(contributions: const []),
      'bullet': const BulletChartRenderer(metrics: []),
      'boxPlot': const BoxPlotChartRenderer(groups: []),
      'bubble': const BubbleChartRenderer(series: []),
      'gantt': const GanttChartRenderer(tasks: []),
      'sankey': SankeyChartRenderer(nodes: const [], links: const []),
      'streamGraph': const StreamGraphChartRenderer(series: []),
    };

    // Data-driven charts produce no marks when empty; a few (heatmap's calendar
    // grid, histogram's fixed bins) still draw an empty frame — both are fine, so
    // the universal invariant we assert is "draws + builds a finite scene without
    // throwing", via _drawAndScene.
    const emptyMeansNoMarks = {
      'line',
      'area',
      'stepLine',
      'groupedLine',
      'stackedLine',
      'simpleBar',
      'groupedBar',
      'stackedBar',
      'waterfall',
      'scatter',
      'candlestick',
      'pie',
      'donut',
      'radar',
      'polarArea',
      'sunburst',
      'funnel',
      'treemap',
      'bullet',
      'boxPlot',
      'bubble',
      'gantt',
      'sankey',
      'streamGraph',
    };

    for (final entry in empties.entries) {
      test('${entry.key} with empty data', () {
        _drawAndScene(entry.value);
        if (entry.value is InteractiveRenderer &&
            emptyMeansNoMarks.contains(entry.key)) {
          final scene = (entry.value as InteractiveRenderer).buildScene(
            const Size(420, 300),
          );
          expect(scene.isEmpty, isTrue, reason: '${entry.key} should be empty');
        }
      });
    }
  });

  group('renderers survive a single datum', () {
    final singles = <String, ChartRenderer>{
      'line': LineChartRenderer(points: [const ChartPoint('A', 10)]),
      'area': AreaChartRenderer(points: [const ChartPoint('A', 10)]),
      'stepLine': StepLineChartRenderer(points: [const ChartPoint('A', 10)]),
      'simpleBar': const SimpleBarChartRenderer(bars: [BarItem('A', 10)]),
      'histogram': HistogramRenderer(values: [5], binCount: 5),
      'scatter': const ScatterPlotRenderer(
        points: [ScatterPoint(x: 10, y: 20)],
      ),
      'pie': const PieChartRenderer(
        slices: [PieSlice(value: 30, color: _blue, label: 'Only')],
      ),
      'gauge': GaugeChartRenderer(value: 50, label: 'X'),
      'funnel': const FunnelChartRenderer(
        stages: [FunnelStage(label: 'One', value: 100, color: _blue)],
      ),
      'treemap': TreemapChartRenderer(
        items: [const TreemapItem(label: 'One', value: 100, color: _blue)],
      ),
    };

    for (final entry in singles.entries) {
      test('${entry.key} with one datum', () => _drawAndScene(entry.value));
    }
  });

  group('renderers survive all-equal / zero values (zero span)', () {
    final flats = <String, ChartRenderer>{
      'line': LineChartRenderer(
        points: [
          const ChartPoint('A', 5),
          const ChartPoint('B', 5),
          const ChartPoint('C', 5),
        ],
      ),
      'area': AreaChartRenderer(
        points: [
          const ChartPoint('A', 0),
          const ChartPoint('B', 0),
          const ChartPoint('C', 0),
        ],
      ),
      'simpleBar': const SimpleBarChartRenderer(
        bars: [BarItem('A', 0), BarItem('B', 0)],
      ),
      'pie': const PieChartRenderer(
        slices: [
          PieSlice(value: 0, color: _blue, label: 'A'),
          PieSlice(value: 0, color: _teal, label: 'B'),
        ],
      ),
      'gauge': GaugeChartRenderer(value: 5, min: 5, max: 5, label: 'flat'),
      'scatter': const ScatterPlotRenderer(
        points: [ScatterPoint(x: 5, y: 5), ScatterPoint(x: 5, y: 5)],
      ),
    };

    for (final entry in flats.entries) {
      test('${entry.key} all-equal', () => _drawAndScene(entry.value));
    }
  });

  group('renderers survive negative values', () {
    final negatives = <String, ChartRenderer>{
      'line': LineChartRenderer(
        points: [
          const ChartPoint('A', -10),
          const ChartPoint('B', 5),
          const ChartPoint('C', -3),
        ],
      ),
      'area': AreaChartRenderer(
        points: [const ChartPoint('A', -10), const ChartPoint('B', 5)],
      ),
      'simpleBar': const SimpleBarChartRenderer(
        bars: [BarItem('A', -10), BarItem('B', 20)],
      ),
      'scatter': const ScatterPlotRenderer(
        points: [ScatterPoint(x: -5, y: -8), ScatterPoint(x: 4, y: 3)],
      ),
      'waterfall': const WaterfallChartRenderer(
        steps: [WaterfallStep('A', -20), WaterfallStep('B', -8)],
        initialValue: -5,
      ),
    };

    for (final entry in negatives.entries) {
      test('${entry.key} with negatives', () => _drawAndScene(entry.value));
    }
  });

  // ---------------------------------------------------------------------------
  // Non-finite inputs (NaN / Infinity) must never reach a Canvas coordinate or a
  // toInt(). These would otherwise assert in debug or throw UnsupportedError in
  // release. Each renderer mixes a non-finite value with a healthy one.
  // ---------------------------------------------------------------------------
  group('renderers survive non-finite (NaN/Infinity) values', () {
    final nonFinite = <String, ChartRenderer>{
      'line': LineChartRenderer(
        points: [
          const ChartPoint('A', _nan),
          const ChartPoint('B', _inf),
          const ChartPoint('C', 10),
        ],
      ),
      'area': AreaChartRenderer(
        points: [
          const ChartPoint('A', _nan),
          const ChartPoint('B', 10),
          const ChartPoint('C', _inf),
        ],
      ),
      'stepLine': StepLineChartRenderer(
        points: [
          const ChartPoint('A', _inf),
          const ChartPoint('B', 10),
          const ChartPoint('C', _nan),
        ],
      ),
      'groupedLine': const GroupedLineChartRenderer(
        series: [
          ChartSeries(color: _blue, values: [_nan, 10, _inf]),
        ],
        categories: ['A', 'B', 'C'],
      ),
      'stackedLine': const StackedLineChartRenderer(
        series: [
          ChartSeries(color: _blue, values: [_nan, 10, _inf]),
        ],
        categories: ['A', 'B', 'C'],
      ),
      'simpleBar': const SimpleBarChartRenderer(
        bars: [BarItem('A', _nan), BarItem('B', _inf), BarItem('C', 10)],
      ),
      'groupedBar': const GroupedBarChartRenderer(
        series: [
          ChartSeries(color: _blue, values: [_nan, 10, _inf]),
        ],
        categories: ['A', 'B', 'C'],
      ),
      'stackedBar': const StackedBarChartRenderer(
        series: [
          ChartSeries(color: _blue, values: [_nan, 10, _inf]),
        ],
        categories: ['A', 'B', 'C'],
      ),
      'histogram': HistogramRenderer(
        values: [1, _nan, _inf, 3, 4],
        binCount: 5,
      ),
      'waterfall': const WaterfallChartRenderer(
        steps: [
          WaterfallStep('A', _nan),
          WaterfallStep('B', _inf),
          WaterfallStep('C', 5),
        ],
        initialValue: 10,
      ),
      'scatter': const ScatterPlotRenderer(
        points: [
          ScatterPoint(x: _nan, y: _inf),
          ScatterPoint(x: 10, y: 20),
        ],
      ),
      'candlestick': CandlestickChartRenderer(
        candles: const [
          Candle(label: 'A', open: _nan, high: _inf, low: _nan, close: 10),
          Candle(label: 'B', open: 12, high: 16, low: 11, close: 15),
        ],
      ),
      'pie': const PieChartRenderer(
        slices: [
          PieSlice(value: _nan, color: _blue, label: 'A'),
          PieSlice(value: 30, color: _teal, label: 'B'),
          PieSlice(value: _inf, color: _violet, label: 'C'),
        ],
      ),
      'donut': const DonutChartRenderer(
        slices: [
          PieSlice(value: _inf, color: _blue, label: 'A'),
          PieSlice(value: 30, color: _teal, label: 'B'),
        ],
      ),
      'radar': const RadarChartRenderer(
        series: [
          RadarSeries(color: _blue, values: {'A': _nan, 'B': 0.5, 'C': _inf}),
        ],
      ),
      'polarArea': const PolarAreaChartRenderer(
        slices: [
          PolarSlice(label: 'A', value: _nan, color: _blue),
          PolarSlice(label: 'B', value: 40, color: _teal),
          PolarSlice(label: 'C', value: _inf, color: _violet),
        ],
      ),
      'gauge': GaugeChartRenderer(value: _nan, label: 'X'),
      'funnel': const FunnelChartRenderer(
        stages: [
          FunnelStage(label: 'A', value: _inf, color: _blue),
          FunnelStage(label: 'B', value: 100, color: _teal),
        ],
      ),
      'bullet': const BulletChartRenderer(
        metrics: [
          BulletMetric(
            label: 'M',
            value: _nan,
            target: _inf,
            ranges: [_nan, 75, _inf],
          ),
        ],
      ),
      'boxPlot': const BoxPlotChartRenderer(
        groups: [
          BoxGroup(
            label: 'G',
            min: _nan,
            q1: 30,
            median: 48,
            q3: 66,
            max: _inf,
            color: _blue,
          ),
        ],
      ),
      'bubble': const BubbleChartRenderer(
        series: [
          [
            BubbleData(x: _nan, y: _inf, size: _nan, color: _blue),
            BubbleData(x: 40, y: 55, size: 5, color: _teal),
          ],
        ],
      ),
      'sankey': SankeyChartRenderer(
        nodes: const [
          SankeyNode(id: 'a', label: 'Src', column: 0, color: _blue),
          SankeyNode(id: 'b', label: 'Dst', column: 1, color: _teal),
        ],
        links: const [SankeyLink(from: 'a', to: 'b', value: _nan)],
      ),
      'streamGraph': const StreamGraphChartRenderer(
        series: [
          ChartSeries(color: _blue, values: [_nan, 10, _inf]),
          ChartSeries(color: _teal, values: [5, _inf, 8]),
        ],
        categories: ['A', 'B', 'C'],
      ),
    };

    for (final entry in nonFinite.entries) {
      test('${entry.key} with NaN/Infinity values', () {
        _drawAndScene(entry.value);
      });
    }
  });

  test(
    'BubbleChart with an all-zero axis does not produce a non-finite Offset',
    () {
      // Regression: shared-zero axis used to divide by a zero range → NaN center.
      const r = BubbleChartRenderer(
        series: [
          [
            BubbleData(x: 0, y: 0, size: 3, color: _blue),
            BubbleData(x: 0, y: 0, size: 5, color: _teal),
          ],
        ],
      );
      _drawAndScene(r);
      final scene = r.buildScene(const Size(420, 300));
      for (final m in scene.marks) {
        expect(m.center.dx.isFinite && m.center.dy.isFinite, isTrue);
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Every public chart WIDGET mounts and renders (exercises build + Semantics).
  // ---------------------------------------------------------------------------
  group('every chart widget mounts and renders', () {
    const points = [
      ChartPoint('A', 10),
      ChartPoint('B', 20),
      ChartPoint('C', 15),
    ];
    const cats = ['A', 'B', 'C'];
    final series = [
      const ChartSeries(name: 'S1', color: _blue, values: [10, 20, 15]),
      const ChartSeries(name: 'S2', color: _teal, values: [8, 14, 22]),
    ];
    const slices = [
      PieSlice(value: 30, color: _blue, label: 'P1'),
      PieSlice(value: 50, color: _teal, label: 'P2'),
    ];

    final widgets = <String, Widget>{
      'LineChart': LineChart(points: points),
      'GroupedLineChart': GroupedLineChart(series: series, categories: cats),
      'StackedLineChart': StackedLineChart(series: series, categories: cats),
      'AreaChart': AreaChart(points: points),
      'StepLineChart': StepLineChart(points: points),
      'SimpleBarChart': const SimpleBarChart(
        bars: [BarItem('A', 10), BarItem('B', 20)],
      ),
      'GroupedBarChart': GroupedBarChart(series: series, categories: cats),
      'StackedBarChart': StackedBarChart(series: series, categories: cats),
      'Histogram': Histogram(values: const [1, 2, 2, 3, 3, 4], binCount: 4),
      'WaterfallChart': const WaterfallChart(
        steps: [WaterfallStep('A', 20), WaterfallStep('B', -8)],
        initialValue: 10,
      ),
      'PieChart': const PieChart(slices: slices),
      'DonutChart': const DonutChart(slices: slices),
      'ScatterPlot': const ScatterPlot(
        points: [ScatterPoint(x: 10, y: 20), ScatterPoint(x: 40, y: 55)],
      ),
      'BubbleChart': const BubbleChart(
        series: [
          [
            BubbleData(x: 10, y: 20, size: 3),
            BubbleData(x: 40, y: 55, size: 5),
          ],
        ],
      ),
      'CandlestickChart': const CandlestickChart(
        candles: [
          Candle(label: 'A', open: 10, high: 14, low: 9, close: 12),
          Candle(label: 'B', open: 12, high: 16, low: 11, close: 15),
        ],
      ),
      'BoxPlotChart': const BoxPlotChart(
        groups: [
          BoxGroup(
            label: 'G',
            min: 10,
            q1: 30,
            median: 48,
            q3: 66,
            max: 88,
            color: _blue,
          ),
        ],
      ),
      'RadarChart': const RadarChart(
        series: [
          RadarSeries(color: _blue, values: {'A': 0.8, 'B': 0.5, 'C': 0.6}),
        ],
      ),
      'GaugeChart': const GaugeChart(value: 72, label: 'Score'),
      'BulletChart': const BulletChart(
        metrics: [
          BulletMetric(
            label: 'M',
            value: 76,
            target: 85,
            ranges: [50, 75, 100],
          ),
        ],
      ),
      'FunnelChart': const FunnelChart(
        stages: [
          FunnelStage(label: 'A', value: 1000, color: _blue),
          FunnelStage(label: 'B', value: 400, color: _teal),
        ],
      ),
      'TreemapChart': const TreemapChart(
        items: [
          TreemapItem(label: 'A', value: 50, color: _blue),
          TreemapItem(label: 'B', value: 30, color: _teal),
        ],
      ),
      'PolarAreaChart': const PolarAreaChart(
        slices: [
          PolarSlice(label: 'A', value: 40, color: _blue),
          PolarSlice(label: 'B', value: 70, color: _teal),
        ],
      ),
      'SunburstChart': const SunburstChart(
        roots: [
          SunburstNode(label: 'A', value: 50, color: _blue),
          SunburstNode(label: 'B', value: 30, color: _teal),
        ],
      ),
      'SankeyChart': const SankeyChart(
        nodes: [
          SankeyNode(id: 'a', label: 'Src', column: 0, color: _blue),
          SankeyNode(id: 'b', label: 'Dst', column: 1, color: _teal),
        ],
        links: [SankeyLink(from: 'a', to: 'b', value: 30)],
      ),
      'StreamGraphChart': StreamGraphChart(series: series, categories: cats),
      'GanttChart': const GanttChart(
        tasks: [
          GanttTask(name: 'Design', startMonth: 0, duration: 2),
          GanttTask(name: 'Build', startMonth: 2, duration: 3),
        ],
      ),
      'Heatmap': Heatmap(
        contributions: [
          for (var d = 0; d < 30; d++)
            ContributionData(date: DateTime(2026, 6, 1 + d), count: d % 5),
        ],
      ),
    };

    test('covers all 27 chart widgets', () {
      expect(widgets.length, 27);
    });

    for (final entry in widgets.entries) {
      testWidgets('${entry.key} renders without throwing', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DrafterTheme(
              colors: DrafterThemeColors.light,
              child: Center(
                child: SizedBox(width: 400, height: 280, child: entry.value),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byWidget(entry.value), findsOneWidget);
      });
    }
  });

  group('drafterFinite', () {
    test('passes finite values through', () {
      expect(drafterFinite(42), 42);
      expect(drafterFinite(-3.5), -3.5);
      expect(drafterFinite(0), 0);
    });

    test('coerces non-finite to the fallback', () {
      expect(drafterFinite(double.nan), 0);
      expect(drafterFinite(double.infinity), 0);
      expect(drafterFinite(double.negativeInfinity), 0);
      expect(drafterFinite(double.nan, 7), 7);
    });

    test('drafterFiniteOrNull nulls non-finite', () {
      expect(drafterFiniteOrNull(5), 5);
      expect(drafterFiniteOrNull(double.nan), isNull);
      expect(drafterFiniteOrNull(double.infinity), isNull);
    });
  });
}
