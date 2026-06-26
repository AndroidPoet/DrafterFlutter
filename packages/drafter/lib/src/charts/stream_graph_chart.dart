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
import 'dart:ui' as ui;

import 'package:drafter/src/core/chart_data.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// Renders `[ChartSeries]` as a themeriver: each series flows as a smooth band,
/// the stack centred symmetrically around the chart midline. Each band uses its
/// series' own `color`, so a colour can never desync from its data. [categories]
/// supplies the optional x-axis labels.
class StreamGraphChartRenderer extends ChartRenderer {
  const StreamGraphChartRenderer({
    required this.series,
    this.categories = const [],
  });

  final List<ChartSeries> series;
  final List<String> categories;

  /// Number of x points shared by every series. Driven by the series' own value
  /// arrays — the common minimum length across all series so the stack only
  /// samples indices that every series actually has — never by `categories.length`.
  /// Ragged or over-long category arrays can't introduce phantom samples this way.
  int get _pointCount {
    if (series.isEmpty) return 0;
    return series.map((s) => s.values.length).reduce((a, b) => a < b ? a : b);
  }

  /// The largest total stacked value across all x points (drives the y scale).
  double _maxTotal(int count) {
    var maxV = 0.0;
    for (var i = 0; i < count; i++) {
      var total = 0.0;
      for (final s in series) {
        total += _valueAt(s, i);
      }
      if (total > maxV) maxV = total;
    }
    return maxV;
  }

  double _valueAt(ChartSeries s, int index) =>
      index >= 0 && index < s.values.length ? s.values[index] : 0.0;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final count = _pointCount;
    if (count < 2 || series.isEmpty) return;

    final p = progress.clamp(0.0, 1.0);

    // 8% horizontal inset; small vertical inset to keep labels readable.
    final chartLeft = size.width * 0.08;
    final chartWidth = size.width * 0.84;
    final chartTop = size.height * 0.06;
    final chartHeight = size.height * 0.84;

    final centerY = chartTop + chartHeight / 2;
    final maxTotal = _maxTotal(count);
    if (maxTotal <= 0) return;

    // Fit the tallest total stack into ~80% of the available height.
    final yScale = (chartHeight * 0.8) / maxTotal;
    final stepX = count > 1 ? chartWidth / (count - 1) : chartWidth;
    final xs = <double>[for (var i = 0; i < count; i++) chartLeft + i * stepX];

    // Per-series thickness (in pixels, pre-progress) at each x.
    final thickness = <List<double>>[
      for (final s in series)
        [for (var i = 0; i < count; i++) _valueAt(s, i) * yScale],
    ];

    // Centred baseline (top edge of the whole stack) at each x. Scale the
    // half-height by progress so the stack grows outward from the centre
    // baseline rather than dropping in from a fixed top edge. Mirrors the
    // Compose renderer exactly (a symmetric, centred stack — not a wiggle).
    final stackTop = List<double>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      var total = 0.0;
      for (final layer in thickness) {
        total += layer[i];
      }
      final halfHeight = (total * p) / 2;
      stackTop[i] = centerY - halfHeight;
    }

    // Running cumulative top per x; each series stacks below the previous one.
    final runningTop = List<double>.of(stackTop);
    for (var idx = 0; idx < series.length; idx++) {
      final s = series[idx];
      final layer = thickness[idx];
      final topEdge = <Offset>[];
      final bottomEdge = <Offset>[];

      for (var i = 0; i < count; i++) {
        final h = layer[i] * p;
        final top = runningTop[i];
        final bottom = top + h;
        topEdge.add(Offset(xs[i], top));
        bottomEdge.add(Offset(xs[i], bottom));
        runningTop[i] = bottom;
      }

      _drawBand(
        canvas,
        topEdge: topEdge,
        bottomEdge: bottomEdge,
        color: s.color,
      );
    }

    _drawXLabels(
      canvas,
      theme: theme,
      xs: xs,
      baseline: chartTop + chartHeight,
    );
  }

  @override
  String get accessibilityLabel => 'Stream graph';

  @override
  String get accessibilityValue => series.isEmpty
      ? 'No data'
      : '${series.length} series: ${series.map((s) => '${s.name.isEmpty ? 'series' : s.name} ${AccessibilityFormat.range(s.values)}').join('; ')}';

  // ---------------------------------------------------------------------------
  // Bands
  // ---------------------------------------------------------------------------

  /// Builds a closed band from a smooth top edge and a smooth bottom edge, fills
  /// it with a soft vertical gradient, then strokes a thin lighter top edge for
  /// separation between stacked bands.
  void _drawBand(
    Canvas canvas, {
    required List<Offset> topEdge,
    required List<Offset> bottomEdge,
    required Color color,
  }) {
    if (topEdge.length < 2) return;

    final topPath = smoothPath(topEdge);

    // Closed band: reuse the already-computed top spline, then smooth the
    // bottom edge R->L and close (avoids computing smoothPath twice).
    final band = Path.from(topPath);
    _appendSmoothInto(band, bottomEdge.reversed.toList());
    band.close();

    var minY = double.infinity;
    for (final pt in topEdge) {
      if (pt.dy < minY) minY = pt.dy;
    }
    var maxY = double.negativeInfinity;
    for (final pt in bottomEdge) {
      if (pt.dy > maxY) maxY = pt.dy;
    }

    // Opaque-ish base so the band reads solid over busy backgrounds, then a
    // soft top->bottom gradient on top (mirrors the Compose renderer).
    canvas
      ..drawPath(band, Paint()..color = color.withValues(alpha: 0.85))
      ..drawPath(
        band,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, minY),
            Offset(0, maxY),
            [color.withValues(alpha: 0.92), color.withValues(alpha: 0.78)],
          ),
      )
      // Thin lighter stroke along the top edge for separation between bands.
      ..drawPath(
        topPath,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  /// Appends a Catmull-Rom smooth curve through [points] into [path], continuing
  /// the existing subpath (lines to the first point, then cubic segments through
  /// the rest). Mirrors `smoothPath` but without starting a new subpath.
  void _appendSmoothInto(Path path, List<Offset> points) {
    if (points.isEmpty) return;
    final first = points.first;
    path.lineTo(first.dx, first.dy);
    if (points.length < 3) {
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      return;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i - 1 < 0 ? i : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 > points.length - 1 ? i + 1 : i + 2];
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6.0,
        p1.dy + (p2.dy - p0.dy) / 6.0,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6.0,
        p2.dy - (p3.dy - p1.dy) / 6.0,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
  }

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  /// Draws a sparse set of x labels (at most 6) along the bottom of the chart.
  /// Reads from [categories], only drawing a label when the index exists in both
  /// the category array and the mapped x positions.
  void _drawXLabels(
    Canvas canvas, {
    required DrafterThemeColors theme,
    required List<double> xs,
    required double baseline,
  }) {
    if (categories.isEmpty) return;
    const maxLabels = 6;
    final labelCount = categories.length;
    final stride = ((labelCount + maxLabels - 1) ~/ maxLabels).clamp(
      1,
      1 << 30,
    );

    var i = 0;
    while (i < labelCount) {
      if (i >= xs.length) break;
      drawChartText(
        canvas,
        categories[i],
        Offset(xs[i], baseline + 6 + 6),
        color: theme.label,
        fontSize: 10,
        h: HAlign.center,
        v: VAlign.center,
      );
      i += stride;
    }
  }
}

/// A stream graph (themeriver): stacked series that flow as smooth bands centred
/// around the chart midline, growing symmetrically outward from the centre as
/// they animate in. Each band's colour is bound to its `ChartSeries`; [categories]
/// supplies the optional x-axis labels.
class StreamGraphChart extends StatelessWidget {
  const StreamGraphChart({
    super.key,
    required this.series,
    this.categories = const [],
    this.animate = true,
    this.replay = 0,
  });

  final List<ChartSeries> series;
  final List<String> categories;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: StreamGraphChartRenderer(series: series, categories: categories),
    animate: animate,
    duration: const Duration(milliseconds: 900),
    replay: replay,
  );
}
