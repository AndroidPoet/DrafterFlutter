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
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Creates an opaque [Color] from a 24-bit RGB hex value, e.g. `drafterHex(0x4C8DF6)`.
Color drafterHex(int hex) => Color(0xFF000000 | (hex & 0xFFFFFF));

/// Immutable Drafter color constants — the 8-color series palette plus the
/// light/dark surface, grid, and label colors. Ported 1:1 from the Compose
/// library's `theme/DrafterColors.kt` so all ports stay visually identical.
abstract final class DrafterColors {
  // Series palette (deliberately calm, premium tones — no harsh red).
  static final Color blue = drafterHex(0x4C8DF6);
  static final Color teal = drafterHex(0x2FC4C0);
  static final Color violet = drafterHex(0x7C6BF2);
  static final Color amber = drafterHex(0xF6B24C);
  static final Color green = drafterHex(0x49C17A);
  static final Color coral = drafterHex(0xF2766B);
  static final Color pink = drafterHex(0xEC6B9A);
  static final Color indigo = drafterHex(0x5B6BF0);

  /// The ordered series palette used to color slices/series by index.
  static final List<Color> palette = [
    blue,
    teal,
    violet,
    amber,
    green,
    coral,
    pink,
    indigo,
  ];

  // Light theme.
  static final Color gridLight = drafterHex(0xEDF0F5);
  static final Color labelLight = drafterHex(0x9AA3B2);
  static final Color surfaceLight = drafterHex(0xFFFFFF);

  // Dark theme.
  static final Color gridDark = drafterHex(0x2A2E37);
  static final Color labelDark = drafterHex(0x8A92A2);
  static final Color surfaceDark = drafterHex(0x1B1E25);
}

/// The resolved color set a chart draws with. Immutable value — pass by value.
@immutable
class DrafterThemeColors {
  const DrafterThemeColors({
    required this.palette,
    required this.grid,
    required this.label,
    required this.surface,
    required this.isDark,
  });

  final List<Color> palette;
  final Color grid;
  final Color label;
  final Color surface;
  final bool isDark;

  /// The light theme color set.
  static final DrafterThemeColors light = DrafterThemeColors(
    palette: DrafterColors.palette,
    grid: DrafterColors.gridLight,
    label: DrafterColors.labelLight,
    surface: DrafterColors.surfaceLight,
    isDark: false,
  );

  /// The dark theme color set.
  static final DrafterThemeColors dark = DrafterThemeColors(
    palette: DrafterColors.palette,
    grid: DrafterColors.gridDark,
    label: DrafterColors.labelDark,
    surface: DrafterColors.surfaceDark,
    isDark: true,
  );

  /// Cycles the palette by index, wrapping around.
  Color colorAt(int index) =>
      palette[((index % palette.length) + palette.length) % palette.length];

  @override
  bool operator ==(Object other) =>
      other is DrafterThemeColors &&
      other.grid == grid &&
      other.label == label &&
      other.surface == surface &&
      other.isDark == isDark;

  @override
  int get hashCode => Object.hash(grid, label, surface, isDark);
}
