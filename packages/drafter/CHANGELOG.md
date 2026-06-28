# Changelog

## 0.3.0

### Added
* **Interactivity** — a new `InteractiveChart` wrapper turns any chart into a
  touch/mouse-driven one: a trackball with a de-overlapping multi-series tooltip,
  tap value-selection, and drag range-selection, all painted on a non-rebuilding
  Canvas overlay so the base chart's reveal animation is never disturbed. Works
  across **every** chart type — cartesian charts (line/area/step/bar/candlestick/
  stream) get a trackball-column tooltip + range band; radial and free-layout
  charts (pie/donut/polar/sunburst/treemap/heatmap/funnel/bullet/box-plot/bubble/
  gantt/sankey/scatter/radar) get per-mark hover highlighting.
* `ChartInteraction` config — independently toggle `tooltip`, `selection` and
  `rangeSelection`, with `onSelected` / `onRangeSelected` callbacks and a custom
  `rowLabel` tooltip formatter.
* Public interaction model — `ChartScene`, `PlotMark`, `ChartSelection`,
  `ChartRange` (from `package:drafter/drafter.dart`) and the pure `ChartHitTest`
  / `LabelLayout` helpers (from `package:drafter/painting.dart`), so you can
  hit-test custom charts. Renderers opt in via the `InteractiveRenderer`
  interface and a `buildScene(Size)` derived from the same math they paint with.
* `CartesianScale` — a reversible data↔pixel mapping shared by paint and
  hit-test, so the two can never drift.
* Every chart widget (and `InteractiveChart`) now exposes a `duration` parameter
  to tune the entrance-animation length.
* `ChartRenderer` / `InteractiveRenderer` are now re-exported from the main
  `package:drafter/drafter.dart` entrypoint (they appear in `InteractiveChart`'s
  signature).

### Fixed
* **Robustness** — non-finite (`NaN` / `Infinity`) input values are now coerced
  at ingestion across all value-based charts, so malformed data can no longer
  produce a non-finite `Canvas` coordinate (a debug assert) or reach a `toInt()`
  (which threw `UnsupportedError` even in release builds — histogram binning,
  bubble axis rounding, line/bar axis steps).
* `InteractiveChart` resets its interaction state when its `renderer` changes, so
  a stale selection highlight can't linger over new data, and it no longer writes
  to its disposed notifier if the pointer exits during teardown.

### Performance
* The interaction overlay only repaints when the resolved hover/selection state
  actually changes (value-equal snapshots), is isolated in its own
  `RepaintBoundary`, and hit-tests by squared distance.
* Layout-heavy renderers (heatmap, treemap, sankey, candlestick moving-averages)
  memoize their progress-independent layout per size instead of recomputing it on
  every animation frame; candlestick moving averages now use an O(n) sliding
  window.

### Documentation
* The full public API is now documented (every constructor, field and getter),
  enforced by enabling `public_member_api_docs` in the analyzer.

## 0.2.0

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
