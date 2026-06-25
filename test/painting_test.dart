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
import 'package:drafter/drafter.dart';
import 'package:drafter/painting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A custom renderer built purely from the `painting.dart` extension API —
/// proves the lower-level building blocks stay reachable after the barrel split.
class _BoxRenderer extends ChartRenderer {
  const _BoxRenderer();

  @override
  void draw(Canvas canvas, Size size, DrafterThemeColors theme, double t) {
    final bounds = ChartBounds(size);
    canvas.drawRect(bounds.rect, Paint()..color = theme.colorAt(0));
    drawChartText(canvas, 'hi', bounds.rect.center, color: theme.label);
  }

  @override
  String get accessibilityLabel => 'Custom chart';

  @override
  String get accessibilityValue => 'one box';
}

void main() {
  testWidgets('a custom ChartRenderer renders via the painting entrypoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DrafterTheme(
          colors: DrafterThemeColors.light,
          child: const SizedBox(
            width: 200,
            height: 200,
            child: ChartCanvas(renderer: _BoxRenderer()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Custom chart'), findsOneWidget);
  });
}
