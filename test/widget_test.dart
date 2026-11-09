import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsse/fsse.dart';
import 'package:fsse/src/presentation/common/choice_list.dart';
import 'package:fsse/src/presentation/vn/dialogue_box.dart';

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
