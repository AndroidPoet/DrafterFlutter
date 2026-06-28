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
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {DrafterThemeColors? colors}) => Directionality(
  textDirection: TextDirection.ltr,
  child: DrafterTheme(
    colors: colors ?? DrafterThemeColors.light,
    child: Center(child: child),
  ),
);

void main() {
  group('LegendItem', () {
    test('value equality', () {
      const a = LegendItem(label: 'A', color: Color(0xFF112233));
      const b = LegendItem(label: 'A', color: Color(0xFF112233));
      const c = LegendItem(label: 'B', color: Color(0xFF112233));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('DrafterLegend', () {
    testWidgets('renders explicit item labels', (tester) async {
      await tester.pumpWidget(
        _host(
          const DrafterLegend(
            items: [
              LegendItem(label: 'Revenue', color: Color(0xFF4C8DF6)),
              LegendItem(label: 'Cost', color: Color(0xFFF2766B)),
            ],
          ),
        ),
      );
      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('Cost'), findsOneWidget);
    });

    testWidgets('fromLabels renders every label', (tester) async {
      await tester.pumpWidget(
        _host(
          const DrafterLegend.fromLabels(['One', 'Two', 'Three']),
        ),
      );
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);
    });

    testWidgets('fromLabels colors by theme palette, cycling', (tester) async {
      // More labels than palette colors must not throw (index wraps).
      final manyLabels = List<String>.generate(20, (i) => 'S$i');
      await tester.pumpWidget(
        _host(DrafterLegend.fromLabels(manyLabels)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('S0'), findsOneWidget);
      expect(find.text('S19'), findsOneWidget);
    });

    testWidgets('empty legend renders nothing and does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const DrafterLegend(items: [])));
      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('horizontal uses Wrap, vertical uses Column', (tester) async {
      await tester.pumpWidget(
        _host(const DrafterLegend.fromLabels(['A', 'B'])),
      );
      expect(find.byType(Wrap), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const DrafterLegend.fromLabels(
            ['A', 'B'],
            direction: DrafterLegendDirection.vertical,
          ),
        ),
      );
      expect(find.byType(Wrap), findsNothing);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('onItemTap fires with the tapped index', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        _host(
          DrafterLegend.fromLabels(
            const ['A', 'B', 'C'],
            onItemTap: tapped.add,
          ),
        ),
      );
      await tester.tap(find.text('B'));
      expect(tapped, equals([1]));
    });

    testWidgets('not interactive when onItemTap is null', (tester) async {
      await tester.pumpWidget(
        _host(const DrafterLegend.fromLabels(['A'])),
      );
      expect(find.byType(GestureDetector), findsNothing);
    });

    for (final marker in LegendMarker.values) {
      testWidgets('renders with ${marker.name} marker', (tester) async {
        await tester.pumpWidget(
          _host(
            DrafterLegend(
              marker: marker,
              items: const [LegendItem(label: 'A', color: Color(0xFF4C8DF6))],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('A'), findsOneWidget);
      });
    }
  });
}
