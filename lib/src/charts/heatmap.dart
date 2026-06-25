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

import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// A single day's contribution count, keyed by its calendar date.
class ContributionData {
  const ContributionData({required this.date, required this.count});

  final DateTime date;
  final int count;
}

/// Lays out and draws contributions as a GitHub-style contribution calendar.
class HeatmapRenderer extends ChartRenderer {
  HeatmapRenderer({
    required this.contributions,
    Color? baseColor,
    Color? backgroundSquareColor,
  }) : baseColor = baseColor ?? drafterHex(0x40C463),
       backgroundSquareColor = backgroundSquareColor ?? drafterHex(0x2D333B);

  final List<ContributionData> contributions;
  final Color baseColor;
  final Color backgroundSquareColor;

  /// Cell edge length in points (~8pt, like the Compose `8.dp`).
  static const double _cellSize = 8;

  /// Gap between adjacent cells (~2pt, like the Compose `2.dp`).
  static const double _cellPadding = 2;

  /// Number of week columns (a full year ≈ 53 weeks).
  static const int _weeks = 53;

  /// Buckets a day's count into a GitHub-style intensity color. Empty days use a
  /// faint square (light gray on light themes, the configured dark square on dark
  /// themes); non-empty days fade the base color through four alpha steps.
  Color _contributionColor(int count, DrafterThemeColors theme) {
    if (count < 1) {
      return theme.isDark ? backgroundSquareColor : drafterHex(0xEBEDF0);
    }
    if (count <= 3) return baseColor.withValues(alpha: 0.35);
    if (count <= 6) return baseColor.withValues(alpha: 0.6);
    if (count <= 9) return baseColor.withValues(alpha: 0.8);
    return baseColor;
  }

  /// Normalizes a [DateTime] to the start of its day (drops time-of-day).
  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    // Anchor the trailing-year window to the DATA's own latest day (falling back
    // to today when empty), so supplied contributions always land in-range.
    final countsByDay = <DateTime, int>{};
    var latest = _startOfDay(DateTime.now());
    for (final contribution in contributions) {
      final day = _startOfDay(contribution.date);
      countsByDay[day] = (countsByDay[day] ?? 0) + contribution.count;
    }
    if (countsByDay.isNotEmpty) {
      latest = countsByDay.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    }

    // Start `weeks*7` days back, aligned to the start of that week (Sunday).
    final rawStart = latest.subtract(const Duration(days: _weeks * 7 - 1));
    // Dart weekday: 1 = Monday .. 7 = Sunday; `% 7` makes Sunday = 0.
    final weekdayIndex = rawStart.weekday % 7;
    final startDate = rawStart.subtract(Duration(days: weekdayIndex));

    // Size the grid to fit the card with square, centered cells.
    final cols = _weeks.toDouble();
    final step = math.max(
      _cellSize,
      math.min(size.width / cols, size.height / 7),
    );
    final cell = math.max(2.0, step - _cellPadding);
    final cornerRadius = math.min(2.0, cell * 0.25);
    final gridWidth = step * cols;
    final gridHeight = step * 7;
    final originX = (size.width - gridWidth) / 2;
    final originY = (size.height - gridHeight) / 2;

    // Fade the whole grid in with the reveal progress.
    final alpha = progress.clamp(0.0, 1.0);

    var currentDate = startDate;
    for (var week = 0; week < _weeks; week++) {
      var broke = false;
      for (var dayOfWeek = 0; dayOfWeek <= 6; dayOfWeek++) {
        if (currentDate.isAfter(latest)) {
          broke = true;
          break;
        }

        final count = countsByDay[currentDate] ?? 0;
        final color = _contributionColor(count, theme);

        final x = originX + week * step;
        final y = originY + dayOfWeek * step;
        final rect = Rect.fromLTWH(x, y, cell, cell);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)),
          Paint()..color = color.withValues(alpha: color.a * alpha),
        );

        currentDate = currentDate.add(const Duration(days: 1));
      }
      if (broke) break;
    }
  }

  @override
  String get accessibilityLabel => 'Contribution heatmap';

  @override
  String get accessibilityValue =>
      '${contributions.length} days, ${contributions.fold(0, (sum, c) => sum + c.count)} total contributions';
}

/// A GitHub-style contribution heatmap with an animated fade-in reveal.
class Heatmap extends StatelessWidget {
  const Heatmap({
    super.key,
    required this.contributions,
    this.baseColor,
    this.backgroundSquareColor,
    this.animate = true,
    this.replay = 0,
  });

  final List<ContributionData> contributions;
  final Color? baseColor;
  final Color? backgroundSquareColor;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: HeatmapRenderer(
      contributions: contributions,
      baseColor: baseColor,
      backgroundSquareColor: backgroundSquareColor,
    ),
    animate: animate,
    replay: replay,
  );
}
