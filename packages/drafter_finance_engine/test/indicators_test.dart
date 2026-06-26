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
import 'package:drafter_finance_engine/drafter_finance_engine.dart';
import 'package:test/test.dart';

/// Parity tests against the canonical golden values. The Kotlin `IndicatorsTest`
/// and Swift `IndicatorsTests` assert the IDENTICAL numbers — that's what keeps
/// the three ports in lockstep.
void main() {
  test('sma', () {
    final r = Indicators.sma([1, 2, 3, 4, 5], 3);
    expect(r.length, 5);
    expect(r[0], isNull);
    expect(r[1], isNull);
    expect(r[2]!, closeTo(2, 0.0001));
    expect(r[3]!, closeTo(3, 0.0001));
    expect(r[4]!, closeTo(4, 0.0001));
  });

  test('ema seeded with sma', () {
    final r = Indicators.ema([1, 2, 3, 4, 5], 3);
    expect(r[0], isNull);
    expect(r[1], isNull);
    // seed = avg(1,2,3) = 2; k = 0.5
    expect(r[2]!, closeTo(2, 0.0001));
    // 4*0.5 + 2*0.5 = 3
    expect(r[3]!, closeTo(3, 0.0001));
    // 5*0.5 + 3*0.5 = 4
    expect(r[4]!, closeTo(4, 0.0001));
  });

  test('rsi in range', () {
    final values = <double>[
      1, 2, 3, 4, 5, 4, 3, 4, 5, 6, 7, 6, 5, 6, 7, 8, //
    ];
    final r = Indicators.rsi(values, 14);
    expect(r.length, values.length);
    for (final v in r.whereType<double>()) {
      expect(v >= 0 && v <= 100, isTrue, reason: 'RSI out of range: $v');
    }
  });

  test('candlestick scene is deterministic', () {
    final candles = [
      const Candle(time: 0, open: 10, high: 12, low: 9, close: 11),
      const Candle(time: 1, open: 11, high: 13, low: 10, close: 10),
      const Candle(time: 2, open: 10, high: 14, low: 10, close: 13),
    ];
    final scene = CandlestickEngine.build(
      candles,
      const CandleWindow(0, 2),
      const FRect(left: 0, top: 0, right: 300, bottom: 100),
      CandleStyle(
        up: ChartColor.rgba(0, 255, 0),
        down: ChartColor.rgba(255, 0, 0),
      ),
    );
    // 3 candles -> wick + body each = 6 commands.
    expect(scene.commands.length, 6);
  });
}
