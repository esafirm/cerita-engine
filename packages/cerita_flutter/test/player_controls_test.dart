import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, dynamic> _text(String text) => {"type": "TEXT", "text": text, "profile": "nora:0"};

final _story = {
  "index": {
    "conversation_id": "cvn",
    "chapter": "Prologue",
    "scene": {"mode": "VN"},
    "conversations": [
      _text("One"),
      _text("Two"),
      {
        "type": "CHOICE",
        "text": "Pick",
        "variable": "pick",
        "choices": [
          {"text": "Left", "value": "left"},
          {"text": "Right", "value": "right"},
        ],
      },
      _text("You went {{pick}}"),
    ],
  },
};

void main() {
  setUp(mockAudioChannels);

  Future<(StoryController, StorySetup)> pumpStory(WidgetTester tester, {StoryStorage? storage}) async {
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader(_story),
      storage: storage ?? InMemoryStoryStorage(),
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    await tester.pumpAndSettle();
    final stage = tester.widget<VnStage>(find.byType(VnStage));
    return (stage.controller, setup);
  }

  /// Moves on from a line that is fully typed out.
  Future<void> advance(WidgetTester tester) async {
    await tester.tap(find.byType(VnStage));
    await tester.pumpAndSettle();
  }

  testWidgets('BACK rolls back to the previous line and a choice can be picked again', (tester) async {
    final (controller, _) = await pumpStory(tester);
    expect(controller.current?.getText(), "One");
    expect(controller.canRollback, isFalse);

    await advance(tester);
    expect(controller.current?.getText(), "Two");
    await tester.tap(find.byTooltip("Back"));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "One");
    expect(controller.rolledBack, isTrue);
    expect(find.text("One"), findsOneWidget, reason: "rolled-back lines show at once");

    await advance(tester);
    await advance(tester);
    expect(controller.phase, StoryPhase.choice);
    await tester.tap(find.text("Left"));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "You went left");

    await controller.rollback();
    await tester.pumpAndSettle();
    expect(controller.phase, StoryPhase.choice);
    await tester.tap(find.text("Right"));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "You went right");
  });

  testWidgets('the backlog rewinds to a line', (tester) async {
    final (controller, _) = await pumpStory(tester);
    await advance(tester);
    await advance(tester);
    expect(controller.phase, StoryPhase.choice);

    await tester.tap(find.byTooltip("Backlog"));
    await tester.pumpAndSettle();
    // Newest first: "Two", then "One". The choice prompt has no button.
    expect(find.byTooltip("Go back to this line"), findsNWidgets(2));
    await tester.tap(find.byTooltip("Go back to this line").last);
    await tester.pumpAndSettle();
    expect(find.byType(BacklogSheet), findsNothing);
    expect(controller.current?.getText(), "One");
    expect(controller.history, hasLength(1));
  });

  testWidgets('quick save and quick load', (tester) async {
    final storage = InMemoryStoryStorage();
    final (controller, _) = await pumpStory(tester, storage: storage);
    await advance(tester);
    await tester.tap(find.byTooltip("Quick save"));
    await tester.pumpAndSettle();
    expect((await storage.loadSlot(SaveSlot.quickSlotId))?.dialogIndex, 2);

    await advance(tester);
    expect(controller.phase, StoryPhase.choice);
    await tester.tap(find.byTooltip("Quick load"));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Two");
    expect(controller.phase, StoryPhase.showing);
    // The quick save kept the rollback log.
    await tester.tap(find.byTooltip("Back"));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "One");
  });

  testWidgets('HIDE hides the dialogue and controls until the next tap', (tester) async {
    await pumpStory(tester);
    expect(find.text("One"), findsOneWidget);

    await tester.tap(find.byTooltip("Hide"));
    await tester.pump();
    expect(find.text("One"), findsNothing);
    expect(find.byTooltip("Back"), findsNothing);

    await tester.tap(find.byType(VnStage));
    await tester.pump();
    expect(find.text("One"), findsOneWidget);
    final stage = tester.widget<VnStage>(find.byType(VnStage));
    expect(stage.controller.current?.getText(), "One", reason: "the tap that shows the UI doesn't advance");
  });

  testWidgets('settings apply to a running story', (tester) async {
    final storage = InMemoryStoryStorage();
    final (controller, setup) = await pumpStory(tester, storage: storage);
    await setup.settings.update(setup.settings.value.copyWith(textMsPerChar: 0, autoDelayMs: 2000));
    await tester.pump();
    expect(tester.widget<DialogueBox>(find.byType(DialogueBox)).msPerChar, 0);
    expect((await storage.loadSettings()).autoDelayMs, 2000);

    controller.toggleAuto();
    await tester.pump(const Duration(milliseconds: 1900));
    expect(controller.current?.getText(), "One");
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(controller.current?.getText(), "Two");
  });

  testWidgets('settings screen saves changes and resets them', (tester) async {
    final storage = InMemoryStoryStorage();
    final prefs = PlayerPrefs(storage);
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: prefs)));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Skip unread text"));
    await tester.pumpAndSettle();
    expect(prefs.value.skipUnread, isTrue);
    expect((await storage.loadSettings()).skipUnread, isTrue);

    await tester.tap(find.text("Reset"));
    await tester.pumpAndSettle();
    expect(prefs.value, const PlayerSettings());
  });

  testWidgets('save slots list the quick save, with stage thumbnails for VN saves', (tester) async {
    final storage = InMemoryStoryStorage();
    SaveSlot slot(int id, Scene scene, StageState stage) => SaveSlot(
          slotId: id,
          conversationKey: "index",
          dialogIndex: 1,
          dataMap: const {},
          history: const [],
          updatedAt: DateTime(2026),
          scene: scene,
          stage: stage,
          chapter: "Prologue",
        );
    await storage.saveSlot(slot(
      SaveSlot.quickSlotId,
      const Scene(),
      StageState(sprites: {SpritePosition.center: ProfileInfo.fromIdentifier("nora:0")}),
    ));
    await storage.saveSlot(slot(1, const Scene(mode: SceneMode.chat), StageState()));
    final setup = StorySetup(config: const LoaderConfig(), loader: FakeEngineLoader(_story), storage: storage);

    await tester.pumpWidget(MaterialApp(home: SaveSlotsScreen(setup: setup, onLoad: (_) {})));
    await tester.pumpAndSettle();

    expect(find.text("Quick save"), findsOneWidget);
    final poi = tester.widget<Poi>(find.byType(Poi));
    expect(poi.actors.single.sprite, endsWith("nora.png"));
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });
}
