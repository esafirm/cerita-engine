import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

class _FakeEngineLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  _FakeEngineLoader(this.files);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "nora", "name": "Nora", "sprites": ["a.png"]},
            {"id": "miki", "name": "Miki", "sprites": ["c.png"]},
          ],
        }),
        conversation: await loadConversation(Conversation.indexKey),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);

  @override
  Future<List<String>> listConversationKeys() async => files.keys.toList();
}

/// Counts up, so every roll differs from the one before.
class _CountingRandom implements Random {
  int _next;

  _CountingRandom([this._next = 0]);

  @override
  int nextInt(int max) => _next++ % max;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

class _Listener with EngineListener {
  final scenes = <Scene>[];
  final conversations = <String>[];

  @override
  void onNewScene(Scene scene) => scenes.add(scene);

  @override
  void onConversationStarted(Conversation conversation) => conversations.add(conversation.key);
}

Map<String, dynamic> _conversation(
  List<Map<String, dynamic>> items, {
  String mode = "VN",
  String background = "room.png",
  String? music = "theme.mp3",
  String? chapter,
  bool scene = true,
}) =>
    {
      "conversation_id": "cvn",
      "chapter": ?chapter,
      if (scene) "scene": {"mode": mode, "background": background, "music": ?music},
      "conversations": items,
    };

Map<String, dynamic> _text(String text, {String profile = "nora:0", List<Map<String, dynamic>>? effects}) =>
    {"type": "TEXT", "text": text, "profile": profile, "effects": ?effects};

Map<String, dynamic> _add(String variable, int value) => {"variable": variable, "op": "add", "value": value};

RealFsseEngine _engine(Map<String, Map<String, dynamic>> files, {StoryStorage? storage, EngineListener? listener}) =>
    RealFsseEngine(_FakeEngineLoader(files), storage: storage, listener: listener);

Future<String?> _nextText(RealFsseEngine engine, {ItemResult? result}) async =>
    (await engine.next(prevResult: result)).getText();

void main() {
  group('Rollback', () {
    test('goes back one line with its variables and transcript, then plays forward again', () async {
      final engine = _engine({
        "index": _conversation([
          _text("one", effects: [_add("n", 1)]),
          _text("two", effects: [_add("n", 1)]),
          _text("three", effects: [_add("n", 1)]),
        ]),
      });
      await engine.next();
      await engine.next();
      await engine.next();
      expect(engine.dataMap["n"], 3);

      expect(engine.canRollback(), isTrue);
      expect(engine.rollback()?.getText(), "two");
      expect(engine.dataMap["n"], 2);
      expect(engine.history.map((e) => e.itemType?.getText()), ["one", "two"]);

      expect(engine.rollback()?.getText(), "one");
      expect(engine.canRollback(), isFalse);
      expect(engine.rollback(), isNull);

      expect(await _nextText(engine), "two");
      expect(await _nextText(engine), "three");
      expect(engine.dataMap["n"], 3);
    });

    test('a choice can be picked again with a different result', () async {
      final engine = _engine({
        "index": _conversation([
          {
            "type": "CHOICE",
            "text": "Pick",
            "choices": [
              {"text": "Kind", "effects": [_add("trust", 1)]},
              {"text": "Rude", "effects": [_add("trust", -1)]},
            ],
          },
          _text("Trust {{trust}}"),
        ]),
      });
      final choice = await engine.next() as ChoiceItemType;
      expect(await _nextText(engine, result: ItemResult.choice(null, choice.choices[0])), "Trust 1");

      final again = engine.rollback() as ChoiceItemType;
      expect(again.text, "Pick");
      expect(engine.dataMap.containsKey("trust"), isFalse);
      expect(await _nextText(engine, result: ItemResult.choice(null, again.choices[1])), "Trust -1");
      expect(engine.history.where((e) => e.isPlayer).map((e) => e.playerText.toString()), ["Rude"]);
    });

    test('restores the stage and scene of an earlier conversation and tells the listener', () async {
      final listener = _Listener();
      final engine = _engine({
        "index": _conversation([
          {
            "type": "STAGE",
            "actions": [
              {"action": "show", "profile": "miki:0", "position": "left"},
            ],
          },
          _text("Hi", profile: "nora:0"),
          {"type": "JUMP", "target": "street"},
        ]),
        "street": _conversation([_text("Outside")], background: "street.png", music: "night.mp3"),
      }, listener: listener);

      expect(await _nextText(engine), isNull); // STAGE
      expect(await _nextText(engine), "Hi");
      expect(await _nextText(engine), "Outside");
      expect(engine.stage.background, "street.png");
      expect(engine.stage.sprites, hasLength(1));

      // The STAGE item is passed over: "Hi" is the previous line.
      expect(engine.rollback()?.getText(), "Hi");
      expect(engine.currentConversation!.key, "index");
      expect(engine.currentScene!.background, "room.png");
      expect(engine.stage.background, "room.png");
      expect(engine.stage.sprites.values.map((info) => info.id), unorderedEquals(["miki", "nora"]));
      expect(listener.scenes.last.background, "room.png");
      expect(listener.conversations.last, "index");
      expect(engine.canRollback(), isFalse);
    });

    test('rolls back to a transcript index, but not into a chat thread', () async {
      final engine = _engine({
        "index": _conversation([_text("chat line"), {"type": "JUMP", "target": "vn"}], mode: "CHAT"),
        "vn": _conversation([_text("a"), _text("b"), _text("c")]),
      });
      for (var i = 0; i < 4; i++) {
        await engine.next();
      }
      final indexOfA = engine.history.indexWhere((e) => e.itemType?.getText() == "a");
      expect(engine.canRollback(historyIndex: indexOfA), isTrue);
      expect(engine.canRollback(historyIndex: 0), isFalse);

      expect(engine.rollback(historyIndex: indexOfA)?.getText(), "a");
      expect(engine.canRollback(), isFalse);
      expect(await _nextText(engine), "b");
    });

    test('keeps the meta-state', () async {
      final storage = InMemoryStoryStorage();
      final engine = _engine({
        "index": _conversation([
          _text("one"),
          {"type": "SET", "effects": [_add("persistent.runs", 1)]},
          _text("two"),
        ]),
      }, storage: storage);
      await engine.next();
      await engine.next();
      engine.rollback();
      expect(engine.meta.seenItems, containsAll(["index#0", "index#2"]));
      expect(engine.state["persistent.runs"], 1);
      expect(await _nextText(engine), "two");
      expect(engine.lastItemPreviouslySeen, isTrue);
      expect(engine.state["persistent.runs"], 2);
    });

    test('reaches back past a loaded save, into an earlier conversation and to a pending choice', () async {
      final storage = InMemoryStoryStorage();
      final files = {
        "index": _conversation([_text("one"), {"type": "JUMP", "target": "street"}]),
        "street": _conversation([
          _text("two"),
          {
            "type": "CHOICE",
            "text": "Pick",
            "choices": [
              {"text": "Kind"},
              {"text": "Secret", "condition": "trust > 5"},
            ],
          },
          _text("three"),
        ], background: "street.png"),
      };
      final first = _engine(files, storage: storage);
      await first.next();
      await first.next();
      await first.next(); // The choice, still waiting for an answer.
      await first.saveTo(1);

      final engine = _engine(files, storage: storage);
      await engine.start(save: await storage.loadSlot(1));
      final choice = await engine.next() as ChoiceItemType;
      expect(await _nextText(engine, result: ItemResult.choice(null, choice.choices[0])), "three");
      await engine.saveTo(1);

      final loaded = _engine(files, storage: storage);
      await loaded.start(save: await storage.loadSlot(1));
      final again = loaded.rollback() as ChoiceItemType;
      expect(again.choices.map((c) => (c.text, c.locked)), [("Kind", false), ("Secret", true)]);
      expect(loaded.rollback()?.getText(), "two");
      expect(loaded.rollback()?.getText(), "one");
      expect(loaded.currentConversation!.key, "index");
      expect(loaded.stage.background, "room.png");
      expect(loaded.canRollback(), isFalse);
      expect(await _nextText(loaded), "two");
    });

    test('random() gives the same result after rolling back, also after a load', () async {
      final storage = InMemoryStoryStorage();
      final files = {
        "index": _conversation([
          _text("before"),
          _text("Dice {{dice}}", effects: [
            {"variable": "dice", "op": "set", "expr": "random(1, 100)"},
          ]),
        ]),
      };
      final engine = RealFsseEngine(_FakeEngineLoader(files),
          storage: storage, evaluator: ConditionEvaluator(_CountingRandom()));
      await engine.next();
      expect(await _nextText(engine), "Dice 1");
      engine.rollback();
      expect(await _nextText(engine), "Dice 1");
      await engine.saveTo(1);

      final loaded = RealFsseEngine(_FakeEngineLoader(files),
          storage: storage, evaluator: ConditionEvaluator(_CountingRandom(50)));
      await loaded.start(save: await storage.loadSlot(1));
      expect(loaded.rollback()?.getText(), "before");
      expect(await _nextText(loaded), "Dice 1");
    });
  });

  group('Replay', () {
    final files = {
      "index": _conversation([_text("prologue"), {"type": "JUMP", "target": "day1"}], chapter: "Prologue"),
      "day1": _conversation(
        [
          _text("day one"),
          {"type": "CALL", "target": "shared"},
          {"type": "JUMP", "target": "call"},
        ],
        chapter: "Day 1",
        mode: "CHAT",
      ),
      "shared": _conversation([_text("buzz")], scene: false),
      "call": _conversation([_text("ring"), {"type": "JUMP", "target": "day2"}], chapter: "Day 1", mode: "CALL"),
      "day2": _conversation([_text("day two")], chapter: "Day 2"),
    };

    test('plays one chapter, through subroutines and same-chapter conversations', () async {
      final storage = InMemoryStoryStorage();
      final full = _engine(files, storage: storage);
      for (var i = 0; i < 5; i++) {
        await full.next();
      }
      final checkpoint = Checkpoint(conversationKey: "day1", dataMap: const {"x": 1}, unlockedAt: DateTime(2026));

      final engine = _engine(files, storage: storage);
      await engine.start(checkpoint: checkpoint, replay: true);
      expect(engine.replaying, isTrue);
      expect(engine.dataMap["x"], 1);
      expect(await _nextText(engine), "day one");
      expect(await _nextText(engine), "buzz");
      expect(await _nextText(engine), "ring");
      await expectLater(engine.next(), throwsA(isA<EndOfStoryException>()));
    });

    test('a normal checkpoint start keeps going', () async {
      final engine = _engine(files);
      await engine.start(
        checkpoint: Checkpoint(conversationKey: "call", dataMap: const {}, unlockedAt: DateTime(2026)),
      );
      expect(engine.replaying, isFalse);
      expect(await _nextText(engine), "ring");
      expect(await _nextText(engine), "day two");
    });
  });

  test('stage music is recorded for the music room', () async {
    final storage = InMemoryStoryStorage();
    final files = {
      "index": _conversation([
        _text("a"),
        {
          "type": "STAGE",
          "actions": [
            {"action": "music", "file": "tense.mp3"},
          ],
        },
        _text("b"),
        {"type": "JUMP", "target": "never"},
      ]),
      "never": _conversation([_text("c")], music: "ending.mp3"),
    };
    final engine = _engine(files, storage: storage);
    await engine.next();
    await engine.next();
    await engine.next();

    expect((await storage.loadMeta()).heardMusic, {"theme.mp3", "tense.mp3"});
    final catalog = await StoryCatalog.load(_FakeEngineLoader(files));
    expect(catalog.music, ["theme.mp3", "tense.mp3", "ending.mp3"]);
  });

  group('PlayerSettings', () {
    test('round-trips through JSON, clamps volumes and survives a progress reset', () async {
      const settings = PlayerSettings(textMsPerChar: 0, autoDelayMs: 2400, skipUnread: true, musicVolume: 0.3);
      expect(PlayerSettings.fromJson(settings.toJson()), settings);
      expect(PlayerSettings.fromJson({"voice_volume": 4}).voiceVolume, 1);
      expect(PlayerSettings.fromJson({}), const PlayerSettings());
      expect(settings.autoDelayFor(10), 2400 + 10 * 90);

      // Chat pacing speeds chats up, never slows them down (CE-04 D2). Settings saved before it keep the story pace.
      expect(PlayerSettings.fromJson({}).chatTypingFor(1500), 1500);
      expect(PlayerSettings.fromJson(const PlayerSettings(chatPacing: 0.25).toJson()).chatTypingFor(1500), 375);
      expect(PlayerSettings.fromJson({"chat_pacing": 3}).chatPacing, 1);
      expect(const PlayerSettings(chatPacing: -1).chatTypingFor(1500), 0);

      // Developer tools are off unless turned on, and only written when on.
      expect(PlayerSettings.fromJson({}).developerTools, isFalse);
      expect(const PlayerSettings().toJson(), isNot(contains("developer_tools")));
      expect(PlayerSettings.fromJson(const PlayerSettings(developerTools: true).toJson()).developerTools, isTrue);
      expect(const PlayerSettings(developerTools: true), isNot(const PlayerSettings()));

      final storage = InMemoryStoryStorage();
      expect(await storage.loadSettings(), const PlayerSettings());
      await storage.saveSettings(settings);
      await storage.clear();
      expect(await storage.loadSettings(), settings);
    });
  });
}
