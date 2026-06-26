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
import 'chart_color.dart';
import 'geometry.dart';

/// How a [TextCmd] is anchored horizontally around its origin x.
enum TextAlign { start, center, end }

/// A single drawing primitive in pixel space. The engine emits a list of these;
/// each platform renderer walks the list and draws it with native APIs. This is
/// the cross-language contract — keep it small and dumb.
sealed class DrawCommand {
  const DrawCommand();
}

class LineCmd extends DrawCommand {
  const LineCmd({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.color,
    required this.strokeWidth,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final ChartColor color;
  final double strokeWidth;
}

class RectCmd extends DrawCommand {
  const RectCmd({
    required this.rect,
    required this.color,
    required this.fill,
    this.strokeWidth = 0,
    this.cornerRadius = 0,
  });

  final FRect rect;
  final ChartColor color;
  final bool fill;
  final double strokeWidth;
  final double cornerRadius;
}

class PolylineCmd extends DrawCommand {
  const PolylineCmd({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.smooth = false,
  });

  final List<FPoint> points;
  final ChartColor color;
  final double strokeWidth;

  /// When true the renderer connects the points with a Catmull-Rom spline
  /// instead of straight segments.
  final bool smooth;
}

/// A filled polygon (the [points] are closed automatically). Used for area fills.
class FillPathCmd extends DrawCommand {
  const FillPathCmd({
    required this.points,
    required this.color,
    this.smooth = false,
    this.gradient = false,
  });

  final List<FPoint> points;
  final ChartColor color;

  /// When true the outline through the points is curved with a Catmull-Rom spline.
  final bool smooth;

  /// When true the renderer fills with a soft vertical [color]->transparent gradient.
  final bool gradient;
}

class TextCmd extends DrawCommand {
  const TextCmd({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    required this.sizeSp,
    this.align = TextAlign.start,
  });

  final String text;
  final double x;
  final double y;
  final ChartColor color;
  final double sizeSp;
  final TextAlign align;
}

/// The full output of an engine build: an ordered display list plus its plot rect.
class Scene {
  const Scene(this.commands, this.plot);

  final List<DrawCommand> commands;
  final FRect plot;
}
