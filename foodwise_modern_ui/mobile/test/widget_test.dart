
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FoodWise basic widget test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('FoodWise'),
        ),
      ),
    );

    expect(find.text('FoodWise'), findsOneWidget);
  });
}
