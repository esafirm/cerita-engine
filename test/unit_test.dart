import 'package:flutter_test/flutter_test.dart';
import 'package:fsse/fsse.dart';

class _FakeEngineLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  _FakeEngineLoader(this.files);

  @override
  Future<EnginePackage> initialLoad() async {
    return EnginePackage(
      profiles: ProfileData.fromJson({
        "profiles": [
          {
            "id": "123aaa",
            "name": "Nora",
            "sprites": ["nora_open.png", "nora_smile.png"],
          },
        ],
      }),
      conversation: await loadConversation(Conversation.indexKey),
    );
  }

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);

  @override
  Future<List<String>> listConversationKeys() async => files.keys.toList();
}

Map<String, dynamic> _conversation(String id, List<Map<String, dynamic>> items, {bool checkpoint = false}) => {
      "conversation_id": "cvn_$id",
      "chapter": id,
      "checkpoint": checkpoint,
      "scene": {"mode": "CHAT", "channel_id": "thread", "day": 1},
      "conversations": items,
    };

Map<String, dynamic> _text(String text, {String? condition, List<Map<String, dynamic>>? effects}) => {
      "type": "TEXT",
      "text": text,
      "profile": "123aaa:1",
      "condition": ?condition,
      "effects": ?effects,
    };

void main() {
  group('VariableReplacer', () {
    test('replaces placeholders with values from dataMap', () {
      const template = "Hi my name is {{NAME}} {{HAHA}} {{trust_2}}";
      final data = {'NAME': 'TikTok', 'HAHA': 'Ketawa', 'trust_2': 5};
      expect(template.replaceWithVars(data), "Hi my name is TikTok Ketawa 5");
    });

    test('throws when placeholder variable is missing', () {
      const template = "Hello {{MISSING}}";
      expect(() => template.replaceWithVars({}), throwsException);
    });

    test('interpolates text fields but not logic fields', () {
      final json = interpolateItemJson({
        "type": "CHOICE",
        "text": "Hi {{NAME}}",
        "condition": "NAME == '{{NAME}}'",
        "choices": [
          {"text": "I am {{NAME}}", "value": "{{NAME}}", "target": "{{NAME}}"},
        ],
      }, {"NAME": "Alex"});

      expect(json["text"], "Hi Alex");
      expect(json["condition"], "NAME == '{{NAME}}'");
      expect(json["choices"][0], {"text": "I am Alex", "value": "Alex", "target": "{{NAME}}"});
    });
  });

  group('ConditionEvaluator', () {
    const evaluator = ConditionEvaluator();
    final data = {"trust": 12, "PILL": "Blue", "has_photo": true, "ratio": 0.5};

    test('comparisons and logic operators', () {
      expect(evaluator.evaluate("trust >= 10", data), isTrue);
      expect(evaluator.evaluate("trust > 12", data), isFalse);
      expect(evaluator.evaluate("PILL == 'Blue'", data), isTrue);
      expect(evaluator.evaluate('PILL != "Red"', data), isTrue);
      expect(evaluator.evaluate("trust > 0 && has_photo == true", data), isTrue);
      expect(evaluator.evaluate("trust > 100 || has_photo", data), isTrue);
      expect(evaluator.evaluate("!(trust < 5) && ratio <= 0.5", data), isTrue);
      expect(evaluator.evaluate("!has_photo", data), isFalse);
    });

    test('unset variables default to 0, false or empty string', () {
      expect(evaluator.evaluate("missing == 0", data), isTrue);
      expect(evaluator.evaluate("missing < 1", data), isTrue);
      expect(evaluator.evaluate("missing == false", data), isTrue);
      expect(evaluator.evaluate("missing", data), isFalse);
      expect(evaluator.evaluate("missing != 'Blue'", data), isTrue);
    });

    test('empty condition is true and malformed condition throws', () {
      expect(evaluator.evaluate(null, data), isTrue);
      expect(evaluator.evaluate("  ", data), isTrue);
      expect(() => evaluator.evaluate("trust >=", data), throwsA(isA<ConditionException>()));
      expect(() => evaluator.evaluate("(trust > 1", data), throwsA(isA<ConditionException>()));
    });
  });

  group('Effect', () {
    test('set, add, subtract and toggle', () {
      final data = <String, dynamic>{};
      const Effect("name", EffectOp.set, "Miki").apply(data);
      const Effect("trust", EffectOp.add, 5).apply(data);
      const Effect("trust", EffectOp.subtract, 2).apply(data);
      const Effect("flag", EffectOp.toggle).apply(data);
      expect(data, {"name": "Miki", "trust": 3, "flag": true});

      Effect.fromJson({"variable": "flag", "op": "toggle"}).apply(data);
      expect(data["flag"], isFalse);
    });
  });

  group('RealFsseEngine', () {
    test('progresses through items, stores variables, and loads target conversation', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation("index", [
          {"type": "INPUT", "text": "What is your name?", "variable": "NAME", "default_value": "Alex"},
          _text("Hello {{NAME}}"),
          {
            "type": "CHOICE",
            "text": "Pick one",
            "variable": "CHOICE",
            "choices": [
              {"text": "Go next", "value": "A", "target": "target_2"},
            ],
          },
        ]),
        "target_2": _conversation("target_2", [_text("Branched to {{CHOICE}}")]),
      }));

      final first = await engine.next();
      expect(first, isA<InputItemType>());
      expect((first as InputItemType).defaultValue, "Alex");

      final second = await engine.next(prevResult: const ItemResult.input("NAME", "Nora"));
      expect(second.getText(), "Hello Nora");
      expect(engine.getProfile(second)?.name, "Nora");

      final third = await engine.next() as ChoiceItemType;
      final branched = await engine.next(prevResult: ItemResult.choice(third.variable, third.choices.first));
      expect(branched.getText(), "Branched to A");
      expect(engine.getDataMap(), {"NAME": "Nora", "CHOICE": "A"});
      expect(engine.history.where((e) => e.isPlayer).map((e) => e.playerText), ["Nora", "Go next"]);
    });

    test('skips items whose condition fails and applies item effects', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation("index", [
          _text("hidden", condition: "trust > 0"),
          _text("gain", effects: [
            {"variable": "trust", "op": "add", "value": 5},
          ]),
          _text("visible {{trust}}", condition: "trust > 0"),
        ]),
      }));

      expect((await engine.next()).getText(), "gain");
      expect((await engine.next()).getText(), "visible 5");
      expect(engine.next(), throwsA(isA<EndOfStoryException>()));
    });

    test('choice effects apply and conditional choices are locked', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation("index", [
          {
            "type": "CHOICE",
            "text": "Reply?",
            "timeout_ms": 1000,
            "default_choice": 2,
            "choices": [
              {
                "text": "Kind",
                "effects": [
                  {"variable": "trust", "op": "add", "value": 5},
                ],
              },
              {"text": "Rude"},
              {"text": "Secret", "condition": "has_photo == true"},
            ],
          },
          _text("trust is {{trust}}"),
        ]),
      }));

      final choice = await engine.next() as ChoiceItemType;
      expect(choice.choices.map((c) => c.locked), [false, false, true]);
      expect(choice.timeoutChoice?.text, "Kind");

      final after = await engine.next(prevResult: ItemResult.choice(null, choice.choices.first));
      expect(after.getText(), "trust is 5");
    });

    test('BRANCH routes to the first matching target or fallback', () async {
      Map<String, Map<String, dynamic>> files(int trust) => {
            "index": _conversation("index", [
              {
                "type": "TEXT",
                "text": "start",
                "effects": [
                  {"variable": "trust", "op": "set", "value": trust},
                ],
              },
              {
                "type": "BRANCH",
                "branches": [
                  {"condition": "trust >= 20", "target": "end_true"},
                  {"condition": "trust >= 10", "target": "end_good"},
                ],
                "fallback_target": "end_bad",
              },
            ]),
            "end_true": _conversation("end_true", [_text("true")]),
            "end_good": _conversation("end_good", [_text("good")]),
            "end_bad": _conversation("end_bad", [_text("bad")]),
          };

      for (final (trust, expected) in [(25, "true"), (10, "good"), (3, "bad")]) {
        final engine = RealFsseEngine(_FakeEngineLoader(files(trust)));
        await engine.next();
        expect((await engine.next()).getText(), expected);
      }
    });

    test('registers media, endings and checkpoints in persisted meta-state', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation("index", [
          {"type": "MEDIA", "media_type": "IMAGE", "uri": "photo.png", "unlock_id": "cg_01"},
          {"type": "ENDING", "ending_id": "end_01", "title": "The End", "category": "GOOD"},
        ], checkpoint: true),
      });
      final engine = RealFsseEngine(loader, storage: storage);

      expect(await engine.next(), isA<MediaItemType>());
      final ending = await engine.next() as EndingItemType;
      expect(ending.category, EndingCategory.good);

      final meta = await storage.loadMeta();
      expect(meta.unlockedMediaIds, {"cg_01"});
      expect(meta.unlockedEndingIds, {"end_01"});
      expect(meta.unlockedCheckpoints.keys, ["index"]);

      final catalog = await StoryCatalog.load(loader);
      expect(catalog.media.single.item.unlockId, "cg_01");
      expect(catalog.endings.single.hint, "Unlocked in index");
      expect(catalog.checkpoints.single.key, "index");
    });

    test('save snapshot rewinds a pending choice and restores state', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation("index", [
          _text("one", effects: [
            {"variable": "trust", "op": "add", "value": 1},
          ]),
          {
            "type": "CHOICE",
            "text": "Pick",
            "choices": [
              {"text": "A", "value": "a"},
            ],
          },
          _text("after {{trust}}"),
        ]),
      });

      final engine = RealFsseEngine(loader, storage: storage);
      await engine.next();
      await engine.next();
      await engine.saveTo(1);

      final restored = RealFsseEngine(loader, storage: storage);
      await restored.start(save: await storage.loadSlot(1));
      expect(restored.history.map((e) => e.itemType?.getText()), ["one"]);

      final choice = await restored.next() as ChoiceItemType;
      final next = await restored.next(prevResult: ItemResult.choice("pick", choice.choices.first));
      expect(next.getText(), "after 1");
      expect(restored.getDataMap(), {"trust": 1, "pick": "a"});
    });

    test('starting from a checkpoint restores its variable snapshot', () async {
      final storage = InMemoryStoryStorage();
      final loader = _FakeEngineLoader({
        "index": _conversation("index", [
          {
            "type": "CHOICE",
            "text": "Go",
            "choices": [
              {
                "text": "Day 2",
                "target": "day2",
                "effects": [
                  {"variable": "trust", "op": "set", "value": 7},
                ],
              },
            ],
          },
        ]),
        "day2": _conversation("day2", [_text("trust {{trust}}")], checkpoint: true),
      });

      final engine = RealFsseEngine(loader, storage: storage);
      final choice = await engine.next() as ChoiceItemType;
      await engine.next(prevResult: ItemResult.choice(null, choice.choices.first));

      final checkpoint = (await storage.loadMeta()).unlockedCheckpoints["day2"]!;
      final replay = RealFsseEngine(loader, storage: storage);
      await replay.start(checkpoint: checkpoint);
      expect((await replay.next()).getText(), "trust 7");
    });

    test('resolves player profile name from NAME', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": _conversation("index", [
          {"type": "TEXT", "text": "hi", "profile": "player"},
        ]),
      }));
      await engine.start();
      engine.dataMap["NAME"] = "Alex";
      final item = await engine.next();
      expect(engine.getProfile(item)?.name, "Alex");
      expect(engine.getProfile(item)?.isPlayer, isTrue);
    });
  });
}
