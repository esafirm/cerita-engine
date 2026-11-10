import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:cerita_flutter/src/skin/chapter_card_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CardSkin extends StorySkin {
  const _CardSkin();

  @override
  Widget? chapterCard(BuildContext context, Conversation conversation) => Text("card ${conversation.chapter}");
}

Conversation _conversation(String key, String? chapter) => Conversation.fromJson({
  "conversation_id": key,
  "chapter": ?chapter,
  "scene": {"mode": "VN"},
  "conversations": [],
}, key: key);

Widget _wrap(Conversation conversation) => MaterialApp(
  home: StorySkinScope(
    skin: const _CardSkin(),
    child: ChapterCardOverlay(conversation: conversation, child: const DialogueBox("Hi")),
  ),
);

void main() {
  testWidgets('waits for the scene switch, shows the card, then hides it', (tester) async {
    await tester.pumpWidget(_wrap(_conversation("a", "Day 1")));
    // Half of the default 500 ms scene transition belongs to the outgoing scene.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
    final fade = find.ancestor(of: find.text("card Day 1"), matching: find.byType(FadeTransition)).first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 0);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text("card Day 1"), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text("card Day 1"), findsNothing);
  });

  testWidgets('shows again only when the chapter changes', (tester) async {
    await tester.pumpWidget(_wrap(_conversation("a", "Day 1")));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpWidget(_wrap(_conversation("b", "Day 1")));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("card Day 1"), findsNothing);

    await tester.pumpWidget(_wrap(_conversation("c", "Day 2")));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("card Day 2"), findsOneWidget);
  });

  testWidgets('the first line waits for the card to fade out', (tester) async {
    await tester.pumpWidget(_wrap(_conversation("a", "Day 1")));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1000));
    final box = find.descendant(of: find.byType(DialogueBox), matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(box).opacity, 0);
    expect(find.text("Hi"), findsNothing);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<AnimatedOpacity>(box).opacity, 1);
    expect(find.text("Hi"), findsOneWidget);
  });
}
