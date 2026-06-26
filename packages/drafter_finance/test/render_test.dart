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

import 'package:drafter_finance/drafter_finance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Candle> _candles() {
  final rng = math.Random(3);
  final out = <Candle>[];
  var price = 100.0;
  for (var i = 0; i < 40; i++) {
    final open = price;
    final close = (price + (rng.nextDouble() - 0.5) * 5).clamp(50.0, 150.0);
    out.add(Candle(
      time: i,
      open: open,
      high: math.max(open, close) + 1,
      low: math.min(open, close) - 1,
      close: close,
      volume: 100 + rng.nextDouble() * 900,
    ));
    price = close;
  }
  return out;
}

/// Pumps a widget into a sized frame and asserts it painted without throwing —
/// this drives the real `CustomPainter` (gradients, Catmull-Rom paths, text).
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, height: 220, child: child)),
      ),
    ),
  );
  // Let the reveal animation advance a couple of frames, then settle.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 1700));
  expect(tester.takeException(), isNull);
}

void main() {
  final candles = _candles();
  final closes = [for (final c in candles) c.close];

  testWidgets('candlestick renders', (t) async {
    await _pump(t, FinanceCandlestickChart(candles: candles));
  });

  testWidgets('area renders (gradient + smooth path)', (t) async {
    await _pump(t, FinanceAreaChart(values: closes));
  });

  testWidgets('line renders', (t) async {
    await _pump(t, FinanceLineChart(values: closes));
  });

  testWidgets('baseline renders', (t) async {
    await _pump(
      t,
      FinanceBaselineChart(
        values: closes,
        style: DrafterTheme.instance.baseline(closes.first),
      ),
    );
  });

  testWidgets('histogram renders', (t) async {
    await _pump(t, FinanceHistogramChart(values: closes));
  });

  testWidgets('volume renders', (t) async {
    await _pump(t, FinanceVolumeChart(candles: candles));
  });

  testWidgets('bars render', (t) async {
    await _pump(t, FinanceBarChart(candles: candles));
  });

  testWidgets('candlestick crosshair on drag', (t) async {
    await _pump(t, FinanceCandlestickChart(candles: candles));
    await t.drag(find.byType(FinanceCandlestickChart), const Offset(40, 10));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
