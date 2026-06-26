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

/// Golden color values for both shipped themes — the Kotlin `ThemesTest` and
/// Swift `ThemesTests` assert the IDENTICAL RGB. Keeps the palettes in lockstep.
void main() {
  test('TradingView matches Lightweight Charts defaults', () {
    final up = TradingViewTheme.instance.candle().up; // #26a69a
    expect([up.red, up.green, up.blue], [38, 166, 154]);
    final down = TradingViewTheme.instance.candle().down; // #ef5350
    expect([down.red, down.green, down.blue], [239, 83, 80]);
    final line = TradingViewTheme.instance.line(); // #2196f3, width 3
    expect([line.color.red, line.color.green, line.color.blue], [33, 150, 243]);
    expect(line.lineWidth, 3);
  });

  test('Drafter ships MA overlays, TradingView ships none', () {
    expect(DrafterTheme.instance.candle().movingAverages.length, 3);
    expect(TradingViewTheme.instance.candle().movingAverages.length, 0);
  });

  test('Drafter down is coral, not red', () {
    final down = DrafterTheme.instance.candle().down; // #F2766B coral
    expect([down.red, down.green, down.blue], [242, 118, 107]);
  });
}
