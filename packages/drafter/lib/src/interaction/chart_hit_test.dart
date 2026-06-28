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
import 'dart:ui';

import 'package:drafter/src/interaction/chart_scene.dart';

/// Pure hit-testing over a [ChartScene]. No Flutter painting — every function
/// here is a deterministic query so the interaction layer (and tests) can reason
/// about gestures without a canvas.
abstract final class ChartHitTest {
  /// The default tap radius (logical px) within which a point-like mark counts
  /// as hit when no [PlotMark.region] contains the pointer.
  static const double tapRadius = 28;

  /// The column index nearest pixel x [px] — the trackball column. Uses the
  /// scene's [ChartScene.scale] when present, else the nearest mark by center x.
  static int? nearestIndexAtX(ChartScene scene, double px) {
    if (scene.isEmpty || !px.isFinite) return null;
    final scale = scene.scale;
    if (scale != null) return scale.nearestIndex(px);

    int? best;
    var bestDist = double.infinity;
    for (final m in scene.marks) {
      final d = (m.center.dx - px).abs();
      if (d < bestDist) {
        bestDist = d;
        best = m.index;
      }
    }
    return best;
  }

  /// Every mark sharing column [index] (all series stacked at one x).
  static List<PlotMark> marksAtIndex(ChartScene scene, int index) => [
    for (final m in scene.marks)
      if (m.index == index) m,
  ];

  /// The mark a tap at [point] selects: first any mark whose [PlotMark.region]
  /// contains the point (bars), else the nearest [PlotMark.center] within
  /// [radius]. Returns `null` when nothing is close enough.
  static PlotMark? markAt(
    ChartScene scene,
    Offset point, {
    double radius = tapRadius,
  }) {
    if (scene.isEmpty || !point.dx.isFinite || !point.dy.isFinite) return null;

    for (final m in scene.marks) {
      final r = m.region;
      if (r != null && r.contains(point)) return m;
      final p = m.hitPath;
      if (p != null && p.contains(point)) return m;
    }

    // Compare squared distances to avoid a sqrt per mark (called on every hover
    // move in per-mark mode).
    PlotMark? best;
    var bestSq = double.infinity;
    for (final m in scene.marks) {
      final dx = m.center.dx - point.dx;
      final dy = m.center.dy - point.dy;
      final sq = dx * dx + dy * dy;
      if (sq < bestSq) {
        bestSq = sq;
        best = m;
      }
    }
    return (best != null && bestSq <= radius * radius) ? best : null;
  }

  /// The inclusive column range spanned by a drag from pixel x [startX] to
  /// [endX], with every mark inside it. Returns `null` for an empty scene.
  static ChartRange? rangeBetween(
    ChartScene scene,
    double startX,
    double endX,
  ) {
    if (scene.isEmpty) return null;
    final a = nearestIndexAtX(scene, math.min(startX, endX));
    final b = nearestIndexAtX(scene, math.max(startX, endX));
    if (a == null || b == null) return null;
    final lo = math.min(a, b);
    final hi = math.max(a, b);
    return ChartRange(
      startIndex: lo,
      endIndex: hi,
      marks: [
        for (final m in scene.marks)
          if (m.index >= lo && m.index <= hi) m,
      ],
    );
  }
}
