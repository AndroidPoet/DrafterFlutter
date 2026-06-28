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
import 'package:drafter/src/core/chart_math.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One hit-testable datum a chart drew: a value at a pixel position, carrying
/// enough context (series, label, color) to fill a tooltip row or a highlight.
///
/// [center] is the focal pixel (a line vertex, a bar top, a candle close).
/// [region] is an optional pixel rectangle that "owns" the datum — set for bars
/// so a tap anywhere inside the bar selects it; `null` for point-like charts,
/// where hit-testing falls back to nearest-[center].
@immutable
class PlotMark {
  /// Creates a hit-testable mark at [center] carrying its [value] and tooltip
  /// context, with an optional [region]/[hitPath] for area hit-testing.
  const PlotMark({
    required this.index,
    required this.seriesIndex,
    required this.seriesName,
    required this.label,
    required this.value,
    required this.center,
    required this.color,
    this.region,
    this.hitPath,
  });

  /// The x-column index this datum belongs to (shared across series at one x).
  final int index;

  /// Which series this datum came from (0 for single-series charts).
  final int seriesIndex;

  /// The series' name, for multi-series tooltip rows ('' when unnamed).
  final String seriesName;

  /// The x-axis category label for this column ('' when unlabeled).
  final String label;

  /// The datum's own value (a series' contribution, not a cumulative total).
  final double value;

  /// The focal pixel position used for trackball markers and highlights.
  final Offset center;

  /// The color this datum was drawn with.
  final Color color;

  /// The pixel rectangle that selects this datum on tap; `null` for point or
  /// non-rectangular charts. Cheaper than [hitPath] when the area is a rect
  /// (bars, treemap cells, heatmap cells, gantt bars).
  final Rect? region;

  /// An arbitrary pixel shape that selects this datum on tap — for wedges and
  /// other non-rectangular areas (pie/donut/polar/sunburst slices, funnel
  /// segments). Checked after [region]; falls back to nearest-[center] if both
  /// are null.
  final Path? hitPath;
}

/// The retained geometry of a rendered chart: the plot [bounds], an optional
/// index-based [scale] (present for uniformly-spaced charts, `null` for free
/// scatter/bar layouts), every [marks] datum, and the x-axis [categories].
///
/// A renderer produces this from the *same* math it paints with, so the
/// interaction layer hit-tests exactly what the user sees.
@immutable
class ChartScene {
  /// Creates a scene from a renderer's drawn geometry: its plot [bounds], the
  /// hit-testable [marks], and optionally the cartesian [scale] and x-axis
  /// [categories].
  const ChartScene({
    required this.bounds,
    required this.marks,
    this.scale,
    this.categories = const [],
  });

  /// An empty scene — used as the graceful fallback for non-interactive charts.
  static const ChartScene empty = ChartScene(
    bounds: null,
    marks: <PlotMark>[],
  );

  /// The plot rectangle, or `null` for an empty scene.
  final ChartBounds? bounds;

  /// The reversible index↔pixel scale for cartesian charts; `null` for radial
  /// and free-layout charts (which hit-test per-mark instead of per-column).
  final CartesianScale? scale;

  /// Every hit-testable datum the chart drew.
  final List<PlotMark> marks;

  /// The x-axis category labels, one per column (may be empty).
  final List<String> categories;

  /// Whether the scene has no marks to hit-test.
  bool get isEmpty => marks.isEmpty;
}

/// The result of a value (tap) selection: the single datum that was hit.
@immutable
class ChartSelection {
  /// Wraps the single [mark] a tap selected.
  const ChartSelection(this.mark);

  /// The datum that was hit.
  final PlotMark mark;
}

/// The result of a range (drag) selection: the inclusive column span plus every
/// datum inside it, so a consumer can total/average the selection.
@immutable
class ChartRange {
  /// Creates a range spanning columns [startIndex] to [endIndex] inclusive,
  /// carrying every datum ([marks]) within it.
  const ChartRange({
    required this.startIndex,
    required this.endIndex,
    required this.marks,
  });

  /// The first column index in the (inclusive) range.
  final int startIndex;

  /// The last column index in the (inclusive) range.
  final int endIndex;

  /// Every datum whose column falls within the range.
  final List<PlotMark> marks;
}
