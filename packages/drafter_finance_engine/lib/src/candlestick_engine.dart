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

import 'chart_color.dart';
import 'geometry.dart';
import 'indicators.dart';
import 'linear_scale.dart';
import 'candle.dart';
import 'scene.dart';

/// The inclusive range of candle indices currently visible (pan/zoom state).
class CandleWindow {
  const CandleWindow(this.firstIndex, this.lastIndex);

  final int firstIndex;
  final int lastIndex;

  int get count => lastIndex - firstIndex + 1;
}

/// A moving-average overlay request.
class MaConfig {
  const MaConfig(this.period, this.color);

  final int period;
  final ChartColor color;
}

/// Visual configuration for the candlestick scene.
class CandleStyle {
  const CandleStyle({
    required this.up,
    required this.down,
    this.wickWidth = 1.5,
    this.bodyWidthRatio = 0.7,
    this.movingAverages = const [],
  });

  final ChartColor up;
  final ChartColor down;
  final double wickWidth;
  final double bodyWidthRatio;
  final List<MaConfig> movingAverages;

  CandleStyle copyWith({
    ChartColor? up,
    ChartColor? down,
    double? wickWidth,
    double? bodyWidthRatio,
    List<MaConfig>? movingAverages,
  }) =>
      CandleStyle(
        up: up ?? this.up,
        down: down ?? this.down,
        wickWidth: wickWidth ?? this.wickWidth,
        bodyWidthRatio: bodyWidthRatio ?? this.bodyWidthRatio,
        movingAverages: movingAverages ?? this.movingAverages,
      );
}

/// Turns candles + a visible [CandleWindow] + a plot [FRect] into a flat display
/// list. Contains all the geometry/scaling math; the renderer just draws what it
/// returns. Pure and deterministic — identical inputs always yield an identical
/// [Scene], which is what the golden fixtures assert.
class CandlestickEngine {
  const CandlestickEngine._();

  static Scene build(
    List<Candle> candles,
    CandleWindow window,
    FRect plot,
    CandleStyle style,
  ) {
    final commands = <DrawCommand>[];
    if (candles.isEmpty || window.count <= 0) return Scene(commands, plot);

    final lastIdx = candles.length - 1;
    final first = window.firstIndex.clamp(0, lastIdx);
    final last = window.lastIndex.clamp(first, lastIdx);
    final visible = candles.sublist(first, last + 1);

    var minLow = double.maxFinite;
    var maxHigh = -double.maxFinite;
    for (final c in visible) {
      if (c.low < minLow) minLow = c.low;
      if (c.high > maxHigh) maxHigh = c.high;
    }
    // Max price -> top (smaller y); min price -> bottom.
    final priceScale = LinearScale(
      domainMin: minLow,
      domainMax: maxHigh,
      rangeStart: plot.bottom,
      rangeEnd: plot.top,
    );

    final n = visible.length;
    final slot = plot.width / n;
    final bodyWidth = math.max(slot * style.bodyWidthRatio, 1.0);

    double centerX(int i) => plot.left + slot * i + slot / 2;

    for (var i = 0; i < visible.length; i++) {
      final candle = visible[i];
      final cx = centerX(i);
      final up = candle.close >= candle.open;
      final color = up ? style.up : style.down;

      // Wick.
      commands.add(
        LineCmd(
          x1: cx,
          y1: priceScale.toPixel(candle.high),
          x2: cx,
          y2: priceScale.toPixel(candle.low),
          color: color,
          strokeWidth: style.wickWidth,
        ),
      );

      // Body (open <-> close), with a 1px floor so doji candles stay visible.
      final topY = priceScale.toPixel(math.max(candle.open, candle.close));
      final bottomY = priceScale.toPixel(math.min(candle.open, candle.close));
      commands.add(
        RectCmd(
          rect: FRect(
            left: cx - bodyWidth / 2,
            top: topY,
            right: cx + bodyWidth / 2,
            bottom: math.max(bottomY, topY + 1),
          ),
          color: color,
          fill: true,
          cornerRadius: math.min(bodyWidth * 0.22, 3.0),
        ),
      );
    }

    // Moving-average overlays on the close price.
    if (style.movingAverages.isNotEmpty) {
      final closes = [for (final c in visible) c.close];
      for (final ma in style.movingAverages) {
        final series = Indicators.sma(closes, ma.period);
        final points = <FPoint>[];
        for (var i = 0; i < series.length; i++) {
          final value = series[i];
          if (value != null) {
            points.add(FPoint(centerX(i), priceScale.toPixel(value)));
          }
        }
        if (points.length >= 2) {
          commands.add(
            PolylineCmd(
              points: points,
              color: ma.color,
              strokeWidth: 2,
              smooth: true,
            ),
          );
        }
      }
    }

    return Scene(commands, plot);
  }
}
