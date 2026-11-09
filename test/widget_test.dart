import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsse/src/simpleconversation/dialogue_box.dart';

void main() {
  group('DialogueBox', () {
    testWidgets('displays dialogue text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DialogueBox('Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });
  });
}

