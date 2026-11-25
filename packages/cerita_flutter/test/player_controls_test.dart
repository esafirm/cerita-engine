import 'dart:convert';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  testWidgets('HIDE hides the dialogue and controls until the next tap, and holds auto mode', (tester) async {
    final (controller, _) = await pumpStory(tester);
    expect(find.text("One"), findsOneWidget);
    controller.toggleAuto();

    await tester.tap(find.byTooltip("Hide"));
    await tester.pump();
    expect(find.text("One"), findsNothing);
    expect(find.byTooltip("Back"), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(controller.current?.getText(), "One", reason: "auto mode waits while the UI is hidden");

    await tester.tap(find.byType(VnStage));
    await tester.pump();
    expect(find.text("One"), findsOneWidget);
    expect(controller.current?.getText(), "One", reason: "the tap that shows the UI doesn't advance");
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Two");
  });

  testWidgets('keyboard: Space advances, Arrow Up rolls back, H hides, Escape opens the menu over the story', (
    tester,
  ) async {
    final (controller, _) = await pumpStory(tester);
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await press(LogicalKeyboardKey.space);
    expect(controller.current?.getText(), "Two");
    await press(LogicalKeyboardKey.arrowUp);
    expect(controller.current?.getText(), "One");

    await press(LogicalKeyboardKey.keyH);
    expect(find.text("One"), findsNothing);
    await press(LogicalKeyboardKey.enter);
    expect(find.text("One"), findsOneWidget);
    expect(controller.current?.getText(), "One", reason: "the key that shows the UI doesn't advance");

    await press(LogicalKeyboardKey.escape);
    expect(find.text("Load game"), findsOneWidget);
    await press(LogicalKeyboardKey.space);
    expect(controller.current?.getText(), "One", reason: "keys go to the open menu, not the story behind it");
    await press(LogicalKeyboardKey.escape);
    expect(find.text("Load game"), findsNothing);
    await press(LogicalKeyboardKey.enter);
    expect(controller.current?.getText(), "Two");

    await press(LogicalKeyboardKey.enter);
    expect(controller.phase, StoryPhase.choice);
    await press(LogicalKeyboardKey.space);
    expect(controller.phase, StoryPhase.choice, reason: "a choice waits for a pick");
  });

  testWidgets('skip stops at the first unread line, and at choices even when skipping unread text', (tester) async {
    final storage = InMemoryStoryStorage();
    await storage.saveMeta(GlobalMetaState(seenItems: {"index#0"}));
    final (controller, setup) = await pumpStory(tester, storage: storage);
    expect(controller.current?.getText(), "One");

    controller.toggleSkip();
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Two");
    expect(controller.skipMode, isFalse, reason: "'Two' was never read in any run");

    await setup.settings.update(setup.settings.value.copyWith(skipUnread: true));
    controller.toggleSkip();
    await tester.pumpAndSettle();
    expect(controller.phase, StoryPhase.choice);
    expect(controller.skipMode, isFalse);
  });

  testWidgets('chat pacing speeds up typing, down to instant', (tester) async {
    Map<String, dynamic> message(String text) =>
        {"type": "TEXT", "text": text, "profile": "nora:0", "typing_delay_ms": 2000};
    final storage = InMemoryStoryStorage();
    await storage.saveSettings(const PlayerSettings(chatPacing: 0.5));
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "cvn",
          "scene": {"mode": "CHAT", "channel_id": "dm"},
          "conversations": [message("Hey"), message("Still there?")],
        },
      }),
      storage: storage,
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    await tester.pump();
    final controller = tester.widget<ChatView>(find.byType(ChatView)).controller;
    expect(controller.phase, StoryPhase.typing);
    await tester.pump(const Duration(milliseconds: 990));
    expect(controller.phase, StoryPhase.typing);
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.current?.getText(), "Hey", reason: "half the story's 2 s");

    await setup.settings.update(setup.settings.value.copyWith(chatPacing: 0));
    await tester.pump(const Duration(milliseconds: 900)); // The pause after a message isn't scaled.
    await tester.pump();
    expect(controller.current?.getText(), "Still there?", reason: "instant: no typing at all");
    await tester.pumpAndSettle();
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

    await prefs.update(prefs.value.copyWith(chatPacing: 0));
    await tester.pumpAndSettle();
    expect(find.text("Instant"), findsOneWidget, reason: "the chat typing row shows the pace");

    await tester.tap(find.text("Reset"));
    await tester.pumpAndSettle();
    expect(prefs.value, const PlayerSettings());
  });

  testWidgets('settings show every slider value on one line in both languages', (tester) async {
    tester.view
      ..physicalSize = const Size(411, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = PlayerPrefs(InMemoryStoryStorage());
    final language = StoryLanguage(locale: "en", locales: const StoryLocales(locales: ["en", "id"]));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => StoryLanguageScope(language: language, child: child!),
      home: SettingsScreen(settings: prefs),
    ));
    await tester.pumpAndSettle();

    Future<void> expectOneLine(String row, String value) async {
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(ListTile, row);
      final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: tile, matching: find.text(value)));
      final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: value.length));
      expect({for (final box in boxes) box.top}, hasLength(1), reason: "$row: $value is on one line");
      final slider = tester.getSize(find.descendant(of: tile, matching: find.byType(Slider)));
      expect(slider.width, greaterThan(200), reason: "$row: the slider keeps most of the row");
    }

    for (final locale in ["en", "id"]) {
      await language.select(locale);
      final strings = language.strings;
      for (final (index, msPerChar) in SettingsScreen.textSpeeds.indexed) {
        await prefs.update(prefs.value.copyWith(textMsPerChar: msPerChar));
        await expectOneLine(strings.textSpeed, strings.textSpeeds[index]);
      }
      for (final (index, pacing) in SettingsScreen.chatPacings.indexed) {
        await prefs.update(prefs.value.copyWith(chatPacing: pacing));
        await expectOneLine(strings.chatPacing, strings.chatPacings[index]);
      }
      await prefs.update(prefs.value.copyWith(autoDelayMs: 3000));
      await expectOneLine(strings.autoForwardDelay, "3.0 s");
      await expectOneLine(strings.music, "100%");
    }
  });

  testWidgets('the newest backlog line clears the bottom system inset', (tester) async {
    tester.view
      ..physicalSize = const Size(411, 900)
      ..devicePixelRatio = 1
      ..viewPadding = const FakeViewPadding(bottom: 48)
      ..padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await pumpStory(tester);
    await advance(tester);

    await tester.tap(find.byTooltip("Backlog"));
    await tester.pumpAndSettle();
    final newest = find.descendant(of: find.byType(BacklogSheet), matching: find.text("Two"));
    expect(tester.getRect(newest).bottom, lessThanOrEqualTo(900 - 48));
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
          chapter: const LocalizedText("Prologue"),
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

  testWidgets('a save made under a held CG shows the CG and the weather in its thumbnail', (tester) async {
    final storage = InMemoryStoryStorage();
    await storage.saveSlot(SaveSlot(
      slotId: 2,
      conversationKey: "index",
      dialogIndex: 1,
      dataMap: const {},
      history: const [],
      updatedAt: DateTime(2026),
      scene: const Scene(),
      stage: StageState(weather: "rain", cg: "cg_storm.png", cgZoom: 1.3, cgFocus: CgFocus.right),
    ));
    final setup = StorySetup(config: const LoaderConfig(), loader: FakeEngineLoader(_story), storage: storage);

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _PixelBundle(),
        child: MaterialApp(home: SaveSlotsScreen(setup: setup, onLoad: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    final poi = tester.widget<Poi>(find.byType(Poi));
    expect(
      (poi.cg, poi.cgZoom, poi.cgFocus, poi.weather),
      ("assets/story/bg/cg_storm.png", 1.3, CgFocus.right, "rain"),
    );
    expect(find.byType(WeatherLayer), findsOneWidget);
  });

  testWidgets('saving over a slot in use asks first, and a save can be deleted', (tester) async {
    final storage = InMemoryStoryStorage();
    final setup = StorySetup(config: const LoaderConfig(), loader: FakeEngineLoader(_story), storage: storage);
    var saves = 0;
    Future<void> save(int id) => storage.saveSlot(SaveSlot(
          slotId: id,
          conversationKey: "index",
          dialogIndex: ++saves,
          dataMap: const {},
          history: const [],
          updatedAt: DateTime(2026),
        ));
    await tester.pumpWidget(MaterialApp(home: SaveSlotsScreen(setup: setup, onSave: save, slots: const [1, 2])));
    await tester.pumpAndSettle();
    expect(find.text("Slot 3"), findsNothing);

    await tester.tap(find.text("Slot 1"));
    await tester.pumpAndSettle();
    expect(find.text("Overwrite save?"), findsNothing, reason: "an empty slot saves at once");
    expect(saves, 1);

    await tester.tap(find.text("Slot 1"));
    await tester.pumpAndSettle();
    expect(find.text("Overwrite save?"), findsOneWidget);
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();
    expect(saves, 1);

    await tester.tap(find.text("Slot 1"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Overwrite"));
    await tester.pumpAndSettle();
    expect((await storage.loadSlot(1))!.dialogIndex, 2);

    await tester.tap(find.byTooltip("Delete save"));
    await tester.pumpAndSettle();
    expect(find.text("Delete the save in Slot 1? This can't be undone."), findsOneWidget);
    await tester.tap(find.text("Delete"));
    await tester.pumpAndSettle();
    expect(await storage.loadSlot(1), isNull);
    expect(find.byTooltip("Delete save"), findsNothing);
  });
}

/// Serves a 1×1 PNG for any asset.
class _PixelBundle extends CachingAssetBundle {
  static final _pixel = base64Decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  );

  @override
  Future<ByteData> load(String key) async {
    if (key == "AssetManifest.bin") return const StandardMessageCodec().encodeMessage(<String, Object?>{})!;
    return ByteData.sublistView(_pixel);
  }
}
