# Changelog

## Unreleased

### Added
* `ScatterPlot.values(values: [(x, y), …])` — a values-first convenience
  constructor matching the line/area/bar charts.
* `package:drafter/painting.dart` — a dedicated entrypoint for the chart-authoring
  extension API (`ChartRenderer`, `ChartCanvas`, layout math, smooth-graphics
  helpers), keeping the main `drafter.dart` namespace focused on charts/data/theme.

### Changed (breaking)
* The low-level drawing/layout helpers (`smoothPath`, `trimPath`, `drawChartText`,
  `ChartBounds`, `RadialLayout`, `HAlign`/`VAlign`, etc.) are no longer exported
  from `package:drafter/drafter.dart` — import `package:drafter/painting.dart`
  instead. The everyday chart widgets, data models and theming are unchanged.

### Fixed
* `BubbleChart` no longer crashes (debug assert via a non-finite `Offset`) when
  every bubble shares a zero on an axis.
* `DrafterThemeColors` `==`/`hashCode` now include the `palette`, so a
  palette-only theme change correctly repaints the charts.
* `colorAt` falls back instead of throwing on an empty palette.
* `ChartCanvas` now picks up a changed `duration` on rebuild.

### Performance
* Static label text is cached (`TextPainter`s are no longer re-shaped every
  animation frame), the painter repaints off the animation listenable inside a
  `RepaintBoundary`, line charts compute path metrics once per frame instead of
  twice, and the stream graph no longer builds its top spline twice per band.

## 0.1.0

Initial release — a premium, dependency-free Flutter charting library, a faithful
port of the Compose/SwiftUI Drafter charts.

* **~27 chart types** across one shared core: line, grouped line, stacked line,
  area, step line, simple/grouped/stacked bar, histogram, waterfall, pie, donut,
  radar, polar area, gauge, scatter, bubble, heatmap, funnel, bullet, box plot,
  treemap, sunburst, sankey, gantt, stream graph and candlestick.
* Renderer architecture: every chart is a pure `ChartRenderer` drawing into a
  `Canvas`, hosted by a thin widget over shared data models, axis/radial math,
  Catmull-Rom smooth graphics and a left-to-right reveal animation.
* `DrafterTheme` / `DrafterThemeColors` for light/dark palettes — a calm,
  premium color set (no harsh red).
* Built-in semantics: each chart exposes an accessibility label and value.
