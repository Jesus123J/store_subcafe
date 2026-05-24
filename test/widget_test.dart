import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Test OK'))),
    );
    expect(find.text('Test OK'), findsOneWidget);
  });
}
