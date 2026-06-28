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
import 'dart:ui' as ui;

import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

double _radians(double degrees) => degrees * math.pi / 180;

double _clamp(double v, double lo, double hi) => math.min(math.max(v, lo), hi);

double _clamp01(double v) => _clamp(v, 0, 1);

/// Draws a gauge into a canvas: static track arc + animated value arc.
/// Holds a `value` within `[min, max]`, an optional `label`, and the accent
/// `color` used for the knob ring.
class GaugeChartRenderer extends ChartRenderer implements InteractiveRenderer {
  /// Creates a gauge renderer for [value] within `[min, max]`.
  GaugeChartRenderer({
    required this.value,
    this.min = 0,
    this.max = 100,
    this.label = '',
    Color? color,
  }) : color = color ?? DrafterColors.teal;

  /// Current value plotted on the gauge.
  final double value;

  /// Minimum of the value range (arc start).
  final double min;

  /// Maximum of the value range (arc end).
  final double max;

  /// Optional caption shown under the center value.
  final String label;

  /// Accent color used for the tip knob ring.
  final Color color;

  // Compose arc geometry: 0 deg = +x, clockwise (y down). 240 deg sweep starting at 150.
  static const double _startAngleDeg = 150;
  static const double _sweepAngleDeg = 240;

  @override
  ChartScene buildScene(Size size) {
    final layout = RadialLayout(size, scale: 0.82);
    final center = layout.center;
    final radius = layout.radius;
    if (radius <= 0) return ChartScene.empty;

    final strokeWidth = radius * 0.16;
    final arcRadius = radius - strokeWidth / 2;

    // Value fraction clamped to [0, 1] at full reveal (progress = 1).
    // A non-finite value collapses to the minimum so the tip stays finite.
    final span = (max - min) == 0 ? 1.0 : (max - min);
    final fraction = value.isFinite ? _clamp01((value - min) / span) : 0.0;
    final valueSweep = _sweepAngleDeg * fraction;

    // Needle tip at the end of the value arc.
    final tipAngle = _radians(_startAngleDeg + valueSweep);
    final tip = layout.pointAt(angle: tipAngle, distance: arcRadius);

    return ChartScene(
      bounds: ChartBounds(size, padding: 0),
      categories: label.isEmpty ? const [] : [label],
      marks: [
        PlotMark(
          index: 0,
          seriesIndex: 0,
          seriesName: '',
          label: label,
          value: value,
          center: tip,
          color: color,
          // The whole gauge owns the single value so hovering anywhere on it
          // shows the value tooltip.
          region: Rect.fromCircle(center: center, radius: radius),
        ),
      ],
    );
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    final layout = RadialLayout(size, scale: 0.82);
    final center = layout.center;
    final radius = layout.radius;
    if (radius <= 0) return;

    final strokeWidth = radius * 0.16;
    final arcRadius = radius - strokeWidth / 2;
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);

    // Background track arc.
    canvas.drawArc(
      arcRect,
      _radians(_startAngleDeg),
      _radians(_sweepAngleDeg),
      false,
      Paint()
        ..color = theme.grid
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Value fraction clamped to [0, 1], scaled by the reveal progress.
    // A non-finite value collapses to the minimum so the knob tip stays finite.
    final span = (max - min) == 0 ? 1.0 : (max - min);
    final rawFraction = value.isFinite ? _clamp01((value - min) / span) : 0.0;
    final fraction = rawFraction * _clamp01(progress);
    final valueSweep = _sweepAngleDeg * fraction;

    if (valueSweep > 0) {
      // Sweep gradient across the full palette for a premium multi-tone arc.
      final palette = [
        ...DrafterColors.palette,
        if (DrafterColors.palette.isNotEmpty)
          DrafterColors.palette.first
        else
          color,
      ];
      final shader = ui.Gradient.sweep(
        center,
        palette,
        [for (var i = 0; i < palette.length; i++) i / (palette.length - 1)],
      );
      canvas.drawArc(
        arcRect,
        _radians(_startAngleDeg),
        _radians(valueSweep),
        false,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Knob at the tip of the value arc (white fill + colored ring).
    final tipAngle = _radians(_startAngleDeg + valueSweep);
    final tip = layout.pointAt(angle: tipAngle, distance: arcRadius);
    final knobRadius = strokeWidth * 0.42;
    canvas
      ..drawCircle(
        tip,
        knobRadius,
        Paint()..color = const Color(0xFFFFFFFF),
      )
      ..drawCircle(
        tip,
        knobRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

    // Center value (big) + optional label below it, vertically centered as a block.
    final valueText = _format(value);
    final valueFontSize = _clamp(radius * 0.04, 20, 44);
    final valueColor = theme.isDark
        ? const Color(0xFFFFFFFF)
        : drafterHex(0x1B1E25);
    final labelColor = theme.isDark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.72)
        : drafterHex(0x1B1E25).withValues(alpha: 0.6);

    final valuePainter = _layoutText(valueText, valueColor, valueFontSize);
    final valueMeasured = Size(valuePainter.width, valuePainter.height);

    final hasLabel = label.isNotEmpty;
    var labelMeasured = Size.zero;
    TextPainter? labelPainter;
    if (hasLabel) {
      labelPainter = _layoutText(label, labelColor, 13);
      labelMeasured = Size(labelPainter.width, labelPainter.height);
    }

    const gap = 6.0;
    final totalH =
        valueMeasured.height + (hasLabel ? labelMeasured.height + gap : 0);
    final blockTop = center.dy - totalH / 2;

    _paintCentered(
      canvas,
      valuePainter,
      Offset(center.dx, blockTop + valueMeasured.height / 2),
    );
    if (labelPainter != null) {
      _paintCentered(
        canvas,
        labelPainter,
        Offset(
          center.dx,
          blockTop + valueMeasured.height + gap + labelMeasured.height / 2,
        ),
      );
    }

    // Min / max end labels just outside the arc ends.
    _drawEndLabel(
      canvas,
      _format(min),
      _startAngleDeg,
      center,
      arcRadius,
      strokeWidth,
      theme.label,
    );
    _drawEndLabel(
      canvas,
      _format(max),
      _startAngleDeg + _sweepAngleDeg,
      center,
      arcRadius,
      strokeWidth,
      theme.label,
    );
  }

  @override
  String get accessibilityLabel => 'Gauge';

  @override
  String get accessibilityValue =>
      '${label.isEmpty ? 'value' : label} ${AccessibilityFormat.number(value)} '
      'of ${AccessibilityFormat.number(min)} to ${AccessibilityFormat.number(max)}';

  void _drawEndLabel(
    Canvas canvas,
    String text,
    double angleDeg,
    Offset center,
    double arcRadius,
    double strokeWidth,
    Color color,
  ) {
    final rad = _radians(angleDeg);
    final r = arcRadius + strokeWidth * 0.9;
    final p = Offset(
      center.dx + r * math.cos(rad),
      center.dy + r * math.sin(rad),
    );
    drawChartText(
      canvas,
      text,
      p,
      color: color,
      fontSize: 11,
      h: HAlign.center,
      v: VAlign.center,
    );
  }

  TextPainter _layoutText(String text, Color color, double fontSize) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _paintCentered(Canvas canvas, TextPainter painter, Offset center) {
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  String _format(double value) => ChartFormatting.format(value, decimals: 2);
}

/// A radial gauge with a static track, an animated value arc, a tip knob, and
/// a centered value/label.
class GaugeChart extends StatelessWidget {
  /// Creates a gauge chart for [value] within `[min, max]`.
  const GaugeChart({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.label = '',
    this.color,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  /// Current value plotted on the gauge.
  final double value;

  /// Minimum of the value range (arc start).
  final double min;

  /// Maximum of the value range (arc end).
  final double max;

  /// Optional caption shown under the center value.
  final String label;

  /// Accent color used for the tip knob ring; defaults to the theme accent.
  final Color? color;

  /// Whether to play the reveal animation on first build.
  final bool animate;

  /// Bump this counter to replay the reveal animation.
  final int replay;

  /// Duration of the reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: GaugeChartRenderer(
      value: value,
      min: min,
      max: max,
      label: label,
      color: color,
    ),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}
