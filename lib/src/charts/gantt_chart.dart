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

import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// One row of a [GanttChart]: a [name], its [startMonth] on the timeline, a
/// [duration] in months, and an optional bar [color] (falls back to the theme
/// palette when `null`).
class GanttTask {
  const GanttTask({
    required this.name,
    required this.startMonth,
    required this.duration,
    this.color,
  });

  final String name;
  final int startMonth;
  final int duration;
  final Color? color;
}

/// Draws an ordered `[GanttTask]` into a canvas as a horizontal timeline of bars.
class GanttChartRenderer extends ChartRenderer {
  const GanttChartRenderer({required this.tasks});

  final List<GanttTask> tasks;

  /// Largest `startMonth + duration` across all tasks, clamped to at least 1.
  int get _maxMonth {
    var m = 1;
    for (final t in tasks) {
      final v = t.startMonth + t.duration;
      if (v > m) m = v;
    }
    return math.max(m, 1);
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (size.width < 1 || size.height < 1 || tasks.isEmpty) return;

    // Compose layout: 20% left margin, 70% width, 10% top inset, 80% height.
    final chartHeight = size.height * 0.8;
    final chartWidth = size.width * 0.7;
    final chartTop = size.height * 0.1;
    final chartBottom = chartTop + chartHeight;
    final chartLeft = size.width * 0.2;

    final safeMaxMonth = _maxMonth.toDouble();

    _drawAxes(
      canvas,
      left: chartLeft,
      top: chartTop,
      bottom: chartBottom,
      width: chartWidth,
      theme: theme,
    );
    _drawYAxisLabels(
      canvas,
      left: chartLeft,
      top: chartTop,
      bottom: chartBottom,
      theme: theme,
    );
    _drawXAxisLabels(
      canvas,
      left: chartLeft,
      bottom: chartBottom,
      width: chartWidth,
      safeMaxMonth: safeMaxMonth,
      canvasSize: size,
      theme: theme,
    );

    // Bars.
    final taskHeight = math.max(chartHeight / tasks.length, 1.0);
    final p = progress.clamp(0.0, 1.0);
    for (var index = 0; index < tasks.length; index++) {
      final task = tasks[index];
      final startX = chartLeft + (task.startMonth / safeMaxMonth) * chartWidth;
      final width = math.max(
        (task.duration / safeMaxMonth) * chartWidth * p,
        1.0,
      );
      final y = chartTop + index * taskHeight;
      // Each bar takes its own color; fall back to the theme palette when unset.
      final color = task.color ?? theme.colorAt(index);
      final barHeight = math.max(taskHeight * 0.8, 1.0);
      final rect = Rect.fromLTWH(
        startX,
        y + taskHeight * 0.1,
        width,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(6, barHeight / 2)),
        ),
        Paint()..color = color.withValues(alpha: progress.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  String get accessibilityLabel => 'Gantt chart';

  @override
  String get accessibilityValue {
    if (tasks.isEmpty) return 'No data';
    const limit = 12;
    final names = tasks
        .take(limit)
        .map((t) => t.name.isEmpty ? 'task' : t.name)
        .toList();
    final suffix = tasks.length > limit
        ? ', and ${tasks.length - limit} more'
        : '';
    return '${tasks.length} tasks: ${names.join(', ')}$suffix';
  }

  // ---------------------------------------------------------------------------
  // Axes & labels
  // ---------------------------------------------------------------------------

  void _drawAxes(
    Canvas canvas, {
    required double left,
    required double top,
    required double bottom,
    required double width,
    required DrafterThemeColors theme,
  }) {
    final axisPaint = Paint()
      ..color = theme.label
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(Offset(left, top), Offset(left, bottom), axisPaint)
      ..drawLine(
        Offset(left, bottom),
        Offset(left + width, bottom),
        axisPaint,
      );
  }

  void _drawYAxisLabels(
    Canvas canvas, {
    required double left,
    required double top,
    required double bottom,
    required DrafterThemeColors theme,
  }) {
    final taskHeight = math.max((bottom - top) / tasks.length, 1);
    for (var index = 0; index < tasks.length; index++) {
      final task = tasks[index];
      final yCenter = top + index * taskHeight + taskHeight / 2;
      // Truncate so long names stay inside the narrow left margin.
      final name = task.name.length > 9
          ? '${task.name.substring(0, 8)}…'
          : task.name;
      drawChartText(
        canvas,
        name,
        Offset(left - 4, yCenter),
        color: theme.label,
        h: HAlign.end,
        v: VAlign.center,
      );
    }
  }

  void _drawXAxisLabels(
    Canvas canvas, {
    required double left,
    required double bottom,
    required double width,
    required double safeMaxMonth,
    required Size canvasSize,
    required DrafterThemeColors theme,
  }) {
    // Distinct integer months spanned by the tasks, plus 0 and the max month.
    final months = <int>{};
    for (final task in tasks) {
      final start = task.startMonth;
      final end = task.startMonth + task.duration;
      if (start <= end) {
        for (var m = start; m <= end; m++) {
          months.add(m);
        }
      }
    }
    months
      ..add(0)
      ..add(safeMaxMonth.toInt());

    // Thin out ticks so labels don't overlap at small widths (~14pt each).
    final sorted = months.toList()..sort();
    final maxTicks = math.max(2, (width / 18).toInt());
    final step = math.max(1, (sorted.length / maxTicks).ceil());
    for (var i = 0; i < sorted.length; i++) {
      final monthInt = sorted[i];
      final isLast = monthInt == sorted.last;
      if (!(i % step == 0 || isLast)) continue;
      final fraction = monthInt / safeMaxMonth;
      // Clamp the x so the rightmost tick stays inside the canvas.
      final x = math.min(left + fraction * width, canvasSize.width - 6);
      drawChartText(
        canvas,
        '$monthInt',
        Offset(x, bottom + 6),
        color: theme.label,
        h: isLast ? HAlign.end : HAlign.center,
      );
    }
  }
}

/// A horizontal Gantt timeline with rounded task bars and an animated reveal.
class GanttChart extends StatelessWidget {
  const GanttChart({
    super.key,
    required this.tasks,
    this.animate = true,
    this.replay = 0,
  });

  final List<GanttTask> tasks;
  final bool animate;
  final int replay;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: GanttChartRenderer(tasks: tasks),
    animate: animate,
    duration: const Duration(milliseconds: 2000),
    replay: replay,
  );
}
