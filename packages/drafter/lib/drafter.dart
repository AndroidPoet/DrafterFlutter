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

/// Drafter — a premium, dependency-free Flutter charting library.
///
/// A faithful port of the Compose/SwiftUI Drafter charts: each chart is a pure
/// renderer (drawing into a `Canvas`) hosted by a thin widget over a shared
/// core — data models, axis/radial math, Catmull-Rom smooth graphics, and a
/// left-to-right reveal animation. Calm, premium palette; no harsh red.
///
/// This entrypoint exports the chart widgets, their data models, and theming —
/// everything most apps need. The lower-level extension API (the `ChartRenderer`
/// base, `ChartCanvas`, layout math and smooth-graphics helpers) lives in a
/// separate `package:drafter/painting.dart` import, so it stays out of the way
/// unless you're writing a custom chart.
library;

// Charts.
export 'src/charts/area_chart.dart';
export 'src/charts/bar_chart.dart';
export 'src/charts/box_plot_chart.dart';
export 'src/charts/bubble_chart.dart';
export 'src/charts/bullet_chart.dart';
export 'src/charts/candlestick_chart.dart';
export 'src/charts/funnel_chart.dart';
export 'src/charts/gantt_chart.dart';
export 'src/charts/gauge_chart.dart';
export 'src/charts/heatmap.dart';
export 'src/charts/line_chart.dart';
export 'src/charts/pie_chart.dart';
export 'src/charts/polar_area_chart.dart';
export 'src/charts/radar_chart.dart';
export 'src/charts/sankey_chart.dart';
export 'src/charts/scatter_plot.dart';
export 'src/charts/step_line_chart.dart';
export 'src/charts/stream_graph_chart.dart';
export 'src/charts/sunburst_chart.dart';
export 'src/charts/treemap_chart.dart';
// Core data models. (Rendering helpers — chart_graphics/chart_math/
// chart_renderer/chart_formatting — are exported from `painting.dart`.)
export 'src/core/chart_data.dart';
// The renderer base + interaction capability appear in `InteractiveChart`'s
// public signature, so they're reachable from this entrypoint too. (The rest of
// the authoring API — ChartCanvas, layout math, graphics — stays in
// `painting.dart`.)
export 'src/core/chart_renderer.dart' show ChartRenderer, InteractiveRenderer;
// Interactivity: the wrapper widget + the scene/selection model it reports.
// (Hit-testing and label-layout helpers live in `painting.dart`.)
export 'src/interaction/chart_scene.dart';
export 'src/interaction/interactive_chart.dart';
// Theme.
export 'src/theme/drafter_colors.dart';
export 'src/theme/drafter_theme.dart';
