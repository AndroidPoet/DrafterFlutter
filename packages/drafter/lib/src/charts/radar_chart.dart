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

import 'package:drafter/src/core/chart_data.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// Draws one or more overlaid [RadarSeries] polygons into a canvas.
///
/// Axes are taken from the first non-empty series' keys, with any extra keys
/// from later series unioned in so no series loses an axis. Each series carries
/// its own `color`, is filled at 22% and stroked at 90% opacity, both scaled by
/// reveal `progress`; vertices grow outward from the center as `progress` advances.
class RadarChartRenderer extends ChartRenderer implements InteractiveRenderer {
  /// Creates a renderer that overlays each polygon in [series].
  const RadarChartRenderer({required this.series});

  /// The series to overlay, each contributing one polygon.
  final List<RadarSeries> series;

  @override
  ChartScene buildScene(Size size) {
    // Mirror draw()'s early-returns so degenerate inputs hit-test to nothing.
    if (series.isEmpty) return ChartScene.empty;
    final axisLabels = _orderedAxisLabels(series);
    final axisCount = axisLabels.length;
    if (axisCount < 3) return ChartScene.empty;

    final layout = RadialLayout(size);
    final marks = <PlotMark>[];

    // One mark per (series, axis) vertex, at full (un-animated) radius so the
    // hit regions stay put while the entrance animation expands the polygons.
    for (var s = 0; s < series.length; s++) {
      final entry = series[s];
      for (var index = 0; index < axisCount; index++) {
        final label = axisLabels[index];
        final value = drafterFinite(entry.values[label] ?? 0);
        final angle = _axisAngle(index, axisCount);
        final vertex = layout.pointAt(
          angle: angle,
          distance: layout.radius * value,
        );
        marks.add(
          PlotMark(
            index: index,
            seriesIndex: s,
            seriesName: '',
            label: label,
            value: value,
            center: vertex,
            color: entry.color,
            region: Rect.fromCircle(center: vertex, radius: 12),
          ),
        );
      }
    }

    return ChartScene(
      bounds: ChartBounds(size, padding: 0),
      categories: axisLabels,
      marks: marks,
    );
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    // Element count is driven by `series`; axes are derived defensively so series
    // with differing (or empty) key sets can never crash or drop the whole chart.
    if (series.isEmpty) return;
    final axisLabels = _orderedAxisLabels(series);
    final axisCount = axisLabels.length;
    if (axisCount < 3) return;

    final layout = RadialLayout(size);

    _drawGridAndAxes(canvas, layout, axisLabels, theme);

    for (final entry in series) {
      _drawDataPolygon(
        canvas,
        layout,
        axisLabels,
        entry,
        entry.color,
        progress,
      );
    }
  }

  @override
  String get accessibilityLabel => 'Radar chart';

  @override
  String get accessibilityValue {
    if (series.isEmpty) return 'No data';
    final axisCount = _orderedAxisLabels(series).length;
    return '${series.length} series over $axisCount axes';
  }

  // Concentric grid rings (5), one axis line per dimension, and axis labels.
  void _drawGridAndAxes(
    Canvas canvas,
    RadialLayout layout,
    List<String> axisLabels,
    DrafterThemeColors theme,
  ) {
    final center = layout.center;
    final radius = layout.radius;
    final axisCount = axisLabels.length;

    final gridPaint = Paint()
      ..color = theme.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Concentric rings.
    for (var ring = 1; ring <= 5; ring++) {
      final r = radius * ring / 5;
      canvas.drawCircle(center, r, gridPaint);
    }

    // Axes + labels.
    for (var i = 0; i < axisCount; i++) {
      final angle = _axisAngle(i, axisCount);
      final end = layout.pointAt(angle: angle, distance: radius);

      canvas.drawLine(center, end, gridPaint);

      final labelPoint = layout.pointAt(angle: angle, distance: radius * 1.1);
      drawChartText(
        canvas,
        axisLabels[i],
        labelPoint,
        color: theme.label,
        fontSize: 12,
        h: HAlign.center,
        v: VAlign.center,
      );
    }
  }

  // Filled + stroked polygon for one series, vertices scaled by progress.
  void _drawDataPolygon(
    Canvas canvas,
    RadialLayout layout,
    List<String> axisLabels,
    RadarSeries series,
    Color color,
    double progress,
  ) {
    final axisCount = axisLabels.length;
    final p = math.min(math.max(progress, 0), 1);

    final points = <Offset>[
      for (var index = 0; index < axisLabels.length; index++)
        () {
          final value = drafterFinite(series.values[axisLabels[index]] ?? 0);
          final angle = _axisAngle(index, axisCount);
          final distance = layout.radius * value * p;
          return layout.pointAt(angle: angle, distance: distance);
        }(),
    ];
    if (points.isEmpty) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    canvas
      ..drawPath(
        path,
        Paint()..color = color.withValues(alpha: 0.22 * progress),
      )
      ..drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.9 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );

    // Haloed vertex dots once the polygon has expanded enough.
    if (progress > 0.6) {
      for (final point in points) {
        drawVertexDot(canvas, point, color, 4);
      }
    }
  }

  // Angle for axis `index`, starting at the top (-90 deg) and stepping clockwise.
  static double _axisAngle(int index, int count) =>
      index * 2 * math.pi / count - math.pi / 2;

  // Keys in insertion order where available, otherwise sorted for stability.
  static List<String> _orderedKeys(Map<String, double> values) =>
      values.keys.toList()..sort();

  // Stable axis ordering across (possibly mismatched) series. Seeds from the
  // first non-empty series' sorted keys, then appends any extra keys from other
  // series (also sorted) so a richer series never silently loses an axis. For
  // matching input this is identical to sorting the first series' keys.
  static List<String> _orderedAxisLabels(List<RadarSeries> series) {
    RadarSeries? seed;
    for (final entry in series) {
      if (entry.values.isNotEmpty) {
        seed = entry;
        break;
      }
    }
    if (seed == null) return const [];
    final labels = _orderedKeys(seed.values);
    final seen = labels.toSet();
    for (final entry in series) {
      for (final key in _orderedKeys(entry.values)) {
        if (!seen.contains(key)) {
          labels.add(key);
          seen.add(key);
        }
      }
    }
    return labels;
  }
}

/// A multi-axis radar chart with grid rings, per-axis labels, and an animated
/// expand-from-center reveal for each overlaid series.
class RadarChart extends StatelessWidget {
  /// Creates a radar chart that overlays each polygon in [series].
  const RadarChart({
    super.key,
    required this.series,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 1000),
  });

  /// The series to overlay, each contributing one polygon.
  final List<RadarSeries> series;

  /// Whether to play the entrance reveal animation.
  final bool animate;

  /// Bump this value to replay the entrance animation.
  final int replay;

  /// Duration of the entrance reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: RadarChartRenderer(series: series),
    animate: animate,
    replay: replay,
    duration: duration,
  );
}
