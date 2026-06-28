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

/// Drafter's **extension API** — import this alongside
/// `package:drafter/drafter.dart` when you write a custom [ChartRenderer] or
/// draw directly into a chart `Canvas`.
///
/// The everyday chart widgets, data models and theming live in the main
/// `package:drafter/drafter.dart` entrypoint. This secondary entrypoint exposes
/// the lower-level building blocks so they don't clutter the primary namespace:
///
/// * [ChartRenderer] / [ChartCanvas] — the renderer base and its animating host.
/// * Layout math — [ChartAxis], [ChartBounds], [RadialLayout], [ChartText],
///   [HAlign], [VAlign], `normalizedLabels`.
/// * Smooth graphics — `smoothPath`, `drawSmoothLine`, `areaGradientShader`,
///   `drawChartText`, `measureChartText`, `drawVertexDot`, `trimPath`.
/// * Interaction graphics — `drawTrackball`, `drawTooltip` ([TooltipRow]),
///   `drawSelectionBand`, `drawHighlightRing` — for custom interactive renderers.
/// * Hit-testing & label layout — [ChartHitTest], [LabelLayout].
/// * [ChartFormatting] / [AccessibilityFormat] — shared number/label helpers.
library;

export 'src/core/chart_formatting.dart';
export 'src/core/chart_graphics.dart';
export 'src/core/chart_math.dart';
export 'src/core/chart_renderer.dart';
// Interaction extension API: pure hit-testing + label de-overlap, for custom
// charts that want to participate in tooltips/selection.
export 'src/interaction/chart_hit_test.dart';
export 'src/interaction/label_layout.dart';
