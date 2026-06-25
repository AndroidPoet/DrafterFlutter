# Changelog

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
