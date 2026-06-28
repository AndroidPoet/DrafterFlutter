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
import 'dart:math' as math;

import 'package:drafter/drafter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

/// Deterministic RNG so the gallery always shows the same sample data.
final math.Random _rng = math.Random(7);

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
];

/// A list of labeled monthly points in roughly [10, 100].
List<ChartPoint> _monthlyPoints({double base = 40, double swing = 45}) {
  return [
    for (final m in _months)
      ChartPoint(m, (base + _rng.nextDouble() * swing).roundToDouble()),
  ];
}

/// A run of raw values in [lo, hi].
List<double> _values(int n, {double lo = 10, double hi = 100}) => [
  for (var i = 0; i < n; i++)
    (lo + _rng.nextDouble() * (hi - lo)).roundToDouble(),
];

/// A small set of named, colored series over [count] points.
List<ChartSeries> _series(int seriesCount, int count) {
  return [
    for (var s = 0; s < seriesCount; s++)
      ChartSeries(
        name: 'S${s + 1}',
        color: DrafterColors.palette[s % DrafterColors.palette.length],
        values: _values(count, lo: 15, hi: 90),
      ),
  ];
}

/// Wraps a renderer in an [InteractiveChart] with default interactions
/// (tooltip + tap selection) — the gallery's shorthand for "make this card live".
Widget _interactive(ChartRenderer renderer) =>
    InteractiveChart(renderer: renderer);

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drafter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: Colors.white),
      home: const _Gallery(),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Drafter — 27 charts'),
      ),
      body: DrafterTheme(
        colors: DrafterThemeColors.light,
        child: GridView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 460,
            mainAxisExtent: 300,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          children: _cards(),
        ),
      ),
    );
  }

  List<Widget> _cards() {
    final palette = DrafterColors.palette;

    // ---- Lines ----
    final linePoints = _monthlyPoints();
    final lineSeries2 = _series(2, _months.length);
    final lineSeries3 = _series(3, _months.length);
    final stackSeries = _series(3, _months.length);

    // ---- Bars ----
    final bars = [
      for (var i = 0; i < _months.length; i++)
        BarItem(
          _months[i],
          (20 + _rng.nextDouble() * 70).roundToDouble(),
          color: palette[i % palette.length],
        ),
    ];
    final groupedBars = _series(3, 5);
    final stackedBars = _series(3, 5);
    final histValues = [
      for (var i = 0; i < 200; i++) (50 + _rng.nextDouble() * 50 - 25),
    ];
    final waterfall = [
      WaterfallStep('Sales', 60, color: DrafterColors.green),
      WaterfallStep('Refund', -18, color: DrafterColors.coral),
      WaterfallStep('Fees', -12, color: DrafterColors.amber),
      WaterfallStep('Bonus', 24, color: DrafterColors.teal),
    ];

    // ---- Pie / donut ----
    final pieSlices = [
      for (var i = 0; i < 5; i++)
        PieSlice(
          value: (10 + _rng.nextDouble() * 40).roundToDouble(),
          color: palette[i % palette.length],
          label: 'P${i + 1}',
        ),
    ];

    // ---- Radar ----
    const axes = ['Speed', 'Power', 'Range', 'Agility', 'Focus', 'Stamina'];
    final radarSeries = [
      RadarSeries(
        color: DrafterColors.blue,
        values: {for (final a in axes) a: 0.4 + _rng.nextDouble() * 0.55},
      ),
      RadarSeries(
        color: DrafterColors.coral,
        values: {for (final a in axes) a: 0.35 + _rng.nextDouble() * 0.55},
      ),
    ];

    // ---- Polar ----
    final polarSlices = [
      for (var i = 0; i < 6; i++)
        PolarSlice(
          label: 'Q${i + 1}',
          value: (20 + _rng.nextDouble() * 80).roundToDouble(),
          color: palette[i % palette.length],
        ),
    ];

    // ---- Scatter ----
    final scatter = [
      for (var i = 0; i < 24; i++)
        ScatterPoint(
          x: (5 + _rng.nextDouble() * 95).roundToDouble(),
          y: (5 + _rng.nextDouble() * 95).roundToDouble(),
          color: palette[i % palette.length],
        ),
    ];

    // ---- Bubble ----
    final bubbles = [
      [
        for (var i = 0; i < 6; i++)
          BubbleData(
            x: (10 + _rng.nextDouble() * 80).roundToDouble(),
            y: (10 + _rng.nextDouble() * 80).roundToDouble(),
            size: 1 + _rng.nextDouble() * 5,
            color: DrafterColors.violet,
          ),
      ],
      [
        for (var i = 0; i < 6; i++)
          BubbleData(
            x: (10 + _rng.nextDouble() * 80).roundToDouble(),
            y: (10 + _rng.nextDouble() * 80).roundToDouble(),
            size: 1 + _rng.nextDouble() * 5,
            color: DrafterColors.teal,
          ),
      ],
    ];

    // ---- Heatmap (fixed end date, ~120 days) ----
    final end = DateTime(2026, 6, 25);
    final contributions = [
      for (var d = 119; d >= 0; d--)
        ContributionData(
          date: end.subtract(Duration(days: d)),
          count: _rng.nextInt(12),
        ),
    ];

    // ---- Funnel ----
    final funnel = [
      FunnelStage(label: 'Visits', value: 1000, color: DrafterColors.blue),
      FunnelStage(label: 'Signups', value: 640, color: DrafterColors.teal),
      FunnelStage(label: 'Trials', value: 360, color: DrafterColors.violet),
      FunnelStage(label: 'Paid', value: 140, color: DrafterColors.green),
    ];

    // ---- Bullet ----
    final bullets = [
      BulletMetric(
        label: 'Revenue',
        value: 76,
        target: 85,
        ranges: const [50, 75, 100],
        color: DrafterColors.indigo,
      ),
      BulletMetric(
        label: 'Profit',
        value: 58,
        target: 70,
        ranges: const [40, 70, 100],
        color: DrafterColors.teal,
      ),
      BulletMetric(
        label: 'Growth',
        value: 92,
        target: 80,
        ranges: const [50, 75, 100],
        color: DrafterColors.green,
      ),
    ];

    // ---- Box plot ----
    final boxes = [
      for (var i = 0; i < 4; i++)
        BoxGroup(
          label: 'G${i + 1}',
          min: 10 + _rng.nextDouble() * 10,
          q1: 30 + _rng.nextDouble() * 10,
          median: 48 + _rng.nextDouble() * 10,
          q3: 66 + _rng.nextDouble() * 10,
          max: 88 + _rng.nextDouble() * 10,
          color: palette[i % palette.length],
        ),
    ];

    // ---- Treemap ----
    final treemap = [
      for (var i = 0; i < 7; i++)
        TreemapItem(
          label: 'T${i + 1}',
          value: (20 + _rng.nextDouble() * 90).roundToDouble(),
          color: palette[i % palette.length],
        ),
    ];

    // ---- Sunburst ----
    final sunburst = [
      SunburstNode(
        label: 'Apps',
        value: 50,
        color: DrafterColors.blue,
        children: [
          SunburstNode(label: 'iOS', value: 30, color: DrafterColors.teal),
          SunburstNode(label: 'And', value: 20, color: DrafterColors.violet),
        ],
      ),
      SunburstNode(
        label: 'Web',
        value: 30,
        color: DrafterColors.amber,
        children: [
          SunburstNode(label: 'SSR', value: 18, color: DrafterColors.green),
          SunburstNode(label: 'SPA', value: 12, color: DrafterColors.coral),
        ],
      ),
      SunburstNode(
        label: 'Other',
        value: 20,
        color: DrafterColors.pink,
        children: [
          SunburstNode(label: 'CLI', value: 20, color: DrafterColors.indigo),
        ],
      ),
    ];

    // ---- Sankey ----
    final sankeyNodes = [
      SankeyNode(
        id: 'a',
        label: 'Source',
        column: 0,
        color: DrafterColors.blue,
      ),
      SankeyNode(
        id: 'b',
        label: 'Direct',
        column: 0,
        color: DrafterColors.teal,
      ),
      SankeyNode(
        id: 'c',
        label: 'Mobile',
        column: 1,
        color: DrafterColors.violet,
      ),
      SankeyNode(
        id: 'd',
        label: 'Desktop',
        column: 1,
        color: DrafterColors.amber,
      ),
      SankeyNode(
        id: 'e',
        label: 'Convert',
        column: 2,
        color: DrafterColors.green,
      ),
    ];
    const sankeyLinks = [
      SankeyLink(from: 'a', to: 'c', value: 30),
      SankeyLink(from: 'a', to: 'd', value: 20),
      SankeyLink(from: 'b', to: 'c', value: 15),
      SankeyLink(from: 'b', to: 'd', value: 25),
      SankeyLink(from: 'c', to: 'e', value: 28),
      SankeyLink(from: 'd', to: 'e', value: 32),
    ];

    // ---- Gantt ----
    const gantt = [
      GanttTask(name: 'Design', startMonth: 0, duration: 2),
      GanttTask(name: 'Build', startMonth: 2, duration: 3),
      GanttTask(name: 'Test', startMonth: 4, duration: 2),
      GanttTask(name: 'Ship', startMonth: 6, duration: 1),
    ];

    // ---- Candles ----
    final candles = <Candle>[];
    var price = 100.0;
    for (var i = 0; i < 18; i++) {
      final open = price;
      final close = open + (_rng.nextDouble() - 0.5) * 14;
      final high = math.max(open, close) + _rng.nextDouble() * 6;
      final low = math.min(open, close) - _rng.nextDouble() * 6;
      candles.add(
        Candle(
          label: 'D${i + 1}',
          open: open,
          high: high,
          low: low,
          close: close,
        ),
      );
      price = close;
    }
    const movingAverages = [
      MovingAverage(period: 5, color: Color(0xFF4C8DF6)),
      MovingAverage(period: 10, color: Color(0xFFF6B24C)),
    ];

    // Every card is interactive: each chart's renderer is wrapped in an
    // `InteractiveChart`, so hover/tap shows a tooltip and tap selects a datum.
    // The first two also wire up onSelected/onRangeSelected readouts.
    return [
      _InteractiveCard(
        title: 'Interactive Line — hover, tap, drag',
        renderer: LineChartRenderer(points: linePoints),
        rangeSelection: true,
      ),
      _InteractiveCard(
        title: 'Interactive Bars — hover, tap',
        renderer: SimpleBarChartRenderer(bars: bars),
      ),
      _ChartCard(
        title: 'Line',
        child: _interactive(LineChartRenderer(points: linePoints)),
      ),
      _ChartCard(
        title: 'Grouped Line',
        child: _interactive(
          GroupedLineChartRenderer(series: lineSeries2, categories: _months),
        ),
      ),
      _ChartCard(
        title: 'Stacked Line',
        child: _interactive(
          StackedLineChartRenderer(series: stackSeries, categories: _months),
        ),
      ),
      _ChartCard(
        title: 'Area',
        child: _interactive(AreaChartRenderer(points: _monthlyPoints())),
      ),
      _ChartCard(
        title: 'Step Line',
        child: _interactive(StepLineChartRenderer(points: _monthlyPoints())),
      ),
      _ChartCard(
        title: 'Simple Bar',
        child: _interactive(SimpleBarChartRenderer(bars: bars)),
      ),
      _ChartCard(
        title: 'Grouped Bar',
        child: _interactive(
          GroupedBarChartRenderer(
            series: groupedBars,
            categories: const ['A', 'B', 'C', 'D', 'E'],
          ),
        ),
      ),
      _ChartCard(
        title: 'Stacked Bar',
        child: _interactive(
          StackedBarChartRenderer(
            series: stackedBars,
            categories: const ['A', 'B', 'C', 'D', 'E'],
          ),
        ),
      ),
      _ChartCard(
        title: 'Histogram',
        child: _interactive(HistogramRenderer(values: histValues, binCount: 8)),
      ),
      _ChartCard(
        title: 'Waterfall',
        child: _interactive(
          WaterfallChartRenderer(
            steps: waterfall,
            initialValue: 30,
            startLabel: 'Start',
            totalLabel: 'Total',
          ),
        ),
      ),
      _ChartCard(
        title: 'Pie',
        child: _interactive(PieChartRenderer(slices: pieSlices)),
      ),
      _ChartCard(
        title: 'Donut',
        child: _interactive(DonutChartRenderer(slices: pieSlices)),
      ),
      _ChartCard(
        title: 'Radar',
        child: _interactive(RadarChartRenderer(series: radarSeries)),
      ),
      _ChartCard(
        title: 'Polar Area',
        child: _interactive(PolarAreaChartRenderer(slices: polarSlices)),
      ),
      _ChartCard(
        title: 'Gauge',
        child: _interactive(GaugeChartRenderer(value: 72, label: 'Score')),
      ),
      _ChartCard(
        title: 'Scatter Plot',
        child: _interactive(ScatterPlotRenderer(points: scatter)),
      ),
      _ChartCard(
        title: 'Bubble',
        child: _interactive(BubbleChartRenderer(series: bubbles)),
      ),
      _ChartCard(
        title: 'Heatmap',
        child: _interactive(HeatmapRenderer(contributions: contributions)),
      ),
      _ChartCard(
        title: 'Funnel',
        child: _interactive(FunnelChartRenderer(stages: funnel)),
      ),
      _ChartCard(
        title: 'Bullet',
        child: _interactive(BulletChartRenderer(metrics: bullets)),
      ),
      _ChartCard(
        title: 'Box Plot',
        child: _interactive(BoxPlotChartRenderer(groups: boxes)),
      ),
      _ChartCard(
        title: 'Treemap',
        child: _interactive(TreemapChartRenderer(items: treemap)),
      ),
      _ChartCard(
        title: 'Sunburst',
        child: _interactive(SunburstChartRenderer(roots: sunburst)),
      ),
      _ChartCard(
        title: 'Sankey',
        child: _interactive(
          SankeyChartRenderer(nodes: sankeyNodes, links: sankeyLinks),
        ),
      ),
      _ChartCard(
        title: 'Gantt',
        child: _interactive(GanttChartRenderer(tasks: gantt)),
      ),
      _ChartCard(
        title: 'Stream Graph',
        child: _interactive(
          StreamGraphChartRenderer(series: lineSeries3, categories: _months),
        ),
      ),
      _ChartCard(
        title: 'Candlestick',
        child: _interactive(
          CandlestickChartRenderer(
            candles: candles,
            movingAverages: movingAverages,
          ),
        ),
      ),
    ];
  }
}

/// A card wrapping a chart in an [InteractiveChart], with a live readout of the
/// last tap selection and drag range below it.
class _InteractiveCard extends StatefulWidget {
  const _InteractiveCard({
    required this.title,
    required this.renderer,
    this.rangeSelection = false,
  });

  final String title;
  final ChartRenderer renderer;
  final bool rangeSelection;

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  String _readout =
      'Hover for a tooltip · tap to select'
      ' · drag to select a range';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Color(0xFF55606C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: InteractiveChart(
              renderer: widget.renderer,
              interaction: ChartInteraction(
                rangeSelection: widget.rangeSelection,
                onSelected: (s) => setState(() {
                  _readout = s == null
                      ? 'No selection'
                      : 'Selected ${s.mark.label.isEmpty ? '#${s.mark.index}' : s.mark.label}'
                            ' = ${s.mark.value.toStringAsFixed(0)}';
                }),
                onRangeSelected: (r) => setState(() {
                  _readout = r == null
                      ? 'No range'
                      : 'Range ${r.startIndex}–${r.endIndex}'
                            ' (${r.marks.length} points)';
                }),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _readout,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8A92A2), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// A white, softly-shadowed card with a small grey title above a 220pt chart.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF55606C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
