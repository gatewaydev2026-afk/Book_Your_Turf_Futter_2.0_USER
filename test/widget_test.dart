import 'package:book_your_turf/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads Test Screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(
      initialScreen: Scaffold(body: Text('Test Screen')),
    ));

    expect(find.text('Test Screen'), findsOneWidget);
  });
}
