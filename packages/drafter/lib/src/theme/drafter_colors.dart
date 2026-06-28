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

  /// Series palette color 1 — blue.
  static final Color blue = drafterHex(0x4C8DF6);

  /// Series palette color 2 — teal.
  static final Color teal = drafterHex(0x2FC4C0);

  /// Series palette color 3 — violet.
  static final Color violet = drafterHex(0x7C6BF2);

  /// Series palette color 4 — amber.
  static final Color amber = drafterHex(0xF6B24C);

  /// Series palette color 5 — green.
  static final Color green = drafterHex(0x49C17A);

  /// Series palette color 6 — coral.
  static final Color coral = drafterHex(0xF2766B);

  /// Series palette color 7 — pink.
  static final Color pink = drafterHex(0xEC6B9A);

  /// Series palette color 8 — indigo.
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

  /// Gridline color for the light theme.
  static final Color gridLight = drafterHex(0xEDF0F5);

  /// Axis-label color for the light theme.
  static final Color labelLight = drafterHex(0x9AA3B2);

  /// Surface (background) color for the light theme.
  static final Color surfaceLight = drafterHex(0xFFFFFF);

  // Dark theme.

  /// Gridline color for the dark theme.
  static final Color gridDark = drafterHex(0x2A2E37);

  /// Axis-label color for the dark theme.
  static final Color labelDark = drafterHex(0x8A92A2);

  /// Surface (background) color for the dark theme.
  static final Color surfaceDark = drafterHex(0x1B1E25);
}

/// The resolved color set a chart draws with. Immutable value — pass by value.
@immutable
class DrafterThemeColors {
  /// Creates a resolved color set from a series [palette] plus the [grid],
  /// [label] and [surface] colors; [isDark] selects dark-theme derivations.
  const DrafterThemeColors({
    required this.palette,
    required this.grid,
    required this.label,
    required this.surface,
    required this.isDark,
  });

  /// The ordered series palette, cycled by [colorAt].
  final List<Color> palette;

  /// The gridline color.
  final Color grid;

  /// The axis-label color.
  final Color label;

  /// The surface (background) color.
  final Color surface;

  /// Whether this is a dark theme (drives the derived interaction colors).
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

  // ---------------------------------------------------------------------------
  // Interaction colors (tooltips / trackball / selection).
  //
  // Derived from the existing palette via getters so the const constructor and
  // the two static instances stay untouched — adding interactivity does not
  // change a theme's value identity. A dark, slightly translucent tooltip panel
  // reads on both light and dark surfaces; the crosshair and selection band are
  // calm, low-alpha tones (no harsh red), matching the library's palette ethos.
  // ---------------------------------------------------------------------------

  /// The tooltip / popup panel background.
  Color get tooltipBackground =>
      isDark ? const Color(0xF22B303A) : const Color(0xF21B1E25);

  /// The tooltip's primary text color (reads on [tooltipBackground]).
  Color get tooltipText => const Color(0xFFF4F6FA);

  /// The tooltip's secondary / muted text color.
  Color get tooltipMutedText => const Color(0xB3F4F6FA);

  /// The trackball / crosshair line color.
  Color get crosshair => label.withValues(alpha: 0.5);

  /// The fill of a drag range-selection band.
  Color get selectionBand =>
      (palette.isEmpty ? DrafterColors.blue : palette.first).withValues(
        alpha: 0.12,
      );

  /// The border of a drag range-selection band.
  Color get selectionBorder =>
      (palette.isEmpty ? DrafterColors.blue : palette.first).withValues(
        alpha: 0.5,
      );

  /// Cycles the palette by index, wrapping around. Falls back to
  /// [DrafterColors.blue] when the palette is empty rather than throwing.
  Color colorAt(int index) {
    if (palette.isEmpty) return DrafterColors.blue;
    return palette[((index % palette.length) + palette.length) %
        palette.length];
  }

  @override
  bool operator ==(Object other) =>
      other is DrafterThemeColors &&
      listEquals(other.palette, palette) &&
      other.grid == grid &&
      other.label == label &&
      other.surface == surface &&
      other.isDark == isDark;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(palette), grid, label, surface, isDark);
}
