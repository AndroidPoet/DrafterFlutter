<h1 align="center">Drafter</h1>

<p align="center">
  <a href="https://github.com/AndroidPoet/DrafterFlutter/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/AndroidPoet/DrafterFlutter/actions/workflows/ci.yml/badge.svg"/></a>
  <a href="https://opensource.org/licenses/Apache-2.0"><img alt="License" src="https://img.shields.io/badge/License-Apache%202.0-blue.svg"/></a>
  <a href="https://pub.dev/packages/drafter"><img alt="pub" src="https://img.shields.io/pub/v/drafter.svg?label=pub&color=blue"/></a>
  <a href="https://flutter.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.27%2B-027DFD.svg"/></a>
  <img alt="Platforms" src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Web%20%7C%20Windows%20%7C%20Linux-lightgrey.svg"/>
</p>

<div align="center">
<p align="center">
📊 A powerful, flexible charting library for <b>Flutter</b> — a native Dart port of <a href="https://github.com/androidpoet/Drafter">Drafter</a> for Compose and <a href="https://github.com/AndroidPoet/DrafterCharts">DrafterCharts</a> for SwiftUI.
</p>
</div>

<div align="center">

![Drafter demo](https://raw.githubusercontent.com/AndroidPoet/DrafterFlutter/main/Art/demo.gif)

<sub><a href="https://github.com/AndroidPoet/DrafterFlutter/raw/main/Art/demo.mp4">▶ Watch the full-resolution video</a></sub>

</div>

## Features

- 📊 **27 chart types** out of the box:
  - **Bars** — Bar, Grouped Bar, Stacked Bar, Histogram, Waterfall
  - **Lines** — Line, Grouped Line, Stacked Line, Step Line, Area
  - **Distribution** — Scatter, Bubble, Box Plot, Candlestick
  - **Part-to-whole** — Pie, Donut, Funnel, Treemap, Polar Area, Sunburst
  - **Specialized** — Radar, Gantt, Gauge, Bullet, Sankey, Stream Graph, Contribution Heatmap
- 🎨 Highly customizable appearance with a shared `DrafterThemeColors` (light/dark, custom palettes)
- ✨ Smooth, premium rendering — Catmull-Rom curves, soft gradient fills, rounded shapes
- 🎬 Built-in left-to-right reveal animation with a one-line `replay` hook
- 👆 **Opt-in interactivity** — wrap any chart in `InteractiveChart` for a trackball tooltip, tap value-selection and drag range-selection, painted on the same `Canvas` (no extra dependencies)
- 🚀 Pure Flutter `CustomPaint`/`Canvas`, **zero dependencies** beyond the SDK
- 📱 Immutable value-type data models and an `InheritedWidget`-based theme
- ♿️ **Semantics built in** — every chart announces its kind and a data summary, so a `Canvas` is never silently invisible to screen readers
- 🧩 **One consistent, type-safe API** — every chart takes its bound elements directly (`points:`, `series:`, `bars:`, `slices:`, `nodes:`…), so a label can't desync from its value and there's no `data:` wrapper to learn

## Installation

Add Drafter to your `pubspec.yaml`:

```yaml
dependencies:
  drafter: ^0.3.0
```

Or from the command line:

```bash
flutter pub add drafter
```

And import it:

```dart
import 'package:drafter/drafter.dart';
```

## Anatomy of a chart

Every chart is a Flutter `Widget` that takes an immutable data model. Two optional
knobs are shared by all charts:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `animate`  | `true`  | Play the left-to-right reveal on first build. Pass `false` to draw fully revealed. |
| `replay`   | `0`     | Change this value (e.g. from a button) to replay the entrance animation. |
| `duration` | `≈1s`   | How long the entrance reveal runs. |

```dart
AreaChart(points: areaPoints)                     // animates on build
AreaChart(points: areaPoints, animate: false)     // static
AreaChart(points: areaPoints, replay: replayKey)  // bump replayKey to re-run
```

Size charts like any Flutter widget (`SizedBox`, `AspectRatio`, `Expanded`…), and
set the palette / light-dark with a `DrafterTheme` ancestor.

For the simplest single-series charts there are **values-first** convenience
constructors, so trivial cases can skip building labeled elements:

```dart
LineChart.values(values: [40, 65, 50, 80, 70, 95])
AreaChart.values(values: [12, 18, 9, 24, 20, 30], color: DrafterColors.teal)
SimpleBarChart.values(values: [24, 38, 30, 46])
StepLineChart.values(values: [10, 25, 18, 32])
ScatterPlot.values(values: [(1, 2), (3, 5), (4, 3)])   // raw (x, y) pairs
```

The full point/series form (`points:`, `series:`, `bars:`) is the primary API for
labels, multi-series, and per-element colors.

## Interactivity

Charts are static by default. To make one interactive, drive it from a
**renderer** (every chart widget `Xxx` has a matching `XxxRenderer`) and wrap that
in an `InteractiveChart`:

```dart
InteractiveChart(
  renderer: LineChartRenderer(points: points),
  interaction: ChartInteraction(
    rangeSelection: true,
    onSelected: (sel) => print('tapped ${sel?.mark.value}'),
    onRangeSelected: (range) => print('range ${range?.startIndex}..${range?.endIndex}'),
  ),
)
```

You get, painted on the same `Canvas` with no extra dependencies:

- **Trackball + tooltip** following the pointer (hover) or finger (drag). On
  multi-series cartesian charts the tooltip lists every series at that column,
  with overlapping rows automatically de-overlapped.
- **Tap to select** the nearest datum — highlighted, and reported via
  `onSelected` (a `ChartSelection`, or `null` when the tap misses).
- **Drag to select a range** of columns (cartesian charts) — banded, and
  reported via `onRangeSelected` (a `ChartRange` with every datum inside it).

Every chart type is supported. Cartesian charts (line/area/step/bar/candlestick/
stream) use a trackball column; radial and free-layout charts
(pie/donut/polar/sunburst/treemap/heatmap/funnel/bullet/box-plot/bubble/gantt/
sankey/scatter/radar) highlight the individual mark under the pointer.

`ChartInteraction` lets you enable just what you want:

| Flag | Default | Effect |
|------|---------|--------|
| `tooltip` | `true` | Trackball + tooltip on hover/drag. |
| `selection` | `true` | Tap selects the nearest datum (fires `onSelected`). |
| `rangeSelection` | `false` | Drag selects a column range (fires `onRangeSelected`). |
| `rowLabel` | — | Custom `String Function(PlotMark)` to format a tooltip row. |

A renderer that doesn't implement `InteractiveRenderer` (or an empty
`ChartInteraction`) degrades gracefully to a plain, static chart.

## Table of Contents

1. [Bar Charts](#bar-charts) — [Simple](#simple-bar-chart) · [Grouped](#grouped-bar-chart) · [Stacked](#stacked-bar-chart)
2. [Line Charts](#line-charts) — [Simple](#simple-line-chart) · [Grouped](#grouped-line-chart) · [Stacked](#stacked-line-chart)
3. [Histogram Chart](#histogram-chart)
4. [Waterfall Chart](#waterfall-chart)
5. [Area Chart](#area-chart)
6. [Step Line Chart](#step-line-chart)
7. [Pie & Donut Chart](#pie--donut-chart)
8. [Scatter Plot Chart](#scatter-plot-chart)
9. [Bubble Chart](#bubble-chart)
10. [Candlestick Chart](#candlestick-chart)
11. [Box Plot Chart](#box-plot-chart)
12. [Radar Chart](#radar-chart)
13. [Gauge Chart](#gauge-chart)
14. [Bullet Chart](#bullet-chart)
15. [Funnel Chart](#funnel-chart)
16. [Treemap Chart](#treemap-chart)
17. [Polar Area Chart](#polar-area-chart)
18. [Sunburst Chart](#sunburst-chart)
19. [Sankey Chart](#sankey-chart)
20. [Stream Graph Chart](#stream-graph-chart)
21. [Gantt Chart](#gantt-chart)
22. [Heatmap Chart](#heatmap-chart)

> Every snippet below renders a single chart. Wrap it in a `SizedBox` (or any
> sizing widget) to give it bounds, as shown in the first example.

## Bar Charts

### Simple Bar Chart

```dart
SizedBox(
  height: 300,
  child: SimpleBarChart(
    bars: const [BarItem('Q1', 24), BarItem('Q2', 38), BarItem('Q3', 30), BarItem('Q4', 46)],
  ),
)
```

### Grouped Bar Chart

```dart
GroupedBarChart(
  series: [
    ChartSeries(name: '2023', color: DrafterColors.blue, values: [20, 34, 26, 40]),
    ChartSeries(name: '2024', color: DrafterColors.teal, values: [28, 30, 38, 44]),
  ],
  categories: const ['Q1', 'Q2', 'Q3', 'Q4'],
)
```

### Stacked Bar Chart

```dart
StackedBarChart(
  series: [
    ChartSeries(color: DrafterColors.blue,   values: [12, 16, 14, 20]),
    ChartSeries(color: DrafterColors.teal,   values: [8, 10, 12, 14]),
    ChartSeries(color: DrafterColors.violet, values: [6, 8, 10, 9]),
  ],
  categories: const ['Q1', 'Q2', 'Q3', 'Q4'],
)
```

## Line Charts

### Simple Line Chart

```dart
LineChart(
  points: const [ChartPoint('Jan', 40), ChartPoint('Feb', 65), ChartPoint('Mar', 50), ChartPoint('Apr', 80)],
  color: DrafterColors.blue,
)
```

### Grouped Line Chart

```dart
GroupedLineChart(
  series: [
    ChartSeries(name: 'A', color: DrafterColors.blue, values: [30, 45, 40, 70]),
    ChartSeries(name: 'B', color: DrafterColors.teal, values: [20, 35, 50, 45]),
  ],
  categories: const ['Jan', 'Feb', 'Mar', 'Apr'],
)
```

### Stacked Line Chart

```dart
StackedLineChart(
  series: [
    ChartSeries(color: DrafterColors.violet, values: [10, 14, 12, 20]),
    ChartSeries(color: DrafterColors.green,  values: [8, 10, 14, 12]),
  ],
  categories: const ['Jan', 'Feb', 'Mar', 'Apr'],
)
```

## Histogram Chart

```dart
Histogram(
  values: const [2, 3, 3, 4, 5, 5, 6, 7, 8, 9, 10, 12, 13, 15],
  binCount: 5,
)
```

## Waterfall Chart

Each `WaterfallStep` is an incremental change applied to `initialValue`; the
number of bars is driven by `steps` (one step per delta), so the counts always
line up.

```dart
WaterfallChart(
  steps: const [WaterfallStep('Revenue', 50), WaterfallStep('Cost', -20), WaterfallStep('Profit', 30)],
  initialValue: 100,
)
```

Opt into a leading **Start** bar (the initial value) and a trailing **Total**
bar (the final running total) — the classic Start … Total waterfall:

```dart
WaterfallChart(
  steps: const [WaterfallStep('Sales', 60), WaterfallStep('Costs', -25), WaterfallStep('Tax', -10)],
  initialValue: 50,
  startLabel: 'Start',   // draws a leading bar at the initial value
  totalLabel: 'Net',     // draws a trailing bar at the final running total
)
```

> Counts don't have to be perfect: every chart drives its element count from the
> value arrays, and mismatched `categories`/`colors` are handled gracefully
> (missing entries fall back, extras are ignored) — no ghost columns or crashes.

## Area Chart

```dart
AreaChart(
  points: const [
    ChartPoint('Jan', 12), ChartPoint('Feb', 28), ChartPoint('Mar', 18),
    ChartPoint('Apr', 34), ChartPoint('May', 24), ChartPoint('Jun', 40),
  ],
  color: DrafterColors.blue,
)
```

## Step Line Chart

```dart
StepLineChart(
  points: const [
    ChartPoint('Jan', 10), ChartPoint('Feb', 25),
    ChartPoint('Mar', 18), ChartPoint('Apr', 32),
  ],
)
```

## Pie & Donut Chart

```dart
final slices = [
  PieSlice(value: 40, color: DrafterColors.blue,   label: 'Blue'),
  PieSlice(value: 30, color: DrafterColors.teal,   label: 'Teal'),
  PieSlice(value: 20, color: DrafterColors.violet, label: 'Violet'),
  PieSlice(value: 10, color: DrafterColors.amber,  label: 'Amber'),
];

PieChart(slices: slices);
DonutChart(slices: slices);
```

## Scatter Plot Chart

```dart
ScatterPlot(
  points: [
    const ScatterPoint(x: 1, y: 2),
    const ScatterPoint(x: 2, y: 5),
    ScatterPoint(x: 3, y: 3, color: DrafterColors.coral),
  ],
)
```

## Bubble Chart

```dart
BubbleChart(
  series: [
    [ BubbleData(x: 10, y: 26, size: 30, color: DrafterColors.blue),
      BubbleData(x: 26, y: 30, size: 60, color: DrafterColors.blue) ],
    [ BubbleData(x: 14, y: 15, size: 30, color: DrafterColors.teal),
      BubbleData(x: 22, y: 36, size: 45, color: DrafterColors.teal) ],
  ],
)
```

## Candlestick Chart

```dart
CandlestickChart(
  candles: const [
    Candle(label: '1', open: 20, high: 30, low: 16, close: 26),
    Candle(label: '2', open: 26, high: 32, low: 22, close: 23),
    Candle(label: '3', open: 23, high: 28, low: 18, close: 27),
    Candle(label: '4', open: 27, high: 38, low: 25, close: 35),
  ],
  movingAverages: [MovingAverage(period: 3, color: DrafterColors.amber)],
)
```

## Box Plot Chart

```dart
BoxPlotChart(
  groups: [
    BoxGroup(label: 'A', min: 5,  q1: 18, median: 28, q3: 38, max: 52, color: DrafterColors.violet),
    BoxGroup(label: 'B', min: 10, q1: 22, median: 30, q3: 41, max: 48, color: DrafterColors.blue),
    BoxGroup(label: 'C', min: 8,  q1: 15, median: 24, q3: 33, max: 44, color: DrafterColors.teal),
  ],
)
```

## Radar Chart

```dart
RadarChart(
  series: [
    RadarSeries(color: DrafterColors.blue, values: const {'Speed': 0.8, 'Power': 0.6, 'Range': 0.9}),
    RadarSeries(color: DrafterColors.teal, values: const {'Speed': 0.5, 'Power': 0.9, 'Range': 0.6}),
  ],
)
```

## Gauge Chart

```dart
GaugeChart(value: 72, min: 0, max: 100, label: 'Score', color: DrafterColors.teal)
```

## Bullet Chart

```dart
BulletChart(
  metrics: [
    BulletMetric(label: 'Revenue', value: 72, target: 80, ranges: const [40, 65, 100], color: DrafterColors.blue),
    BulletMetric(label: 'Profit',  value: 55, target: 50, ranges: const [30, 60, 90],  color: DrafterColors.teal),
  ],
)
```

## Funnel Chart

```dart
FunnelChart(
  stages: [
    FunnelStage(label: 'Visits',  value: 100, color: DrafterColors.blue),
    FunnelStage(label: 'Signups', value: 64,  color: DrafterColors.teal),
    FunnelStage(label: 'Trials',  value: 38,  color: DrafterColors.violet),
    FunnelStage(label: 'Paid',    value: 18,  color: DrafterColors.amber),
  ],
)
```

## Treemap Chart

```dart
TreemapChart(
  items: [
    TreemapItem(label: 'Mobile',  value: 45, color: DrafterColors.blue),
    TreemapItem(label: 'Desktop', value: 30, color: DrafterColors.teal),
    TreemapItem(label: 'Tablet',  value: 15, color: DrafterColors.violet),
    TreemapItem(label: 'Watch',   value: 8,  color: DrafterColors.amber),
  ],
)
```

## Polar Area Chart

```dart
PolarAreaChart(
  slices: [
    PolarSlice(label: 'N', value: 40, color: DrafterColors.blue),
    PolarSlice(label: 'E', value: 35, color: DrafterColors.violet),
    PolarSlice(label: 'S', value: 30, color: DrafterColors.green),
    PolarSlice(label: 'W', value: 22, color: DrafterColors.amber),
  ],
)
```

## Sunburst Chart

```dart
SunburstChart(
  roots: [
    SunburstNode(label: 'Web', value: 50, color: DrafterColors.blue, children: [
      SunburstNode(label: 'HTML', value: 20, color: DrafterColors.blue),
      SunburstNode(label: 'CSS',  value: 15, color: DrafterColors.blue),
      SunburstNode(label: 'JS',   value: 15, color: DrafterColors.blue),
    ]),
    SunburstNode(label: 'Mobile', value: 35, color: DrafterColors.teal, children: [
      SunburstNode(label: 'iOS',     value: 20, color: DrafterColors.teal),
      SunburstNode(label: 'Android', value: 15, color: DrafterColors.teal),
    ]),
  ],
)
```

## Sankey Chart

```dart
SankeyChart(
  nodes: [
    SankeyNode(id: 'a', label: 'Source A', column: 0, color: DrafterColors.blue),
    SankeyNode(id: 'b', label: 'Source B', column: 0, color: DrafterColors.teal),
    SankeyNode(id: 'm', label: 'Hub',      column: 1, color: DrafterColors.violet),
    SankeyNode(id: 'x', label: 'Out X',    column: 2, color: DrafterColors.amber),
    SankeyNode(id: 'y', label: 'Out Y',    column: 2, color: DrafterColors.green),
  ],
  links: const [
    SankeyLink(from: 'a', to: 'm', value: 30),
    SankeyLink(from: 'b', to: 'm', value: 20),
    SankeyLink(from: 'm', to: 'x', value: 28),
    SankeyLink(from: 'm', to: 'y', value: 22),
  ],
)
```

## Stream Graph Chart

```dart
StreamGraphChart(
  series: [
    ChartSeries(name: 'A', color: DrafterColors.blue, values: [4, 6, 8, 7, 9, 6]),
    ChartSeries(name: 'B', color: DrafterColors.teal, values: [3, 4, 6, 8, 7, 9]),
  ],
  categories: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
)
```

## Gantt Chart

```dart
GanttChart(
  tasks: const [
    GanttTask(name: 'Design', startMonth: 0, duration: 2, color: DrafterColors.blue),
    GanttTask(name: 'Build',  startMonth: 2, duration: 3, color: DrafterColors.teal),
  ],
)
```

## Heatmap Chart

```dart
final start = DateTime(2026, 1, 1);
final contributions = [
  for (var day = 0; day < 365; day++)
    ContributionData(
      date: start.add(Duration(days: day)),
      count: (day * 13 + day % 7 * 5) % 16 - 4,
    ),
];

Heatmap(contributions: contributions);
```

## Theming

All charts read their palette and light/dark colors from the nearest
`DrafterTheme` ancestor. Set it once for a subtree:

```dart
DrafterTheme(
  colors: DrafterThemeColors.dark,   // or .light, or a custom set
  child: Column(
    children: [
      AreaChart(points: areaPoints),
      PieChart(slices: pieSlices),
    ],
  ),
)
```

A custom palette is just a `DrafterThemeColors`:

```dart
DrafterTheme(
  colors: DrafterThemeColors(
    palette: [DrafterColors.blue, DrafterColors.teal, DrafterColors.indigo],
    grid: const Color(0xFFEDF0F5),
    label: const Color(0xFF9AA3B2),
    surface: const Color(0xFFFFFFFF),
    isDark: false,
  ),
  child: chart,
)
```

`DrafterTheme.brightness(dark: true, child: …)` is a convenience for picking the
built-in light/dark set by a boolean. Each chart's geometry lives in a pure
`ChartRenderer` hosted by `ChartCanvas`, so the drawing is testable and the
theming + reveal animation are centralized in one place.

## Writing a custom chart

The everyday `package:drafter/drafter.dart` import gives you the chart widgets,
data models and theming. The lower-level building blocks for authoring your own
chart live in a separate entrypoint so they stay out of your way:

```dart
import 'package:drafter/drafter.dart';   // DrafterThemeColors, data models
import 'package:drafter/painting.dart';  // ChartRenderer, ChartCanvas, helpers

class MyRenderer extends ChartRenderer {
  const MyRenderer();

  @override
  void draw(Canvas canvas, Size size, DrafterThemeColors theme, double progress) {
    final bounds = ChartBounds(size);              // shared layout math
    canvas.drawRect(bounds.rect, Paint()..color = theme.colorAt(0));
    drawChartText(canvas, 'hi', bounds.rect.center, color: theme.label);
  }

  @override
  String get accessibilityLabel => 'My chart';
  @override
  String get accessibilityValue => 'a summary of the data';
}

// Host it in the shared animating canvas:
const ChartCanvas(renderer: MyRenderer());
```

`painting.dart` exposes the renderer base (`ChartRenderer`/`ChartCanvas`), the
layout helpers (`ChartBounds`, `RadialLayout`, `ChartAxis`, `HAlign`/`VAlign`),
the smooth-graphics helpers (`smoothPath`, `drawSmoothLine`, `drawChartText`,
`areaGradientShader`), and the shared formatters.

## Accessibility

A `Canvas` is a single opaque drawing — by default screen readers skip right over
it. Drafter fixes this for you: `ChartCanvas` wraps each chart in one `Semantics`
node and pulls its description from the renderer, so every chart announces **what
it is** and **a summary of its data** with no extra work at the call site.

```dart
AreaChart(points: const [ChartPoint('Jan', 40), ChartPoint('Feb', 65), ChartPoint('Mar', 30)])
// TalkBack/VoiceOver: "Area chart, 3 points, Jan 40, Feb 65, Mar 30"

GaugeChart(value: 72, min: 0, max: 100, label: 'Score')
// TalkBack/VoiceOver: "Gauge, Score 72 of 0 to 100"
```

The label/value come from each `ChartRenderer`'s `accessibilityLabel` and
`accessibilityValue`, so if you write a custom renderer you can describe it the
same way.

## Demo

A runnable gallery of every chart — wrapped in light-themed cards — lives in
[`example/`](example). Run it on any platform:

```bash
cd example
flutter run            # or: flutter run -d macos / -d chrome
```

## Contributing

Contributions are welcome! Found a bug, have an improvement, or want a new chart?
Open an issue or a pull request — see [CONTRIBUTING.md](https://github.com/AndroidPoet/DrafterFlutter/blob/main/CONTRIBUTING.md).

## Find this repository useful? :heart:
Support it by joining __[stargazers](https://github.com/AndroidPoet/DrafterFlutter/stargazers)__ for this repository. :star: <br>
Also, __[follow me](https://github.com/AndroidPoet)__ on GitHub for my next creations! 🤩

## License

```
Designed and developed by AndroidPoet (Ranbir Singh)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
