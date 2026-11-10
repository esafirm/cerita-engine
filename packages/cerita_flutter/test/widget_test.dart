import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DialogueBox', () {
    testWidgets('types text out and completes on demand', (tester) async {
      final key = GlobalKey<DialogueBoxState>();
      await tester.pumpWidget(_wrap(DialogueBox('Hello there', key: key, speaker: 'Nora')));

      expect(find.text('Nora'), findsOneWidget);
      expect(find.text('Hello there'), findsNothing);
      expect(key.currentState!.complete(), isTrue);
      await tester.pump();
      expect(find.text('Hello there'), findsOneWidget);
      expect(key.currentState!.complete(), isFalse);
    });

    testWidgets('reports the line once it is typed out or completed', (tester) async {
      final key = GlobalKey<DialogueBoxState>();
      var typed = 0;
      await tester.pumpWidget(_wrap(DialogueBox('Are you going to check it?', key: key, onTyped: () => typed++)));

      await tester.pump(const Duration(milliseconds: 200));
      expect(typed, 0);
      key.currentState!.complete();
      await tester.pump();
      expect(typed, 1);

      // The same line again is already shown.
      await tester.pumpWidget(_wrap(DialogueBox('Are you going to check it?', key: key, onTyped: () => typed++)));
      await tester.pump();
      expect(typed, 2);

      await tester.pumpWidget(_wrap(DialogueBox('Yes.', key: key, onTyped: () => typed++)));
      await tester.pump(const Duration(seconds: 1));
      expect(typed, 3);
    });

    testWidgets('instant shows the full text', (tester) async {
      await tester.pumpWidget(_wrap(const DialogueBox('Hello', instant: true)));
      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('ChoiceList', () {
    ChoiceItemType choiceItem({int? timeoutMs}) => ChoiceItemType.fromJson({
          "type": "CHOICE",
          "text": "Reply?",
          "timeout_ms": ?timeoutMs,
          "default_choice": 1,
          "choices": [
            {"text": "Kind"},
            {"text": "Rude"},
            {"text": "Secret", "condition": "has_photo"},
          ],
        }).withAvailability((condition) => condition == null);

    testWidgets('locked choices show a lock and ignore taps', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(_wrap(ChoiceList(item: choiceItem(), onSelected: (c) => selected.add(c.text))));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.tap(find.text('Secret'));
      await tester.tap(find.text('Kind'));
      expect(selected, ['Kind']);
    });

    testWidgets('timeout picks the default choice', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _wrap(ChoiceList(item: choiceItem(timeoutMs: 3000), onSelected: (c) => selected.add(c.text))),
      );

      expect(find.text('3s'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3100));
      expect(selected, ['Rude']);
    });
  });
}
