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

/// A platform-agnostic color, stored as packed `0xAARRGGBB`.
///
/// Renderers convert this to their native color type (Flutter `Color`, Compose
/// `Color`, SwiftUI `Color`, …). Kept as a plain value so it serializes cleanly
/// into goldens.
class ChartColor {
  const ChartColor(this.argb);

  /// Packed `0xAARRGGBB`. Held as an `int` (64-bit on the Dart VM) to match the
  /// Kotlin `Long`.
  final int argb;

  int get alpha => (argb >> 24) & 0xFF;
  int get red => (argb >> 16) & 0xFF;
  int get green => (argb >> 8) & 0xFF;
  int get blue => argb & 0xFF;

  /// Builds a color from 8-bit channels; alpha defaults to opaque.
  static ChartColor rgba(int r, int g, int b, [int a = 255]) => ChartColor(
        ((a & 0xFF) << 24) |
            ((r & 0xFF) << 16) |
            ((g & 0xFF) << 8) |
            (b & 0xFF),
      );

  /// Returns a copy with [argb] replaced (mirrors Kotlin's `copy(argb = …)`).
  ChartColor copyWith({int? argb}) => ChartColor(argb ?? this.argb);

  @override
  bool operator ==(Object other) => other is ChartColor && other.argb == argb;

  @override
  int get hashCode => argb.hashCode;

  @override
  String toString() =>
      'ChartColor(0x${argb.toRadixString(16).padLeft(8, '0')})';
}
