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

/// One-dimensional label de-collision used wherever chart labels would overlap:
/// axis ticks (drop overlapping labels) and trackball value rows (nudge them
/// apart). Pure value math — no canvas, fully unit-testable.
abstract final class LabelLayout {
  /// Nudges [centers] apart so adjacent labels keep at least [minGap] between
  /// their centers, while staying within `[lo, hi]`. Preserves input order in
  /// the returned list; the result is the adjusted center for each input index.
  ///
  /// Use for stacked trackball value labels at one x: several series can share a
  /// y, and this spreads them into a readable column without reordering.
  static List<double> spread(
    List<double> centers,
    double minGap,
    double lo,
    double hi,
  ) {
    final n = centers.length;
    if (n == 0) return const [];
    if (n == 1) return [centers[0].clamp(lo, hi)];

    // Work in sorted-by-position order so neighbors are actually adjacent.
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => centers[a].compareTo(centers[b]));
    final placed = List<double>.filled(n, 0);

    // Forward pass: push each label down past the previous one.
    var cursor = lo;
    for (final idx in order) {
      var p = centers[idx];
      if (p < cursor) p = cursor;
      placed[idx] = p;
      cursor = p + minGap;
    }

    // If we overran the bottom, pull back up from [hi] to fit within bounds.
    if (cursor - minGap > hi) {
      cursor = hi;
      for (var k = n - 1; k >= 0; k--) {
        final idx = order[k];
        var p = placed[idx];
        if (p > cursor) p = cursor;
        placed[idx] = p;
        cursor = p - minGap;
      }
    }
    return placed;
  }

  /// Returns the indices to *keep* so that drawn label boxes — each centered at
  /// `centers[i]` with width `widths[i]` — do not overlap, leaving at least
  /// [minGap] between neighboring boxes. Greedy left-to-right; the first label
  /// in position order is always kept.
  ///
  /// Use for axis tick labels: a measured replacement for fixed stride-thinning
  /// that adapts to actual label widths instead of guessing a step.
  static List<int> thin(
    List<double> centers,
    List<double> widths,
    double minGap,
  ) {
    final n = centers.length;
    if (n == 0) return const [];

    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => centers[a].compareTo(centers[b]));
    final keep = <int>[];
    var lastRight = double.negativeInfinity;
    for (final idx in order) {
      final left = centers[idx] - widths[idx] / 2;
      final right = centers[idx] + widths[idx] / 2;
      if (left >= lastRight + minGap) {
        keep.add(idx);
        lastRight = right;
      }
    }
    keep.sort();
    return keep;
  }
}
