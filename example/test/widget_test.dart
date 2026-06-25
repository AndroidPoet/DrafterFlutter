// A basic smoke test for the Drafter gallery demo app.

import 'package:flutter_test/flutter_test.dart';

import 'package:drafter_example/main.dart';

void main() {
  testWidgets('Gallery renders the app bar', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    expect(find.text('Drafter — 27 charts'), findsOneWidget);
  });
}
