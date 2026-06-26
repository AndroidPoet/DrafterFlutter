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

/// Maps a value domain `[domainMin, domainMax]` onto a pixel range
/// `[rangeStart, rangeEnd]` linearly.
///
/// For a price axis pass `rangeStart = bottomPx` and `rangeEnd = topPx` so that
/// the maximum price maps to the top of the plot (smaller y).
class LinearScale {
  LinearScale({
    required this.domainMin,
    required this.domainMax,
    required this.rangeStart,
    required this.rangeEnd,
  }) : _domainSpan =
            (domainMax - domainMin) == 0 ? 1.0 : (domainMax - domainMin);

  final double domainMin;
  final double domainMax;
  final double rangeStart;
  final double rangeEnd;
  final double _domainSpan;

  double toPixel(double value) {
    final t = (value - domainMin) / _domainSpan;
    return rangeStart + t * (rangeEnd - rangeStart);
  }

  double toValue(double pixel) {
    final span = (rangeEnd - rangeStart) == 0 ? 1.0 : (rangeEnd - rangeStart);
    final t = (pixel - rangeStart) / span;
    return domainMin + t * _domainSpan;
  }
}
