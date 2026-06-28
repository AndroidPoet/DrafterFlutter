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
import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// A single bullet-chart metric: a featured [value], a [target] to beat, and a
/// set of qualitative [ranges] (band end-values) drawn as the backdrop.
@immutable
class BulletMetric {
  /// Creates a bullet metric; [color] defaults to the palette indigo accent.
  const BulletMetric({
    required this.label,
    required this.value,
    required this.target,
    required this.ranges,
    Color? color,
    // Equals DrafterColors.indigo; inlined as a const so this stays a const ctor.
  }) : color = color ?? const Color(0xFF5B6BF0);

  /// Name of the metric, shown in the left gutter.
  final String label;

  /// Featured measure drawn as the animated bar.
  final double value;

  /// Comparative target drawn as the vertical tick.
  final double target;

  /// Qualitative band end-values forming the backdrop ranges.
  final List<double> ranges;

  /// Color of the measure bar.
  final Color color;
}

/// Draws bullet-chart metrics into a canvas.
class BulletChartRenderer extends ChartRenderer implements InteractiveRenderer {
  /// Creates a renderer for the given [metrics].
  const BulletChartRenderer({required this.metrics});

  /// Metrics drawn as stacked KPI tracks, one row each.
  final List<BulletMetric> metrics;

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (metrics.isEmpty) return;

    // Match the Compose host layout: an 80% plot inset on every side.
    final chartLeft = size.width * 0.1;
    final chartTop = size.height * 0.1;
    final chartWidth = size.width * 0.8;
    final chartHeight = size.height * 0.8;

    final bandBase = theme.isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final markerColor = theme.isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    final count = metrics.length;
    final rowSlot = chartHeight / count;
    final rowHeight = rowSlot * 0.55;

    // Left gutter for labels: ~28% of width.
    final gutter = chartWidth * 0.28;
    final trackLeft = chartLeft + gutter;
    final trackWidth = chartWidth - gutter;

    final p = progress.clamp(0.0, 1.0);

    for (var index = 0; index < count; index++) {
      final metric = metrics[index];
      final rowTop = chartTop + rowSlot * index + (rowSlot - rowHeight) / 2;
      final rowCenterY = rowTop + rowHeight / 2;

      final value = drafterFinite(metric.value);
      final target = drafterFinite(metric.target);
      final sortedRanges = [for (final r in metric.ranges) drafterFinite(r)]
        ..sort();
      final rangesMax = sortedRanges.isEmpty
          ? 0.0
          : sortedRanges.reduce((a, b) => a > b ? a : b);
      final rawMax = [
        rangesMax,
        value,
        target,
      ].reduce((a, b) => a > b ? a : b);
      final maxValue = (!rawMax.isFinite || rawMax <= 0) ? 1.0 : rawMax;

      // Qualitative range bands, increasingly darker translucent tint.
      for (var rIndex = 0; rIndex < sortedRanges.length; rIndex++) {
        final rangeEnd = sortedRanges[rIndex];
        final start = rIndex == 0 ? 0.0 : sortedRanges[rIndex - 1];
        final x0 = trackLeft + (start / maxValue) * trackWidth;
        final x1 = trackLeft + (rangeEnd / maxValue) * trackWidth;
        final alpha = 0.06 + 0.07 * rIndex;
        final bandRect = Rect.fromLTWH(
          x0,
          rowTop,
          (x1 - x0) < 0 ? 0.0 : (x1 - x0),
          rowHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bandRect, const Radius.circular(4)),
          Paint()..color = bandBase.withValues(alpha: alpha),
        );
      }

      // Measure bar = value: thinner, rounded, animated width.
      final measureHeight = rowHeight * 0.42;
      final measureTop = rowCenterY - measureHeight / 2;
      final measureFullWidth = (value / maxValue) * trackWidth;
      final measureWidth = (measureFullWidth * p) < 0
          ? 0.0
          : (measureFullWidth * p);
      final measureRect = Rect.fromLTWH(
        trackLeft,
        measureTop,
        measureWidth,
        measureHeight,
      );
      final measureCorner = measureHeight / 2;
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(measureRect, Radius.circular(measureCorner)),
          Paint()..color = metric.color.withValues(alpha: 0.2),
        )
        ..drawRRect(
          RRect.fromRectAndRadius(measureRect, Radius.circular(measureCorner)),
          Paint()..color = metric.color,
        );

      // Vertical target tick.
      final targetX = trackLeft + (target / maxValue) * trackWidth;
      canvas.drawLine(
        Offset(targetX, rowTop - 2),
        Offset(targetX, rowTop + rowHeight + 2),
        Paint()
          ..color = markerColor
          ..strokeWidth = 3,
      );

      // Label on the left of the row, truncated to fit the gutter.
      final labelString = metric.label.length > 8
          ? '${metric.label.substring(0, 7)}…'
          : metric.label;
      drawChartText(
        canvas,
        labelString,
        Offset(chartLeft, rowCenterY),
        color: theme.label,
        v: VAlign.center,
      );

      // Value at the end of the row, above the track.
      final valueString = ChartFormatting.format(metric.value);
      drawChartText(
        canvas,
        valueString,
        Offset(chartLeft + chartWidth, rowTop - 1),
        color: metric.color,
        h: HAlign.end,
        v: VAlign.bottom,
      );
    }
  }

  @override
  ChartScene buildScene(Size size) {
    if (metrics.isEmpty) return ChartScene.empty;

    // Mirror draw()'s layout exactly, at full reveal (progress = 1).
    final chartLeft = size.width * 0.1;
    final chartTop = size.height * 0.1;
    final chartWidth = size.width * 0.8;
    final chartHeight = size.height * 0.8;

    final count = metrics.length;
    final rowSlot = chartHeight / count;
    final rowHeight = rowSlot * 0.55;

    final gutter = chartWidth * 0.28;
    final trackLeft = chartLeft + gutter;
    final trackWidth = chartWidth - gutter;

    final marks = <PlotMark>[];
    for (var index = 0; index < count; index++) {
      final metric = metrics[index];
      final rowTop = chartTop + rowSlot * index + (rowSlot - rowHeight) / 2;
      final rowCenterY = rowTop + rowHeight / 2;

      final value = drafterFinite(metric.value);
      final target = drafterFinite(metric.target);
      final sortedRanges = [for (final r in metric.ranges) drafterFinite(r)]
        ..sort();
      final rangesMax = sortedRanges.isEmpty
          ? 0.0
          : sortedRanges.reduce((a, b) => a > b ? a : b);
      final rawMax = [
        rangesMax,
        value,
        target,
      ].reduce((a, b) => a > b ? a : b);
      final maxValue = (!rawMax.isFinite || rawMax <= 0) ? 1.0 : rawMax;

      // Focal point: the measure-bar tip at full reveal.
      final measureFullWidth = (value / maxValue) * trackWidth;
      final center = Offset(trackLeft + measureFullWidth, rowCenterY);

      // Region: the entire row slot, so a tap anywhere on the row selects it.
      final region = Rect.fromLTWH(
        chartLeft,
        chartTop + rowSlot * index,
        chartWidth,
        rowSlot,
      );

      marks.add(
        PlotMark(
          index: index,
          seriesIndex: 0,
          seriesName: '',
          label: metric.label,
          value: metric.value,
          center: center,
          color: metric.color,
          region: region,
        ),
      );
    }

    return ChartScene(
      bounds: ChartBounds(size, padding: 0),
      marks: marks,
    );
  }

  @override
  String get accessibilityLabel => 'Bullet chart';

  @override
  String get accessibilityValue => metrics.isEmpty
      ? 'No data'
      : metrics
            .map(
              (m) =>
                  '${m.label} ${AccessibilityFormat.number(m.value)} of target ${AccessibilityFormat.number(m.target)}',
            )
            .join('; ');
}

/// A bullet chart: stacked KPI tracks with qualitative range bands, an animated
/// value bar, and a target marker per metric.
class BulletChart extends StatelessWidget {
  /// Creates a bullet chart for the given [metrics].
  const BulletChart({
    super.key,
    required this.metrics,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  /// Metrics to render as stacked KPI tracks.
  final List<BulletMetric> metrics;

  /// Whether to play the reveal animation on first build.
  final bool animate;

  /// Bump this counter to replay the reveal animation.
  final int replay;

  /// Duration of the reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: BulletChartRenderer(metrics: metrics),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}
