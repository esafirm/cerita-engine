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
            {"id": "nora", "name": "Nora", "sprites": ["a.png", "b.png"]},
            {"id": "miki", "name": "Miki", "sprites": ["c.png"]},
          ],
        }),
        conversation: await loadConversation(Conversation.indexKey),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);
}

Map<String, dynamic> _conversation(List<Map<String, dynamic>> items, {String background = "room.png"}) => {
      "conversation_id": "cvn",
      "scene": {"mode": "VN", "background": background, "music": "theme.mp3"},
      "conversations": items,
    };

Map<String, dynamic> _text(String text, {String? id, String profile = "nora:0", String? position}) => {
      "type": "TEXT",
      "text": text,
      "profile": profile,
      "id": ?id,
      "position": ?position,
    };

Future<String?> _nextText(RealFsseEngine engine, {ItemResult? result}) async =>
    (await engine.next(prevResult: result)).getText();

void main() {
  _peekExitTests();
  group('ConditionEvaluator expressions', () {
    test('arithmetic, precedence, unary minus and string concat', () {
      const evaluator = ConditionEvaluator();
      final data = {"a": 3, "b": 4, "name": "Rin"};
      expect(evaluator.value("a + b * 2", data), 11);
      expect(evaluator.value("(a + b) * 2", data), 14);
      expect(evaluator.value("a-1", data), 2);
      expect(evaluator.value("-a + 10", data), 7);
      expect(evaluator.value("b / 2", data), 2);
      expect(evaluator.value("a / 2", data), 1.5);
      expect(evaluator.value("b % 3", data), 1);
      expect(evaluator.value("'Hi ' + name", data), "Hi Rin");
      expect(evaluator.value("missing + 1", data), 1);
      expect(evaluator.evaluate("a * 2 > b + 1", data), isTrue);
      expect(() => evaluator.value("a / 0", data), throwsA(isA<ConditionException>()));
    });

    test('functions', () {
      final evaluator = ConditionEvaluator(Random(1));
      expect(evaluator.value("max(1, 5, 3)", {}), 5);
      expect(evaluator.value("min(2, -4)", {}), -4);
      expect(evaluator.value("abs(-2) + floor(1.7) + ceil(1.2) + round(1.5)", {}), 2 + 1 + 2 + 2);
      for (var i = 0; i < 50; i++) {
        expect(evaluator.value("random(1, 3)", {}), inInclusiveRange(1, 3));
      }
      expect(() => evaluator.value("nope(1)", {}), throwsA(isA<ConditionException>()));
    });

    test('effects take an expr', () {
      final data = <String, dynamic>{"a": 2};
      const Effect("a", EffectOp.set, null, "a * 5").apply(data);
      const Effect("b", EffectOp.add, null, "a + 1").apply(data);
      expect(data, {"a": 10, "b": 11});
    });
  });

  group('Flow', () {
    test('labels, JUMP, SET and same-conversation / cross-conversation targets', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation([
          {"type": "SET", "effects": [{"variable": "n", "op": "set", "value": 1}]},
          {"type": "JUMP", "target": "#later"},
          _text("skipped"),
          _text("later {{n}}", id: "later"),
          {"type": "JUMP", "target": "other#mid", "effects": [{"variable": "n", "op": "add", "value": 1}]},
        ]),
        "other": _conversation([_text("start of other"), _text("mid {{n}}", id: "mid")]),
      }));

      expect(await _nextText(engine), "later 1");
      expect(await _nextText(engine), "mid 2");
      expect(engine.currentConversation!.key, "other");
    });

    test('CALL returns with RETURN or at the end of the called conversation, and nests', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation([
          {"type": "CALL", "target": "sub"},
          _text("back in index"),
          {"type": "CALL", "target": "#local"},
          _text("after local"),
          {"type": "RETURN"},
          _text("local", id: "local"),
          {"type": "RETURN"},
        ]),
        "sub": _conversation([
          _text("in sub"),
          {"type": "CALL", "target": "deep"},
          _text("sub again"),
        ]),
        "deep": _conversation([_text("deep")]),
      }));

      final lines = [for (var i = 0; i < 6; i++) await _nextText(engine)];
      expect(lines, ["in sub", "deep", "sub again", "back in index", "local", "after local"]);
      // RETURN with an empty call stack ends the story.
      expect(engine.next(), throwsA(isA<EndOfStoryException>()));
    });

    test('call stack is saved and restored', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation([{"type": "CALL", "target": "sub"}, _text("returned")]),
        "sub": _conversation([_text("one"), _text("two")]),
      });
      final engine = RealFsseEngine(loader, storage: storage);
      expect(await _nextText(engine), "one");
      await engine.saveTo(1);

      final restored = RealFsseEngine(loader, storage: storage);
      await restored.start(save: await storage.loadSlot(1));
      expect(await _nextText(restored), "two");
      expect(await _nextText(restored), "returned");
    });

    test('a missing label throws', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation([{"type": "JUMP", "target": "#nowhere"}]),
      }));
      expect(engine.next(), throwsException);
    });

    test('once choices disappear after being picked and empty choices are skipped', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation([
          {
            "type": "CHOICE",
            "id": "hub",
            "text": "Ask",
            "choices": [
              {"text": "A", "once": true, "target": "#hub"},
              {"text": "B", "once": true, "target": "#hub"},
            ],
          },
          _text("done"),
        ]),
      });
      final engine = RealFsseEngine(loader, storage: storage);

      var choice = await engine.next() as ChoiceItemType;
      expect(choice.choices.map((c) => c.text), ["A", "B"]);
      choice = await engine.next(prevResult: ItemResult.choice(null, choice.choices[1])) as ChoiceItemType;
      expect(choice.choices.map((c) => c.text), ["A"]);
      expect(choice.choices.single.index, 0);
      expect(await _nextText(engine, result: ItemResult.choice(null, choice.choices.single)), "done");

      // A new playthrough shows both again, flagged as chosen before.
      final replay = RealFsseEngine(loader, storage: storage);
      await replay.start();
      choice = await replay.next() as ChoiceItemType;
      expect(choice.choices.map((c) => c.chosen), [true, true]);
    });
  });

  group('Persistent variables', () {
    test('live in the meta-state, survive new games and interpolate', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation([
          {"type": "SET", "effects": [{"variable": "persistent.runs", "op": "add", "value": 1}]},
          {"type": "TEXT", "text": "Run {{persistent.runs}}", "condition": "persistent.runs > 0"},
        ]),
      });
      final engine = RealFsseEngine(loader, storage: storage);
      expect(await _nextText(engine), "Run 1");
      expect(engine.dataMap, isEmpty);

      final replay = RealFsseEngine(loader, storage: storage);
      expect(await _nextText(replay), "Run 2");
      expect((await storage.loadMeta()).persistent, {"runs": 2});
    });
  });

  group('Stage', () {
    test('STAGE actions and speakers update the stage, which is saved and restored', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation([
          {
            "type": "STAGE",
            "actions": [
              {"action": "show", "profile": "nora:1", "position": "far_left", "transition": "slide_left"},
              {"action": "show", "profile": "miki:0", "position": "right"},
              {"action": "background", "image": "night.png", "transition": "fade_black", "duration_ms": 1200},
              {"action": "music", "file": "night.mp3"},
              {"action": "weather", "name": "rain"},
              {"action": "zoom", "scale": 1.4, "focus": "left"},
            ],
          },
          _text("hi", profile: "miki:0"),
          {
            "type": "STAGE",
            "actions": [
              {"action": "move", "profile": "nora", "position": "center"},
              {"action": "hide", "profile": "miki"},
            ],
          },
          _text("after"),
        ]),
      });
      final engine = RealFsseEngine(loader, storage: storage);

      final stageItem = await engine.next() as StageItemType;
      expect(stageItem.effectiveWaitMs, 1200);
      expect((stageItem.actions.first as ShowAction).transition, StageTransition.slideLeft);
      expect(engine.stage.sprites.map((k, v) => MapEntry(k, v.id)), {
        SpritePosition.farLeft: "nora",
        SpritePosition.right: "miki",
      });
      expect(engine.stage.background, "night.png");
      expect(engine.stage.music, "night.mp3");
      expect(engine.stage.weather, "rain");
      expect(engine.stage.zoom, 1.4);

      await engine.next();
      expect(engine.stage.speakerId, "miki");
      expect(engine.history, hasLength(1), reason: "STAGE items are not in the transcript");
      await engine.saveTo(1);

      await engine.next();
      expect(engine.stage.sprites.map((k, v) => MapEntry(k, v.id)), {SpritePosition.center: "nora"});
      expect(engine.stage.speakerId, isNull);

      final restored = RealFsseEngine(loader, storage: storage);
      await restored.start(save: await storage.loadSlot(1));
      expect(restored.stage.background, "night.png");
      expect(restored.stage.weather, "rain");
      expect(restored.stage.sprites.keys, {SpritePosition.farLeft, SpritePosition.right});
    });

    test('a new scene with another background resets the stage', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation([
          {"type": "STAGE", "actions": [{"action": "weather", "name": "snow"}]},
          _text("one", position: "left"),
          {"type": "JUMP", "target": "same"},
        ]),
        "same": _conversation([_text("two"), {"type": "JUMP", "target": "elsewhere"}]),
        "elsewhere": _conversation([_text("three", profile: "miki:0")], background: "park.png"),
      }));

      await engine.next();
      await engine.next();
      expect(await _nextText(engine), "two");
      expect(engine.stage.weather, "snow");
      expect(engine.stage.slotOf("nora"), SpritePosition.left);

      expect(await _nextText(engine), "three");
      expect(engine.stage.weather, isNull);
      expect(engine.stage.background, "park.png");
      expect(engine.stage.sprites.keys, {SpritePosition.center});
    });

    test('a conversation without a scene keeps the current scene and stage, also after a load', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation([
          {"type": "STAGE", "actions": [{"action": "weather", "name": "rain"}]},
          _text("before", position: "right"),
          {"type": "CALL", "target": "shared#buzz"},
          _text("after"),
        ], background: "cafe.png"),
        "shared": {
          "conversation_id": "cvn_shared",
          "conversations": [
            _text("unused"),
            {"type": "NARRATION", "id": "buzz", "text": "Buzz"},
            {"type": "NARRATION", "text": "Buzz again"},
          ],
        },
      });
      final engine = RealFsseEngine(loader, storage: storage);
      await engine.next();
      await engine.next();
      expect(await _nextText(engine), "Buzz");
      expect(engine.currentScene?.background, "cafe.png");
      expect(engine.stage.weather, "rain");
      expect(engine.stage.slotOf("nora"), SpritePosition.right);
      await engine.saveTo(1);

      final restored = RealFsseEngine(loader, storage: storage);
      await restored.start(save: await storage.loadSlot(1));
      expect(restored.currentScene?.background, "cafe.png");
      expect(await _nextText(restored), "Buzz again");
      expect(await _nextText(restored), "after");
      expect(restored.stage.weather, "rain");
    });

    test('an offstage line keeps the stage as it is and dims everyone on it', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation([
          _text("listening", position: "left"),
          {"type": "TEXT", "text": "on the tape", "profile": "miki:0", "position": "right", "offstage": true},
          {"type": "TEXT", "text": "aside", "profile": "nora:1", "offstage": true},
        ]),
      }));

      expect(await _nextText(engine), "listening");
      final item = await engine.next() as TextItemType;
      expect(item.offstage, isTrue);
      expect(engine.stage.sprites.map((k, v) => MapEntry(k, v.id)), {SpritePosition.left: "nora"});
      expect(engine.stage.speakerId, "miki", reason: "not on stage, so Poi dims everyone");

      await engine.next();
      expect(engine.stage.sprites[SpritePosition.left]?.spriteIndex, 0, reason: "an offstage line changes nothing");
      expect(engine.stage.speakerId, "nora");
    });

    test('a CHOICE speaker is not brought on stage, but one already there changes expression', () async {
      Map<String, dynamic> choice(String profile) => {
            "type": "CHOICE",
            "text": "Well?",
            "profile": profile,
            "choices": [{"text": "Go on"}],
          };
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation([_text("hi", position: "left"), choice("miki:0"), choice("nora:1")]),
      }));

      await engine.next();
      final first = await engine.next() as ChoiceItemType;
      expect(engine.stage.slotOf("miki"), isNull);
      expect(engine.stage.speakerId, "miki");

      await engine.next(prevResult: ItemResult.choice(null, first.choices.single));
      expect(engine.stage.sprites.map((k, v) => MapEntry(k, "${v.id}:${v.spriteIndex}")), {SpritePosition.left: "nora:1"});
      expect(engine.stage.speakerId, "nora");
    });

    test('unknown actions and transitions throw', () {
      expect(() => StageAction.fromJson({"action": "dance"}), throwsException);
      expect(() => StageAction.fromJson({"action": "background", "transition": "spin"}), throwsException);
      expect(() => StageAction.fromJson({"action": "cg_move", "focus": "up"}), throwsException);
    });

    test('a CG stays over the lines after it, a variant keeps its camera, and a new scene takes it away', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation([
          {
            "type": "STAGE",
            "actions": [
              {"action": "cg", "image": "cg_storm.png", "unlock_id": "cg_storm", "focus": "left", "duration_ms": 800},
              {"action": "cg_move", "zoom": 1.3, "focus": "right", "duration_ms": 8000},
            ],
          },
          _text("one"),
          {"type": "STAGE", "actions": [{"action": "cg", "image": "cg_storm_b.png"}]},
          _text("two"),
          {"type": "STAGE", "actions": [{"action": "cg", "image": null}]},
          _text("three"),
          {"type": "STAGE", "actions": [{"action": "cg", "image": "cg_storm.png"}]},
          {"type": "JUMP", "target": "elsewhere"},
        ]),
        "elsewhere": _conversation([_text("four")]),
      });
      final engine = RealFsseEngine(loader, storage: storage);

      final shown = await engine.next() as StageItemType;
      expect(shown.effectiveWaitMs, 800, reason: "the story doesn't wait for a cg_move");
      expect((engine.stage.cg, engine.stage.cgZoom, engine.stage.cgFocus), ("cg_storm.png", 1.3, CgFocus.right));
      expect(engine.meta.unlockedMediaIds, {"cg_storm"});

      expect(await _nextText(engine), "one");
      expect(engine.stage.cg, "cg_storm.png");
      await engine.saveTo(1);

      await engine.next();
      expect((engine.stage.cg, engine.stage.cgZoom, engine.stage.cgFocus), ("cg_storm_b.png", 1.3, CgFocus.right));
      expect(await _nextText(engine), "two");

      await engine.next();
      expect((engine.stage.cg, engine.stage.cgZoom, engine.stage.cgFocus), (null, 1.0, CgFocus.center));
      expect(await _nextText(engine), "three");

      await engine.next();
      expect(engine.stage.cg, "cg_storm.png");
      expect(await _nextText(engine), "four");
      expect(engine.stage.cg, isNull, reason: "a CG never carries into the next scene, even with the same background");

      final restored = RealFsseEngine(loader, storage: storage);
      await restored.start(save: await storage.loadSlot(1));
      expect((restored.stage.cg, restored.stage.cgZoom, restored.stage.cgFocus), ("cg_storm.png", 1.3, CgFocus.right));
    });

    test('a cg action with an unlock id is a Gallery entry', () async {
      final catalog = StoryCatalog([
        Conversation.fromJson(
          _conversation([
            {"type": "MEDIA", "media_type": "CG", "uri": "cg_a.png", "unlock_id": "cg_a"},
            {"type": "STAGE", "actions": [{"action": "cg", "image": "cg_b.png", "unlock_id": "cg_b"}]},
            {"type": "STAGE", "actions": [{"action": "cg", "image": "cg_b2.png"}]},
            {"type": "STAGE", "actions": [{"action": "cg", "image": "cg_b_again.png", "unlock_id": "cg_b"}]},
          ]),
          key: "index",
        ),
      ]);
      expect([for (final entry in catalog.media) (entry.item.unlockId, entry.item.mediaType, entry.item.uri)], [
        ("cg_a", MediaType.cg, "cg_a.png"),
        ("cg_b", MediaType.cg, "cg_b.png"),
      ]);
    });
  });
}

void _peekExitTests() {
  group('peekExit', () {
    Map<String, dynamic> chat(List<Map<String, dynamic>> items, {String channel = "miki"}) => {
      "conversation_id": "cvn",
      "scene": {"mode": "CHAT", "channel_id": channel},
      "conversations": items,
    };

    test('is null while the next item is in the current conversation', () async {
      final engine = RealFsseEngine(
        _FakeEngineLoader({
          "index": _conversation([
            _text("one"),
            {"type": "JUMP", "target": "#three"},
            _text("two"),
            _text("three", id: "three"),
          ]),
        }),
      );
      expect(await _nextText(engine), "one");
      expect(await engine.peekExit(), isNull, reason: "a jump to a label in the same conversation stays");
    });

    test('names the conversation and scene the next item is in, following jumps, branches and calls', () async {
      final engine = RealFsseEngine(
        _FakeEngineLoader({
          "index": _conversation([
            _text("one"),
            {
              "type": "SET",
              "effects": [
                {"variable": "n", "op": "set", "value": 1},
              ],
            },
            {
              "type": "BRANCH",
              "branches": [
                {"condition": "flag == true", "target": "never"},
              ],
              "fallback_target": "hop",
            },
          ]),
          "hop": {
            "conversation_id": "hop",
            "conversations": [
              {"type": "CALL", "target": "thread"},
            ],
          },
          "thread": chat([_text("hey", profile: "miki:0")]),
        }),
      );
      expect(await _nextText(engine), "one");
      final exit = await engine.peekExit();
      expect(exit?.next?.key, "thread");
      expect(exit?.scene?.mode, SceneMode.chat);
      expect(engine.currentConversation!.key, "index", reason: "peeking goes nowhere");
      expect(await _nextText(engine), "hey");
    });

    test('has no next conversation when the story ends first', () async {
      final engine = RealFsseEngine(
        _FakeEngineLoader({
          "index": _conversation([_text("last")]),
        }),
      );
      expect(await _nextText(engine), "last");
      final exit = await engine.peekExit();
      expect(exit, isNotNull);
      expect(exit!.next, isNull);
    });
  });
}
