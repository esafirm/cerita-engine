import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Day 1 is free and leads to Day 2, which the app's gate keeps closed until [open] is set.
Map<String, Map<String, dynamic>> _story() => {
      "index": {
        "conversation_id": "cvn",
        "chapter": "Day 1",
        "scene": {"mode": "VN"},
        "conversations": [
          {"type": "NARRATION", "text": "The tide is out."},
          {"type": "JUMP", "target": "day2"},
        ],
      },
      "day2": {
        "conversation_id": "cvn",
        "chapter": "Day 2",
        "checkpoint": true,
        "scene": {"mode": "VN"},
        "conversations": [
          {"type": "NARRATION", "text": "The tide is back."},
        ],
      },
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<StorySetup> _setup({required bool Function() open, StoryGateBuilder? gateBuilder}) async {
  final storage = InMemoryStoryStorage();
  await storage.saveSettings(const PlayerSettings(textMsPerChar: 0));
  return StorySetup(
    config: const LoaderConfig(),
    loader: FakeEngineLoader(_story()),
    storage: storage,
    audio: SilentAudio.new,
    gate: (conversation) => open() || conversation.chapter == "Day 1",
    gateBuilder: gateBuilder,
  );
}

void main() {
  setUp(mockAudioChannels);

  testWidgets('the app\'s gate screen shows at a closed chapter, and the story goes on once it opens',
      (tester) async {
    var open = false;
    final setup = await _setup(
      open: () => open,
      gateBuilder: (context, request) => Center(
        child: TextButton(
          onPressed: () {
            open = true;
            request.reopen!();
          },
          child: Text("Buy ${request.conversation.chapter}"),
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    await _settle(tester);
    expect(find.text("The tide is out.", findRichText: true), findsOneWidget);

    await tester.tapAt(const Offset(400, 200));
    await _settle(tester);
    expect(find.text("Buy Day 2"), findsOneWidget);
    final meta = await setup.storage.loadMeta();
    expect(meta.unlockedCheckpoints, isEmpty, reason: "a closed chapter isn't unlocked");
    expect((await setup.storage.loadSlot(SaveSlot.autoSlotId))?.conversationKey, "index",
        reason: "the autosave stays before the gate");

    // The story's menu sits under the gate screen: no tap reaches it, so nothing can save the half-made move.
    await tester.tap(find.byIcon(Icons.menu), warnIfMissed: false);
    await _settle(tester);
    expect(find.byType(StorySheetAction), findsNothing);
    expect(find.text("Buy Day 2"), findsOneWidget);

    await tester.tap(find.text("Buy Day 2"));
    await _settle(tester);
    expect(find.text("Buy Day 2"), findsNothing);
    await tester.tapAt(const Offset(400, 200));
    await _settle(tester);
    expect(find.text("The tide is back.", findRichText: true), findsOneWidget);
  });

  testWidgets('without a gate screen, a closed chapter shows a notice with a way back', (tester) async {
    final setup = await _setup(open: () => false);
    final checkpoint = Checkpoint(conversationKey: "day2", dataMap: const {}, unlockedAt: DateTime(2026));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => StoryScreen(setup: setup, checkpoint: checkpoint))),
          child: const Text("Chapters"),
        ),
      ),
    ));
    await tester.tap(find.text("Chapters"));
    await _settle(tester);
    expect(find.text(CeritaStrings.en.storyClosed), findsOneWidget);

    await tester.tap(find.text(CeritaStrings.en.back));
    await _settle(tester);
    expect(find.text("Chapters"), findsOneWidget);
  });
}
