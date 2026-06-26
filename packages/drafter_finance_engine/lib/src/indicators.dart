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

/// MACD line, signal line and histogram, each aligned to the input length.
class MacdResult {
  const MacdResult({
    required this.macd,
    required this.signal,
    required this.histogram,
  });

  final List<double?> macd;
  final List<double?> signal;
  final List<double?> histogram;
}

/// Bollinger Band triple (middle = SMA), each aligned to the input length.
class BollingerBands {
  const BollingerBands({
    required this.middle,
    required this.upper,
    required this.lower,
  });

  final List<double?> middle;
  final List<double?> upper;
  final List<double?> lower;
}

/// Deterministic technical-indicator math — the canonical reference every SDK
/// port mirrors. Every function returns a list aligned 1:1 with the input, using
/// `null` for leading positions where the indicator is undefined. These exact
/// definitions are frozen by the golden fixtures in `drafter-finance-spec`.
class Indicators {
  const Indicators._();

  /// Simple moving average over the trailing [period] samples.
  static List<double?> sma(List<double> values, int period) {
    if (period <= 0) throw ArgumentError('period must be > 0');
    final out = <double?>[];
    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      sum += values[i];
      if (i >= period) sum -= values[i - period];
      out.add(i >= period - 1 ? sum / period : null);
    }
    return out;
  }

  /// Exponential moving average, seeded with the SMA of the first [period]
  /// samples (the convention used by most charting tools), smoothing
  /// `k = 2 / (period + 1)`.
  static List<double?> ema(List<double> values, int period) {
    if (period <= 0) throw ArgumentError('period must be > 0');
    final out = <double?>[];
    if (values.length < period) {
      for (var i = 0; i < values.length; i++) {
        out.add(null);
      }
      return out;
    }
    final k = 2.0 / (period + 1);
    var seed = 0.0;
    for (var i = 0; i < period; i++) {
      seed += values[i];
    }
    seed /= period;
    var prev = seed;
    for (var i = 0; i < values.length; i++) {
      if (i < period - 1) {
        out.add(null);
      } else if (i == period - 1) {
        out.add(prev);
      } else {
        prev = values[i] * k + prev * (1 - k);
        out.add(prev);
      }
    }
    return out;
  }

  /// Wilder's Relative Strength Index. Output is in `0..100`.
  static List<double?> rsi(List<double> values, [int period = 14]) {
    final out = <double?>[];
    if (values.length < period + 1) {
      for (var i = 0; i < values.length; i++) {
        out.add(null);
      }
      return out;
    }
    out.add(null); // first sample has no prior change
    var avgGain = 0.0;
    var avgLoss = 0.0;
    for (var i = 1; i < values.length; i++) {
      final change = values[i] - values[i - 1];
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? -change : 0.0;
      if (i < period) {
        avgGain += gain;
        avgLoss += loss;
        out.add(null);
      } else if (i == period) {
        avgGain = (avgGain + gain) / period;
        avgLoss = (avgLoss + loss) / period;
        out.add(_rsiFrom(avgGain, avgLoss));
      } else {
        avgGain = (avgGain * (period - 1) + gain) / period;
        avgLoss = (avgLoss * (period - 1) + loss) / period;
        out.add(_rsiFrom(avgGain, avgLoss));
      }
    }
    return out;
  }

  static double _rsiFrom(double avgGain, double avgLoss) {
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - 100 / (1 + rs);
  }

  /// MACD = EMA(fast) - EMA(slow); signal = EMA(signalPeriod) of MACD.
  static MacdResult macd(
    List<double> values, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    final fast = ema(values, fastPeriod);
    final slow = ema(values, slowPeriod);
    final macdLine = <double?>[];
    for (var i = 0; i < values.length; i++) {
      final f = fast[i];
      final s = slow[i];
      macdLine.add(f != null && s != null ? f - s : null);
    }
    // Signal = EMA of the defined portion of the MACD line, re-aligned.
    final defined = <double>[for (final v in macdLine) ?v];
    final signalDefined = ema(defined, signalPeriod);
    final offset = macdLine.indexWhere((it) => it != null);
    final signal = List<double?>.filled(values.length, null);
    if (offset >= 0) {
      for (var j = 0; j < signalDefined.length; j++) {
        signal[offset + j] = signalDefined[j];
      }
    }
    final histogram = <double?>[];
    for (var i = 0; i < values.length; i++) {
      final m = macdLine[i];
      final sg = signal[i];
      histogram.add(m != null && sg != null ? m - sg : null);
    }
    return MacdResult(macd: macdLine, signal: signal, histogram: histogram);
  }

  /// Bollinger Bands: middle = SMA(period); bands = middle ± mult·σ (population).
  static BollingerBands bollinger(
    List<double> values, {
    int period = 20,
    double mult = 2,
  }) {
    if (period <= 0) throw ArgumentError('period must be > 0');
    final middle = sma(values, period);
    final upper = <double?>[];
    final lower = <double?>[];
    for (var i = 0; i < values.length; i++) {
      final mid = middle[i];
      if (mid == null) {
        upper.add(null);
        lower.add(null);
        continue;
      }
      var variance = 0.0;
      for (var j = i - period + 1; j <= i; j++) {
        final d = values[j] - mid;
        variance += d * d;
      }
      final sd = math.sqrt(variance / period);
      upper.add(mid + mult * sd);
      lower.add(mid - mult * sd);
    }
    return BollingerBands(middle: middle, upper: upper, lower: lower);
  }
}
