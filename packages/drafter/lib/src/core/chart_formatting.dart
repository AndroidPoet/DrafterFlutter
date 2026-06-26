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

/// Deterministic, platform-independent number formatting for axis labels and
/// value read-outs. Integer arithmetic avoids float-precision drift and drops
/// trailing zeros (3.0 -> "3", 3.10 -> "3.1").
abstract final class ChartFormatting {
  /// Formats [value] with up to [decimals] fractional digits, trimming trailing
  /// zeros. Handles NaN / infinity gracefully.
  static String format(double value, {int decimals = 1}) {
    if (value.isNaN) return 'NaN';
    if (value.isInfinite) return value > 0 ? '∞' : '-∞';

    final negative = value < 0;
    final magnitude = value.abs();
    var scale = 1;
    for (var i = 0; i < math.max(0, decimals); i++) {
      scale *= 10;
    }

    final scaled = (magnitude * scale).roundToDouble();
    final whole = scaled ~/ scale;
    final fracInt = (scaled.toInt()) % scale;

    if (fracInt == 0 || decimals <= 0) {
      return '${negative && (whole != 0 || scaled != 0) ? '-' : ''}$whole';
    }

    // Build the fractional part, trimming trailing zeros.
    var digits = '$fracInt';
    while (digits.length < decimals) {
      digits = '0$digits';
    }
    while (digits.endsWith('0')) {
      digits = digits.substring(0, digits.length - 1);
    }
    if (digits.isEmpty) {
      return '${negative ? '-' : ''}$whole';
    }
    return '${negative ? '-' : ''}$whole.$digits';
  }
}
