// App/frontend/mobile/test/widget_test.dart
// to perform an interaction with a widget in your test, use the widgettester
// utility in the flutter_test package. for example, you can send tap and scroll
// gestures. you can also use widgettester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
