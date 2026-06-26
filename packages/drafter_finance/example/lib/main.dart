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

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drafter Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const DemoScreen(),
    );
  }
}

/// A deterministic random-walk OHLC series so the demo looks alive but stable.
List<Candle> _sampleCandles({int count = 60, int seed = 7}) {
  final rng = math.Random(seed);
  final out = <Candle>[];
  var price = 100.0;
  for (var i = 0; i < count; i++) {
    final drift = (rng.nextDouble() - 0.48) * 4;
    final open = price;
    final close = (price + drift).clamp(40.0, 200.0);
    final high = math.max(open, close) + rng.nextDouble() * 2;
    final low = math.min(open, close) - rng.nextDouble() * 2;
    final volume = 500 + rng.nextDouble() * 1500;
    out.add(Candle(
      time: i,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    ));
    price = close;
  }
  return out;
}

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final candles = _sampleCandles();
    final closes = [for (final c in candles) c.close];
    final changes = [for (final c in candles) c.close - c.open];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drafter Finance'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ChartCard(
            title: 'Candlestick — drag to scrub',
            child: FinanceCandlestickChart(candles: candles),
          ),
          _ChartCard(
            title: 'Candlestick (TradingView theme)',
            child: FinanceCandlestickChart(
              candles: candles,
              style: TradingViewTheme.instance.candle(),
            ),
          ),
          _ChartCard(
            title: 'Area',
            child: FinanceAreaChart(values: closes),
          ),
          _ChartCard(
            title: 'Line',
            child: FinanceLineChart(values: closes),
          ),
          _ChartCard(
            title: 'Baseline',
            child: FinanceBaselineChart(
              values: closes,
              style: DrafterTheme.instance.baseline(closes.first),
            ),
          ),
          _ChartCard(
            title: 'OHLC bars',
            child: FinanceBarChart(candles: candles),
          ),
          _ChartCard(
            title: 'Volume',
            child: FinanceVolumeChart(candles: candles),
          ),
          _ChartCard(
            title: 'Histogram · change',
            child: FinanceHistogramChart(
              values: changes,
              style: DrafterTheme.instance.histogram(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF55606C),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 200, child: child),
        ],
      ),
    );
  }
}
