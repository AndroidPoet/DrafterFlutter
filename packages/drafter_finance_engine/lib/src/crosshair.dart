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
import 'candlestick_engine.dart';
import 'geometry.dart';
import 'candle.dart';

/// The candle a crosshair has snapped to, plus the x where its line should draw.
class CrosshairResult {
  const CrosshairResult({
    required this.index,
    required this.snappedX,
    required this.candle,
  });

  final int index;
  final double snappedX;
  final Candle candle;
}

/// Resolves a pointer x-position to the nearest candle (magnet mode). Pure hit
/// testing — the same math each renderer feeds its native pointer events into.
class Crosshair {
  const Crosshair._();

  static CrosshairResult? resolve(
    double pointerX,
    List<Candle> candles,
    CandleWindow window,
    FRect plot,
  ) {
    if (candles.isEmpty || window.count <= 0) return null;
    final lastIdx = candles.length - 1;
    final first = window.firstIndex.clamp(0, lastIdx);
    final last = window.lastIndex.clamp(first, lastIdx);
    final n = last - first + 1;
    final slot = plot.width / n;
    if (slot <= 0) return null;
    final rel = ((pointerX - plot.left) / slot).toInt().clamp(0, n - 1);
    final index = first + rel;
    final snappedX = plot.left + slot * rel + slot / 2;
    return CrosshairResult(
      index: index,
      snappedX: snappedX,
      candle: candles[index],
    );
  }
}
