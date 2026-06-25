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
/// [ChartRenderer] (drawing into a `Canvas`) hosted by a thin widget over a
/// shared core — data models, axis/radial math, Catmull-Rom smooth graphics,
/// and a left-to-right reveal animation. Calm, premium palette; no harsh red.
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
// Core.
export 'src/core/chart_data.dart';
export 'src/core/chart_formatting.dart';
export 'src/core/chart_graphics.dart';
export 'src/core/chart_math.dart';
export 'src/core/chart_renderer.dart';
// Theme.
export 'src/theme/drafter_colors.dart';
export 'src/theme/drafter_theme.dart';
