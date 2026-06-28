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

import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// One candle: a label plus the open/high/low/close prices.
@immutable
class Candle {
  /// Creates a candle with the given [label] and open/high/low/close prices.
  const Candle({
    required this.label,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  /// The candle's x-axis label (e.g. a date or period).
  final String label;

  /// The opening price.
  final double open;

  /// The highest price in the period.
  final double high;

  /// The lowest price in the period.
  final double low;

  /// The closing price.
  final double close;
}

/// A simple moving-average overlay (the classic MA5 / MA10 / MA20 study):
/// the trailing average of closing prices over [period] candles, drawn as a
/// smooth line in [color].
@immutable
class MovingAverage {
  /// Creates a moving-average overlay averaging over [period] candles, drawn
  /// in [color].
  const MovingAverage({required this.period, required this.color});

  /// The number of trailing candles averaged at each point.
  final int period;

  /// The line color for this overlay.
  final Color color;
}

/// Draws a candlestick chart into a canvas.
class CandlestickChartRenderer extends ChartRenderer
    implements InteractiveRenderer {
  /// Creates a candlestick renderer for [candles] with optional
  /// [movingAverages] overlays.
  CandlestickChartRenderer({
    required this.candles,
    this.movingAverages = const [],
  });

  /// The candles to draw, left to right.
  final List<Candle> candles;

  /// The moving-average overlays to draw on top of the candles.
  final List<MovingAverage> movingAverages;

  // Memoized trailing-average values per moving-average line. The O(period×count)
  // averaging is size-independent (the renderer is immutable), so it's computed
  // once and only the cheap O(n) pixel mapping runs per animation frame — instead
  // of re-summing the windows ~60×/second during the reveal.
  List<({int startIndex, List<double> averages})>? _maAverages;

  @override
  ChartScene buildScene(Size size) {
    if (candles.isEmpty) return ChartScene.empty;
    final chartLeft = math.max(size.width * 0.1, 34.0);
    final chartTop = size.height * 0.1;
    final chartWidth = size.width * 0.9 - chartLeft;
    final chartHeight = size.height * 0.8;
    final chartBottom = chartTop + chartHeight;
    // Reduce over finite OHLC only so a non-finite low/high can't poison the
    // extent; fall back to 0 when an entire side is non-finite.
    final lows = candles
        .map((c) => drafterFiniteOrNull(c.low))
        .whereType<double>();
    final highs = candles
        .map((c) => drafterFiniteOrNull(c.high))
        .whereType<double>();
    final minLow = lows.isEmpty ? 0.0 : lows.reduce(math.min);
    final maxHigh = highs.isEmpty ? 0.0 : highs.reduce(math.max);
    final range = math.max(maxHigh - minLow, 0.0001);
    // Coerce every value through drafterFinite before mapping it to pixels.
    double yFor(double v) =>
        chartBottom - (drafterFinite(v) - minLow) / range * chartHeight;
    final slot = chartWidth / candles.length;

    final bounds = ChartBounds.insets(
      size,
      left: chartLeft,
      top: chartTop,
      right: size.width - (chartLeft + chartWidth),
      bottom: size.height - chartBottom,
    );
    // Each candle owns its full slot column as the hit region; the close price
    // is the focal value (OHCL-rich tooltips are a later enhancement).
    return ChartScene(
      bounds: bounds,
      categories: [for (final c in candles) c.label],
      marks: [
        for (var i = 0; i < candles.length; i++)
          PlotMark(
            index: i,
            seriesIndex: 0,
            seriesName: '',
            label: candles[i].label,
            value: candles[i].close,
            center: Offset(
              chartLeft + slot * i + slot / 2,
              yFor(candles[i].close),
            ),
            color: candles[i].close >= candles[i].open
                ? DrafterColors.green
                : DrafterColors.coral,
            region: Rect.fromLTRB(
              chartLeft + slot * i,
              chartTop,
              chartLeft + slot * (i + 1),
              chartBottom,
            ),
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
    if (candles.isEmpty) return;

    // Plot rect: ~10% inset on every side (matches Compose 0.1 fractions), but
    // floor the left inset so Y axis price labels don't clip at small sizes.
    final chartLeft = math.max(size.width * 0.1, 34.0);
    final chartTop = size.height * 0.1;
    final chartWidth = size.width * 0.9 - chartLeft;
    final chartHeight = size.height * 0.8;
    final chartBottom = chartTop + chartHeight;

    // Reduce over finite OHLC only (ignoring non-finite lows/highs).
    final lows = candles
        .map((c) => drafterFiniteOrNull(c.low))
        .whereType<double>();
    final highs = candles
        .map((c) => drafterFiniteOrNull(c.high))
        .whereType<double>();
    final minLow = lows.isEmpty ? 0.0 : lows.reduce((a, b) => a < b ? a : b);
    final maxHigh = highs.isEmpty ? 0.0 : highs.reduce((a, b) => a > b ? a : b);
    final range = math.max(maxHigh - minLow, 0.0001);

    final p = progress.clamp(0.0, 1.0);

    // Coerce every value through drafterFinite before mapping it to pixels.
    double yFor(double value) =>
        chartBottom - (drafterFinite(value) - minLow) / range * chartHeight;
    final slot = chartWidth / candles.length;
    double centerXFor(int index) => chartLeft + slot * index + slot / 2;

    // Axes (left + bottom).
    final axisPaint = Paint()
      ..color = theme.grid
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(
        Offset(chartLeft, chartTop),
        Offset(chartLeft, chartBottom),
        axisPaint,
      )
      ..drawLine(
        Offset(chartLeft, chartBottom),
        Offset(chartLeft + chartWidth, chartBottom),
        axisPaint,
      );

    // Y gridlines + labels from min(low)..max(high).
    const ySteps = 4;
    for (var i = 0; i <= ySteps; i++) {
      final value = minLow + range * (i / ySteps);
      final y = chartBottom - (value - minLow) / range * chartHeight;
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartLeft + chartWidth, y),
        Paint()
          ..color = theme.grid
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
      drawChartText(
        canvas,
        ChartFormatting.format(value),
        Offset(chartLeft - 6, y),
        color: theme.label,
        fontSize: 10,
        h: HAlign.end,
        v: VAlign.center,
      );
    }

    final count = candles.length;
    final bodyWidth = math.max(slot * 0.6, 2.0);
    final labelEvery = math.max(1, count ~/ 8);

    for (var index = 0; index < candles.length; index++) {
      final candle = candles[index];
      final centerX = centerXFor(index);
      final isUp = candle.close >= candle.open;
      final color = isUp ? DrafterColors.green : DrafterColors.coral;

      // Body span + center, used as the animation origin.
      final bodyTopValue = math.max(candle.open, candle.close);
      final bodyBottomValue = math.min(candle.open, candle.close);
      final bodyCenterValue = (bodyTopValue + bodyBottomValue) / 2;
      final centerY = yFor(bodyCenterValue);

      // Wick (low -> high), grown from the body center.
      final highY = yFor(candle.high);
      final lowY = yFor(candle.low);
      final animHighY = centerY + (highY - centerY) * p;
      final animLowY = centerY + (lowY - centerY) * p;
      canvas.drawLine(
        Offset(centerX, animHighY),
        Offset(centerX, animLowY),
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // Body rect (open<->close), grown from the center.
      final fullTopY = yFor(bodyTopValue);
      final fullBottomY = yFor(bodyBottomValue);
      final fullBodyHeight = math.max(fullBottomY - fullTopY, 2.0);
      final animBodyHeight = fullBodyHeight * p;
      final bodyTopY = centerY - animBodyHeight / 2;

      // Soft translucent halo behind the body for a premium feel.
      final halo = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - bodyWidth / 2 - 2,
          bodyTopY - 2,
          bodyWidth + 4,
          animBodyHeight + 4,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        halo,
        Paint()..color = color.withValues(alpha: 0.18 * p),
      );

      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - bodyWidth / 2,
          bodyTopY,
          bodyWidth,
          animBodyHeight,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(body, Paint()..color = color.withValues(alpha: p));

      // Sparse X labels to avoid crowding.
      if (index % labelEvery == 0) {
        drawChartText(
          canvas,
          candle.label,
          Offset(centerX, chartBottom + 6),
          color: theme.label,
          fontSize: 10,
          h: HAlign.center,
        );
      }
    }

    // Moving-average overlays (MA5 / MA10 / MA20 ...) as smooth curves,
    // revealed left-to-right with the candles' entrance animation.
    final reveal = chartLeft + chartWidth * p;
    final maValues = _movingAverageValues();
    for (var m = 0; m < movingAverages.length; m++) {
      final points = _movingAveragePoints(maValues[m], centerXFor, yFor);
      if (points.length < 2) continue;
      canvas
        ..save()
        ..clipRect(Rect.fromLTWH(0, 0, reveal, size.height))
        ..drawPath(
          smoothPath(points),
          Paint()
            ..color = movingAverages[m].color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        )
        ..restore();
    }

    // Compact legend (MAn in each line's color), top-left inside the plot.
    var legendX = chartLeft + 4;
    for (final ma in movingAverages) {
      final label = 'MA${ma.period}';
      drawChartText(
        canvas,
        label,
        Offset(legendX, chartTop + 2),
        color: ma.color,
        fontSize: 10,
      );
      legendX += _approxTextWidth(label, 10) + 10;
    }
  }

  @override
  String get accessibilityLabel => 'Candlestick chart';

  @override
  String get accessibilityValue => candles.isEmpty
      ? 'No data'
      : '${candles.length} candles, close ${AccessibilityFormat.range([for (final c in candles) c.close])}';

  /// Computes the (size-independent) trailing averages for every moving-average
  /// line once, memoizing the result. Each entry holds the candle index the line
  /// starts at and the averaged close for each index from there on.
  List<({int startIndex, List<double> averages})> _movingAverageValues() {
    final cached = _maAverages;
    if (cached != null) return cached;
    final count = candles.length;
    final result = <({int startIndex, List<double> averages})>[];
    for (final ma in movingAverages) {
      if (ma.period <= 0 || ma.period > count) {
        result.add((startIndex: 0, averages: const []));
        continue;
      }
      final averages = <double>[];
      // Sliding window: drop the leaving close, add the entering one (O(n), not
      // O(n×period)).
      var sum = 0.0;
      for (var j = 0; j < ma.period; j++) {
        sum += candles[j].close;
      }
      averages.add(sum / ma.period);
      for (var i = ma.period; i < count; i++) {
        sum += candles[i].close - candles[i - ma.period].close;
        averages.add(sum / ma.period);
      }
      result.add((startIndex: ma.period - 1, averages: averages));
    }
    _maAverages = result;
    return result;
  }

  /// Maps a moving-average line's cached values onto pixel offsets for [draw].
  List<Offset> _movingAveragePoints(
    ({int startIndex, List<double> averages}) ma,
    double Function(int) centerXFor,
    double Function(double) yFor,
  ) {
    final averages = ma.averages;
    if (averages.length < 2) return const [];
    return [
      for (var k = 0; k < averages.length; k++)
        Offset(centerXFor(ma.startIndex + k), yFor(averages[k])),
    ];
  }
}

/// Rough advance width for legend layout (no text metrics in the pure canvas path).
double _approxTextWidth(String text, double fontSize) =>
    text.length * fontSize * 0.62;

/// A candlestick (K-line) chart with high-low wicks, open-close bodies, and
/// optional moving-average overlays, with an animated entrance.
class CandlestickChart extends StatelessWidget {
  /// Creates a candlestick chart from [candles] with optional [movingAverages].
  const CandlestickChart({
    super.key,
    required this.candles,
    this.movingAverages = const [],
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  /// The candles to draw, left to right.
  final List<Candle> candles;

  /// The moving-average overlays to draw on top of the candles.
  final List<MovingAverage> movingAverages;

  /// Whether the candles animate in on first reveal.
  final bool animate;

  /// Bump this to replay the reveal animation.
  final int replay;

  /// How long the reveal animation runs.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: CandlestickChartRenderer(
      candles: candles,
      movingAverages: movingAverages,
    ),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}
