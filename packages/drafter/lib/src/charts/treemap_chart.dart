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
import 'dart:ui' as ui;

import 'package:drafter/src/core/chart_formatting.dart';
import 'package:drafter/src/core/chart_graphics.dart';
import 'package:drafter/src/core/chart_math.dart';
import 'package:drafter/src/core/chart_renderer.dart';
import 'package:drafter/src/interaction/chart_scene.dart';
import 'package:drafter/src/theme/drafter_colors.dart';
import 'package:flutter/widgets.dart';

/// One tile of a treemap: a label, its (positive) magnitude, and a fill color.
@immutable
class TreemapItem {
  /// Creates a treemap tile with a [label], (positive) [value], and fill [color].
  const TreemapItem({
    required this.label,
    required this.value,
    required this.color,
  });

  /// The text drawn on the tile.
  final String label;

  /// The tile's magnitude; its area is proportional to this value.
  final double value;

  /// The tile's fill color.
  final Color color;
}

/// A laid-out tile: the source item plus the pixel rectangle it occupies.
class _TreemapTile {
  const _TreemapTile({required this.item, required this.rect});

  final TreemapItem item;
  final Rect rect;
}

const double _gap = 4;
const double _corner = 8;

/// Slice-and-dice / squarify layout. Recursively peels a "row" of the largest
/// items off the shorter side of the remaining rectangle so each tile's aspect
/// ratio stays close to 1, then recurses into the leftover rectangle.
void _squarify(List<TreemapItem> items, Rect rect, List<_TreemapTile> out) {
  if (items.isEmpty || rect.width <= 0 || rect.height <= 0) return;
  if (items.length == 1) {
    out.add(_TreemapTile(item: items[0], rect: rect));
    return;
  }

  final total = items.fold(0.0, (a, b) => a + b.value);
  if (total <= 0) return;

  // Lay tiles along the shorter side so rows stay close to square.
  final horizontal = rect.width >= rect.height;
  final sideLength = horizontal ? rect.height : rect.width;

  // Greedily grow a row, stopping when adding the next item worsens the ratio.
  var rowEnd = 1;
  var rowSum = items[0].value;
  var bestRatio = _worstAspectRatio(
    items.sublist(0, 1),
    sideLength: sideLength,
    rowSum: rowSum,
    rect: rect,
    total: total,
  );
  while (rowEnd < items.length) {
    final candidate = items.sublist(0, rowEnd + 1);
    final candidateSum = rowSum + items[rowEnd].value;
    final candidateRatio = _worstAspectRatio(
      candidate,
      sideLength: sideLength,
      rowSum: candidateSum,
      rect: rect,
      total: total,
    );
    if (candidateRatio > bestRatio) break;
    bestRatio = candidateRatio;
    rowSum = candidateSum;
    rowEnd += 1;
  }

  final row = items.sublist(0, rowEnd);
  final rest = items.sublist(rowEnd);

  // Fraction of the whole rect's area consumed by this row.
  final rowAreaFraction = rowSum / total;

  if (horizontal) {
    final rowWidth = rect.width * rowAreaFraction;
    final rowRect = Rect.fromLTWH(rect.left, rect.top, rowWidth, rect.height);
    out.addAll(_placeRow(row, rowRect, horizontal: false));
    final restRect = Rect.fromLTWH(
      rect.left + rowWidth,
      rect.top,
      rect.width - rowWidth,
      rect.height,
    );
    _squarify(rest, restRect, out);
  } else {
    final rowHeight = rect.height * rowAreaFraction;
    final rowRect = Rect.fromLTWH(rect.left, rect.top, rect.width, rowHeight);
    out.addAll(_placeRow(row, rowRect, horizontal: true));
    final restRect = Rect.fromLTWH(
      rect.left,
      rect.top + rowHeight,
      rect.width,
      rect.height - rowHeight,
    );
    _squarify(rest, restRect, out);
  }
}

/// Lay `row` items out evenly across `rowRect`, stacking along its length.
List<_TreemapTile> _placeRow(
  List<TreemapItem> row,
  Rect rowRect, {
  required bool horizontal,
}) {
  final rowTotal = row.fold(0.0, (a, b) => a + b.value);
  if (rowTotal <= 0) return const [];
  final tiles = <_TreemapTile>[];
  var cursor = horizontal ? rowRect.left : rowRect.top;
  for (final item in row) {
    final frac = item.value / rowTotal;
    if (horizontal) {
      final w = rowRect.width * frac;
      tiles.add(
        _TreemapTile(
          item: item,
          rect: Rect.fromLTWH(cursor, rowRect.top, w, rowRect.height),
        ),
      );
      cursor += w;
    } else {
      final h = rowRect.height * frac;
      tiles.add(
        _TreemapTile(
          item: item,
          rect: Rect.fromLTWH(rowRect.left, cursor, rowRect.width, h),
        ),
      );
      cursor += h;
    }
  }
  return tiles;
}

/// Worst (max) aspect ratio among the row if it were placed, for the heuristic.
double _worstAspectRatio(
  List<TreemapItem> row, {
  required double sideLength,
  required double rowSum,
  required Rect rect,
  required double total,
}) {
  if (rowSum <= 0 || sideLength <= 0) return double.maxFinite;
  final rectArea = rect.width * rect.height;
  final rowArea = rectArea * (rowSum / total);
  final rowThickness = rowArea / sideLength;
  if (rowThickness <= 0) return double.maxFinite;
  var worst = 0.0;
  for (final item in row) {
    final itemArea = rectArea * (item.value / total);
    final itemLength = itemArea / rowThickness;
    if (itemLength > 0) {
      final ratio = (rowThickness / itemLength) > (itemLength / rowThickness)
          ? (rowThickness / itemLength)
          : (itemLength / rowThickness);
      if (ratio > worst) worst = ratio;
    }
  }
  return worst;
}

/// Draws treemap tiles into a canvas using the squarify layout algorithm.
class TreemapChartRenderer extends ChartRenderer
    implements InteractiveRenderer {
  /// Creates a renderer for the given treemap [items].
  TreemapChartRenderer({required this.items});

  /// The tiles to lay out and draw, sorted by value internally.
  final List<TreemapItem> items;

  // Memoized squarify layout: the sort + recursive squarify pass is
  // progress-independent, so it's computed once per size and reused across every
  // animation frame and by buildScene (instead of rebuilt ~60×/second).
  Size? _layoutSize;
  List<_TreemapTile>? _layoutCache;

  /// Lays the tiles out with the same squarify pass [draw] uses, so the marks
  /// match the drawn rectangles. (No animation here — regions stay stable.)
  /// Memoized by [size] since the layout is reveal-independent.
  List<_TreemapTile> _layout(Size size) {
    final cached = _layoutCache;
    if (cached != null && _layoutSize == size) return cached;
    final computed = _computeLayout(size);
    _layoutSize = size;
    _layoutCache = computed;
    return computed;
  }

  List<_TreemapTile> _computeLayout(Size size) {
    if (!(size.width > 0) || !(size.height > 0)) return const [];
    final sorted = [
      for (final item in items)
        if (item.value > 0) item,
    ]..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const [];
    final inset = (size.width < size.height ? size.width : size.height) * 0.04;
    final bounds = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    if (!(bounds.width > 0) || !(bounds.height > 0)) return const [];
    final tiles = <_TreemapTile>[];
    _squarify(sorted, bounds, tiles);
    return tiles;
  }

  @override
  ChartScene buildScene(Size size) {
    final tiles = _layout(size);
    if (tiles.isEmpty) return ChartScene.empty;
    return ChartScene(
      bounds: ChartBounds(size, padding: 0),
      categories: [for (final t in tiles) t.item.label],
      marks: [
        for (var i = 0; i < tiles.length; i++)
          PlotMark(
            index: i,
            seriesIndex: 0,
            seriesName: '',
            label: tiles[i].item.label,
            value: tiles[i].item.value,
            center: tiles[i].rect.center,
            color: tiles[i].item.color,
            region: tiles[i].rect,
          ),
      ],
    );
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (!(size.width > 0) || !(size.height > 0)) return;

    final tiles = _layout(size);
    if (tiles.isEmpty) return;

    for (var index = 0; index < tiles.length; index++) {
      _drawTile(
        tiles[index],
        index: index,
        count: tiles.length,
        canvas: canvas,
        theme: theme,
        progress: progress,
      );
    }
  }

  @override
  String get accessibilityLabel => 'Treemap';

  @override
  String get accessibilityValue => items.isEmpty
      ? 'No data'
      : '${items.length} items, '
            '${AccessibilityFormat.points([for (final i in items) (i.label, i.value)])}';

  void _drawTile(
    _TreemapTile tile, {
    required int index,
    required int count,
    required Canvas canvas,
    required DrafterThemeColors theme,
    required double progress,
  }) {
    final rect = tile.rect;
    final innerLeft = rect.left + _gap;
    final innerTop = rect.top + _gap;
    final innerWidth = rect.width - _gap * 2;
    final innerHeight = rect.height - _gap * 2;
    if (innerWidth <= 1 || innerHeight <= 1) return;

    // Staggered fade + scale-from-center reveal.
    final stagger = count > 1 ? (index / count) * 0.4 : 0.0;
    final local = ((progress - stagger) / (1 - stagger)).clamp(0.0, 1.0);
    if (local <= 0) return;
    final scale = 0.6 + 0.4 * local;
    final alpha = local;

    final drawW = innerWidth * scale;
    final drawH = innerHeight * scale;
    final centerX = innerLeft + innerWidth / 2;
    final centerY = innerTop + innerHeight / 2;
    final tileRect = Rect.fromLTWH(
      centerX - drawW / 2,
      centerY - drawH / 2,
      drawW,
      drawH,
    );
    final rrect = RRect.fromRectAndRadius(
      tileRect,
      const Radius.circular(_corner),
    );

    // Slight vertical gradient: full color at top, slightly dimmed at the bottom.
    final base = tile.item.color;
    canvas
      ..drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(tileRect.center.dx, tileRect.top),
            Offset(tileRect.center.dx, tileRect.bottom),
            [
              base.withValues(alpha: alpha),
              base.withValues(alpha: alpha * 0.78),
            ],
          ),
      )
      // Subtle inner highlight stroke for a premium, glassy edge.
      ..drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.12 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

    _drawLabel(tile.item, tileRect, alpha, canvas);
  }

  void _drawLabel(TreemapItem item, Rect rect, double alpha, Canvas canvas) {
    // Skip text when the tile is too small to read.
    if (rect.width < 48 || rect.height < 32) return;

    const white = Color(0xFFFFFFFF);
    final center = rect.center;

    if (rect.height >= 48) {
      // Room for two centered lines: label above center, value below.
      drawChartText(
        canvas,
        item.label,
        Offset(center.dx, center.dy - 7),
        color: white.withValues(alpha: alpha),
        fontSize: 12,
        weight: FontWeight.w600,
        h: HAlign.center,
        v: VAlign.center,
      );
      drawChartText(
        canvas,
        ChartFormatting.format(item.value),
        Offset(center.dx, center.dy + 8),
        color: white.withValues(alpha: alpha * 0.85),
        fontSize: 10,
        h: HAlign.center,
        v: VAlign.center,
      );
    } else {
      drawChartText(
        canvas,
        item.label,
        center,
        color: white.withValues(alpha: alpha),
        fontSize: 12,
        weight: FontWeight.w600,
        h: HAlign.center,
        v: VAlign.center,
      );
    }
  }
}

/// A squarified treemap with rounded, gradient tiles and a staggered
/// scale-from-center reveal.
class TreemapChart extends StatelessWidget {
  /// Creates a treemap for the given [items].
  const TreemapChart({
    super.key,
    required this.items,
    this.animate = true,
    this.replay = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  /// The tiles to lay out and draw.
  final List<TreemapItem> items;

  /// Whether to animate the reveal on first build.
  final bool animate;

  /// Increment to replay the reveal animation.
  final int replay;

  /// The duration of the reveal animation.
  final Duration duration;

  @override
  Widget build(BuildContext context) => ChartCanvas(
    renderer: TreemapChartRenderer(items: items),
    animate: animate,
    duration: duration,
    replay: replay,
  );
}
