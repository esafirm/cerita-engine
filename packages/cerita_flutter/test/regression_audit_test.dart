import 'dart:async';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

void main() {
  setUp(mockAudioChannels);
  testWidgets('RouteFlowchart handles empty RouteMap without negative height crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteFlowchart(
            map: RouteMap(const StoryGraph([])),
            meta: GlobalMetaState(),
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('StoryLanguage.stringsFor resolves regional locale tags to base language', () {
    final language = StoryLanguage();
    expect(language.stringsFor("id-ID").settings, CeritaStrings.id.settings);
    expect(language.stringsFor("en-US").settings, CeritaStrings.en.settings);
  });

  testWidgets('SettingsScreen reset preserves developerTools toggle', (tester) async {
    final storage = InMemoryStoryStorage();
    final prefs = PlayerPrefs(storage);
    await prefs.update(const PlayerSettings(developerTools: true, textMsPerChar: 80));

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: prefs)));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Reset"));
    await tester.pumpAndSettle();

    expect(prefs.value.textMsPerChar, const PlayerSettings().textMsPerChar);
    expect(prefs.value.developerTools, isTrue);
  });

  test('SharedPrefsStoryStorage isolates dotted namespaces', () async {
    SharedPreferences.setMockInitialValues({});
    final parent = SharedPrefsStoryStorage(namespace: "story");
    final child = SharedPrefsStoryStorage(namespace: "story.demo");

    final slot = SaveSlot(
      slotId: 1,
      conversationKey: "index",
      dialogIndex: 0,
      dataMap: const {},
      history: const [],
      updatedAt: DateTime(2026),
    );
    await parent.saveSlot(slot);
    await child.saveSlot(slot.copyWith(slotId: 2));

    expect((await parent.listSlots()).map((s) => s.slotId), [1]);
    expect((await child.listSlots()).map((s) => s.slotId), [2]);

    await parent.clear();
    expect(await parent.listSlots(), isEmpty);
    expect((await child.listSlots()).map((s) => s.slotId), [2]);
  });

  testWidgets('InputPrompt clears text when item changes', (tester) async {
    final first = InputItemType.fromJson({"type": "INPUT", "text": "First?", "variable": "A"});
    final second = InputItemType.fromJson({"type": "INPUT", "text": "Second?", "variable": "B"});

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InputPrompt(item: first, onSubmit: (_) {}))));
    await tester.enterText(find.byType(TextField), "hello");
    expect(find.text("hello"), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InputPrompt(item: second, onSubmit: (_) {}))));
    expect(find.text("hello"), findsNothing);
  });

  test('PlayerPrefs.load does not overwrite a concurrent update', () async {
    final storage = _DelayedPrefsStorage(const PlayerSettings(textMsPerChar: 80));
    final prefs = PlayerPrefs(storage);
    final loading = prefs.load();
    await prefs.update(const PlayerSettings(textMsPerChar: 15));
    await loading;
    expect(prefs.value.textMsPerChar, 15);
  });

  test('StoryController holdStory is refcounted and ignores calls after dispose', () async {
    final controller = StoryController(
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "index",
          "conversations": [
            {"type": "TEXT", "text": "Hi"},
          ],
        },
      }),
      storage: InMemoryStoryStorage(),
      config: const LoaderConfig(),
      settings: PlayerPrefs(InMemoryStoryStorage()),
      audio: SilentAudio(),
    );
    controller.holdStory(true);
    controller.holdStory(true);
    expect(controller.storyHeld, isTrue);
    controller.holdStory(false);
    expect(controller.storyHeld, isTrue);
    controller.holdStory(false);
    expect(controller.storyHeld, isFalse);

    controller.dispose();
    // Must not throw or schedule timers on a disposed controller.
    controller.holdStory(true);
    controller.holdStory(false);
  });

  test('declining a ringing call does not commit its first item', () async {
    final storage = InMemoryStoryStorage();
    final controller = StoryController(
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "index",
          "scene": {"mode": "CALL", "ring": "ring.mp3", "hangup": "after"},
          "conversations": [
            {
              "type": "TEXT",
              "text": "Unheard",
              "effects": [
                {"variable": "heard_call", "op": "set", "value": true},
              ],
            },
          ],
        },
        "after": {
          "conversation_id": "after",
          "scene": {"mode": "VN"},
          "conversations": [
            {"type": "TEXT", "text": "Declined"},
          ],
        },
      }),
      storage: storage,
      config: const LoaderConfig(),
      settings: PlayerPrefs(storage),
      audio: SilentAudio(),
    );
    await controller.start();
    expect(controller.callState, CallState.ringing);
    expect(controller.dataMap["heard_call"], isNull);
    expect(controller.history, isEmpty);
    expect((await storage.loadMeta()).seenItems, isEmpty);

    await controller.jumpTo("after");
    expect(controller.dataMap["heard_call"], isNull);
    expect(controller.current?.getText(), "Declined");
    controller.dispose();
  });

  test('visibleChannelHistory caches across rebuilds and updates incrementally on new messages', () async {
    final storage = InMemoryStoryStorage();
    final controller = StoryController(
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "index",
          "scene": {"mode": "CHAT", "channel_id": "c1"},
          "conversations": [
            {"type": "TEXT", "text": "First"},
            {"type": "TEXT", "text": "Second"},
          ],
        },
      }),
      storage: storage,
      config: const LoaderConfig(),
      settings: PlayerPrefs(storage),
      audio: SilentAudio(),
    );
    await controller.start();
    final a = controller.visibleChannelHistory("c1");
    final b = controller.visibleChannelHistory("c1");
    expect(identical(a, b), isTrue);
    expect(a.length, 1);

    await controller.advance();
    final c = controller.visibleChannelHistory("c1");
    expect(c.length, 2);
    expect(identical(c, controller.visibleChannelHistory("c1")), isTrue);
    controller.dispose();
  });

  test('skip mode defers autosave until stopped or flushed', () async {
    final storage = _CountingStorage();
    final settings = PlayerPrefs(storage);
    await settings.update(const PlayerSettings(skipUnread: true));
    final controller = StoryController(
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "index",
          "conversations": [
            {"type": "TEXT", "text": "One"},
            {"type": "TEXT", "text": "Two"},
            {"type": "TEXT", "text": "Three"},
          ],
        },
      }),
      storage: storage,
      config: const LoaderConfig(),
      settings: settings,
      audio: SilentAudio(),
    );
    await controller.start();
    expect(storage.slotSaves, 1);
    controller.toggleSkip();
    await controller.advance();
    await controller.advance();
    // No per-line autosave writes while skipMode is active.
    expect(storage.slotSaves, 1);

    controller.toggleSkip();
    await Future<void>.delayed(Duration.zero);
    expect(storage.slotSaves, 2);
    expect((await storage.loadMeta()).seenItems, containsAll(["index#0", "index#1", "index#2"]));
    controller.dispose();
  });

  test('StorySetup.assets forwards custom settings and audio factory', () {
    final storage = InMemoryStoryStorage();
    final prefs = PlayerPrefs(storage);
    final customAudio = SilentAudio();
    final setup = StorySetup.assets(storage: storage, settings: prefs, audio: () => customAudio);
    expect(identical(setup.settings, prefs), isTrue);
    expect(identical(setup.audio(), customAudio), isTrue);
  });

  test('loading a save made while a call is ringing keeps it ringing without running item 0', () async {
    final storage = InMemoryStoryStorage();
    final loader = FakeEngineLoader({
      "index": {
        "conversation_id": "index",
        "scene": {"mode": "CALL", "ring": "ring.mp3"},
        "conversations": [
          {
            "type": "TEXT",
            "text": "Unheard",
            "effects": [
              {"variable": "heard", "op": "set", "value": true},
            ],
          },
        ],
      },
    });
    final controller = StoryController(
      loader: loader,
      storage: storage,
      config: const LoaderConfig(),
      settings: PlayerPrefs(storage),
      audio: SilentAudio(),
    );
    await controller.start();
    expect(controller.callState, CallState.ringing);
    await controller.saveTo(1);
    final saved = (await storage.loadSlot(1))!;
    controller.dispose();

    final restored = StoryController(
      loader: loader,
      storage: storage,
      config: const LoaderConfig(),
      settings: PlayerPrefs(storage),
      audio: SilentAudio(),
    );
    await restored.start(save: saved);
    expect(restored.callState, CallState.ringing);
    expect(restored.dataMap["heard"], isNull);
    restored.dispose();
  });

  test('flushPendingAutoSave during a pending async gate persists the pre-jump clean snapshot', () async {
    final storage = InMemoryStoryStorage();
    final settings = PlayerPrefs(storage);
    await settings.update(const PlayerSettings(skipUnread: true));
    final gateReady = Completer<bool>();
    final gateEntered = Completer<void>();
    final controller = StoryController(
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "index",
          "conversations": [
            {"type": "TEXT", "text": "Line 1"},
            {"type": "TEXT", "text": "Line 2"},
            {"type": "JUMP", "target": "paid"},
          ],
        },
        "paid": {
          "conversation_id": "paid",
          "conversations": [
            {"type": "TEXT", "text": "Paid"},
          ],
        },
      }),
      storage: storage,
      config: const LoaderConfig(),
      settings: settings,
      audio: SilentAudio(),
      gate: (conversation) async {
        if (conversation.key == "paid") {
          gateEntered.complete();
          return gateReady.future;
        }
        return true;
      },
    );
    await controller.start();
    controller.toggleSkip();
    await controller.advance(); // Line 2, deferred clean snapshot at dialogIndex 2 (pointing to JUMP)

    final enteringGate = controller.advance(); // Starts JUMP -> pauses inside async gate (dialogIndex is now 3!)
    await gateEntered.future;

    // Backgrounding the app while gate is pending must save the clean snapshot (dialogIndex 2), not 3!
    await controller.flushPendingAutoSave();
    gateReady.complete(false);
    await enteringGate;

    final auto = (await storage.loadSlot(SaveSlot.autoSlotId))!;
    expect(auto.conversationKey, "index");
    expect(auto.dialogIndex, 2);
    controller.dispose();
  });

  test('entering a ringing call updates autosave to the ringing call instead of keeping a stale deferred slot', () async {
    final storage = InMemoryStoryStorage();
    final settings = PlayerPrefs(storage);
    await settings.update(const PlayerSettings(skipUnread: true));
    final controller = StoryController(
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "index",
          "scene": {"mode": "VN"},
          "conversations": [
            {"type": "TEXT", "text": "Line 1"},
            {"type": "TEXT", "text": "Line 2"},
            {"type": "JUMP", "target": "call_in"},
          ],
        },
        "call_in": {
          "conversation_id": "call_in",
          "scene": {"mode": "CALL", "ring": "ring.mp3"},
          "conversations": [
            {"type": "TEXT", "text": "Hello?"},
          ],
        },
      }),
      storage: storage,
      config: const LoaderConfig(),
      settings: settings,
      audio: SilentAudio(),
    );
    await controller.start();
    controller.toggleSkip();
    await controller.advance(); // Line 2 buffered in _pendingAutoSave
    controller.toggleSkip(); // Stop skip before entering ringing call
    await controller.advance(); // Enters call_in and rings

    expect(controller.callState, CallState.ringing);
    await controller.flushPendingAutoSave();
    final auto = (await storage.loadSlot(SaveSlot.autoSlotId))!;
    expect(auto.conversationKey, "call_in");
    expect(auto.dialogIndex, 0);
    controller.dispose();
  });
}

class _CountingStorage extends InMemoryStoryStorage {
  int slotSaves = 0;

  @override
  Future<void> saveSlot(SaveSlot slot) {
    slotSaves++;
    return super.saveSlot(slot);
  }
}

class _DelayedPrefsStorage extends InMemoryStoryStorage {
  final PlayerSettings stored;

  _DelayedPrefsStorage(this.stored);

  @override
  Future<PlayerSettings> loadSettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return stored;
  }
}
