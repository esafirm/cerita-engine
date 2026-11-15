import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

/// Cross-playthrough memory (backlog CE-03): `meta_set`, `meta.ending.*`, `meta.flag.*` and `memory_marker`.

class _FakeEngineLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  _FakeEngineLoader(this.files);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "tasya", "name": "Tasya", "sprites": ["tasya.png"]},
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

Map<String, dynamic> _conversation(List<Map<String, dynamic>> items, {String? chapter, bool checkpoint = false}) => {
      "conversation_id": "cvn",
      "chapter": ?chapter,
      "checkpoint": checkpoint,
      "scene": {"mode": "VN"},
      "conversations": items,
    };

Map<String, dynamic> _text(String text, {String? condition, List<Map<String, dynamic>>? effects}) =>
    {"type": "TEXT", "text": text, "profile": "tasya:0", "condition": ?condition, "effects": ?effects};

Map<String, dynamic> _ending(String id) =>
    {"type": "ENDING", "ending_id": id, "title": id, "category": "GOOD", "summary": "."};

const _rememberBoat = {"variable": "knows_boat", "op": "meta_set"};

/// Two routes from a hub. The harbor route remembers the boat's name and ends in the storm. The network
/// route reacts to what earlier runs found.
Map<String, Map<String, dynamic>> _story() => {
      "index": _conversation([
        _text("Day five."),
        {
          "type": "CHOICE",
          "text": "Where to?",
          "choices": [
            {"text": "Harbor", "target": "harbor"},
            {"text": "Network", "target": "network"},
          ],
        },
      ], chapter: "Day 5", checkpoint: true),
      "harbor": _conversation([
        _text("The boat is the Kenanga.", effects: [_rememberBoat]),
        _ending("end_storm"),
      ]),
      "network": _conversation([
        _text("Tasya: The Kenanga? How do you know that?", condition: "meta.flag.knows_boat"),
        _text("Tasya: Found anything?"),
        {
          "type": "CHOICE",
          "text": "Answer",
          "choices": [
            {
              "text": "Mention the storm",
              "condition": "meta.ending.end_storm && found_photo",
              "memory_marker": true,
              "target": "true_route",
            },
            {"text": "Show the receipt", "condition": "has_receipt"},
            {"text": "Nothing yet", "effects": [{"variable": "found_photo", "op": "set", "value": true}]},
          ],
        },
        _ending("end_good"),
      ]),
      "true_route": _conversation([_ending("end_true")]),
    };

Future<RealFsseEngine> _start(StoryStorage storage, {SaveSlot? save, Checkpoint? checkpoint}) async {
  final engine = RealFsseEngine(_FakeEngineLoader(_story()), storage: storage);
  await engine.start(save: save, checkpoint: checkpoint);
  return engine;
}

/// Plays the harbor route to the storm ending.
Future<void> _playHarbor(StoryStorage storage) async {
  final engine = await _start(storage);
  await engine.next();
  final hub = await engine.next() as ChoiceItemType;
  expect(await engine.next(prevResult: ItemResult.choice(null, hub.choices.first)), isA<TextItemType>());
  expect(await engine.next(), isA<EndingItemType>());
}

/// Picks the network route and returns the lines up to its CHOICE.
Future<List<ItemType>> _toNetworkChoice(RealFsseEngine engine) async {
  await engine.next();
  final hub = await engine.next() as ChoiceItemType;
  final items = [await engine.next(prevResult: ItemResult.choice(null, hub.choices.last))];
  while (items.last is! ChoiceItemType) {
    items.add(await engine.next());
  }
  return items;
}

void main() {
  group('Memory variables', () {
    const evaluator = ConditionEvaluator();
    late GlobalMetaState meta;
    late StoryState state;

    setUp(() {
      meta = GlobalMetaState(unlockedEndingIds: {"end_storm"}, rememberedFacts: {"knows_boat"});
      state = StoryState({"found_photo": true, "trust": 3}, () => meta);
    });

    test('read endings reached and remembered facts as booleans', () {
      expect(evaluator.evaluate("meta.ending.end_storm", state), isTrue);
      expect(evaluator.evaluate("meta.ending.end_true", state), isFalse);
      expect(evaluator.evaluate("meta.flag.knows_boat", state), isTrue);
      expect(evaluator.evaluate("meta.flag.knows_host", state), isFalse);
      expect(evaluator.evaluate("meta.flag.knows_host == false", state), isTrue);
      expect(evaluator.evaluate("!meta.ending.end_true", state), isTrue);
    });

    test('combine with run variables', () {
      expect(evaluator.evaluate("meta.ending.end_storm && found_photo", state), isTrue);
      expect(evaluator.evaluate("meta.ending.end_storm && trust > 5", state), isFalse);
      expect(evaluator.evaluate("meta.flag.knows_host || trust == 3", state), isTrue);
    });

    test('unknown namespaces are errors and memory is read-only', () {
      expect(() => evaluator.evaluate("meta.route.harbor", state), throwsA(isA<ConditionException>()));
      expect(() => evaluator.evaluate("meta.flag.", state), throwsA(isA<ConditionException>()));
      expect(() => state["meta.flag.knows_host"] = true, throwsStateError);
      expect(() => Effect.fromJson({"variable": "meta.flag.x", "op": "toggle"}).apply(state), throwsStateError);
      // Only names starting with `meta.` are reserved.
      state["metadata"] = 1;
      expect(evaluator.evaluate("metadata == 1", state), isTrue);
    });

    test('meta_set remembers a fact once and needs a StoryState', () {
      final effect = Effect.fromJson({"variable": "knows_host", "op": "meta_set"});
      expect(effect.op, EffectOp.metaSet);

      effect.apply(state);
      expect(meta.rememberedFacts, {"knows_boat", "knows_host"});
      expect(state.persistentDirty, isTrue);
      expect(state.session, {"found_photo": true, "trust": 3});

      state.persistentDirty = false;
      effect.apply(state);
      expect(state.persistentDirty, isFalse);

      expect(() => effect.apply({}), throwsStateError);
    });
  });

  group('Remembering', () {
    test('a fact and the ending survive New game, and memory-gated lines react', () async {
      final storage = InMemoryStoryStorage();
      await _playHarbor(storage);

      final saved = await storage.loadMeta();
      expect(saved.rememberedFacts, {"knows_boat"});
      expect(saved.unlockedEndingIds, {"end_storm"});

      final engine = await _start(storage);
      expect(engine.dataMap, isEmpty);
      final lines = await _toNetworkChoice(engine);
      expect(lines.first.getText(), "Tasya: The Kenanga? How do you know that?");
    });

    test('the meta-state is saved as soon as a choice remembers a fact', () async {
      final storage = InMemoryStoryStorage();
      final engine = RealFsseEngine(
        _FakeEngineLoader({
          "index": _conversation([
            {
              "type": "CHOICE",
              "text": "?",
              "choices": [
                {"text": "Read the hull", "effects": [_rememberBoat]},
              ],
            },
            _text("Done."),
          ]),
        }),
        storage: storage,
      );
      final choice = await engine.next() as ChoiceItemType;
      await engine.next(prevResult: ItemResult.choice(null, choice.choices.single));
      expect((await storage.loadMeta()).rememberedFacts, {"knows_boat"});
    });

    test('loading an older save, a checkpoint replay and rollback keep what was remembered', () async {
      final storage = InMemoryStoryStorage();
      final first = await _start(storage);
      await first.next();
      await first.saveTo(1);
      final checkpoint = (await storage.loadMeta()).unlockedCheckpoints["index"]!;
      await _playHarbor(storage);

      // The slot and the checkpoint were made before the fact was remembered.
      for (final engine in [
        await _start(storage, save: await storage.loadSlot(1)),
        await _start(storage, checkpoint: checkpoint),
      ]) {
        expect(engine.evaluate("meta.flag.knows_boat && meta.ending.end_storm"), isTrue);
        expect(engine.dataMap.containsKey("knows_boat"), isFalse);
      }

      final engine = await _start(storage);
      await engine.next();
      await engine.next();
      engine.rollback();
      expect(engine.evaluate("meta.flag.knows_boat"), isTrue);
    });

    test('meta-state and saves from before this feature still load', () async {
      final old = GlobalMetaState.fromJson({
        "unlocked_media_ids": ["cg_01"],
        "unlocked_ending_ids": ["end_storm"],
        "seen_items": ["index#0"],
        "unlocked_checkpoints": {},
      });
      expect(old.rememberedFacts, isEmpty);
      expect(old.toJson()["remembered_facts"], isEmpty);

      final storage = InMemoryStoryStorage();
      await storage.saveMeta(old);
      final save = SaveSlot.fromJson({
        "slot_id": 1,
        "conversation_key": "network",
        "dialog_index": 0,
        "data_map": {"found_photo": true},
        "history": [],
        "updated_at": "2026-01-01T00:00:00.000",
      });
      final engine = await _start(storage, save: save);
      expect((await engine.next()).getText(), "Tasya: Found anything?");
      final choice = await engine.next() as ChoiceItemType;
      expect(choice.choices.first.text, "Mention the storm");
    });

    test('Reset progress forgets every fact', () async {
      final storage = InMemoryStoryStorage();
      await _playHarbor(storage);
      await storage.clear();

      final meta = await storage.loadMeta();
      expect(meta.rememberedFacts, isEmpty);
      expect(meta.unlockedEndingIds, isEmpty);
      final engine = await _start(storage);
      expect(engine.evaluate("meta.flag.knows_boat || meta.ending.end_storm"), isFalse);
    });
  });

  group('Reacting', () {
    test('a first run shows no memory-gated line or choice, and run-gated choices stay locked', () async {
      final engine = await _start(InMemoryStoryStorage());
      final lines = await _toNetworkChoice(engine);
      expect(lines.map((item) => item.getText()), ["Tasya: Found anything?", "Answer"]);

      final choice = lines.last as ChoiceItemType;
      expect(choice.choices.map((c) => c.text), ["Show the receipt", "Nothing yet"]);
      expect(choice.choices.first.locked, isTrue);
    });

    test('the gated choice needs both the ending and the run variable, and carries its marker', () async {
      final storage = InMemoryStoryStorage();
      await _playHarbor(storage);

      // Storm ending seen, but no photo in this run.
      var choice = (await _toNetworkChoice(await _start(storage))).last as ChoiceItemType;
      expect(choice.choices.map((c) => c.text), ["Show the receipt", "Nothing yet"]);

      final save = SaveSlot.fromJson({
        "slot_id": 1,
        "conversation_key": "network",
        "dialog_index": 2,
        "data_map": {"found_photo": true},
        "history": [],
        "updated_at": "2026-01-01T00:00:00.000",
      });
      final engine = await _start(storage, save: save);
      choice = await engine.next() as ChoiceItemType;
      final storm = choice.choices.first;
      expect(storm.text, "Mention the storm");
      expect(storm.locked, isFalse);
      expect(storm.memoryMarker, isTrue);
      expect(choice.choices.skip(1).map((c) => c.memoryMarker), [false, false]);

      await engine.next(prevResult: ItemResult.choice(null, storm));
      expect((await storage.loadMeta()).unlockedEndingIds, {"end_storm", "end_true"});
    });

    test('BRANCH routes on memory', () async {
      final storage = InMemoryStoryStorage();
      await storage.saveMeta(GlobalMetaState(unlockedEndingIds: {"end_storm", "end_good"}));
      final engine = RealFsseEngine(
        _FakeEngineLoader({
          "index": _conversation([
            {
              "type": "BRANCH",
              "branches": [
                {"condition": "meta.ending.end_storm && meta.ending.end_good", "target": "true_route"},
              ],
              "fallback_target": "plain",
            },
          ]),
          "true_route": _conversation([_text("The whole truth.")]),
          "plain": _conversation([_text("Half of it.")]),
        }),
        storage: storage,
      );
      expect((await engine.next()).getText(), "The whole truth.");
    });
  });

  group('StoryLinter', () {
    Future<List<String>> lint(List<Map<String, dynamic>> items) async => [
          for (final issue in await StoryLinter(_FakeEngineLoader({"index": _conversation(items)})).lint()) "$issue",
        ];

    test('knows facts come from meta_set and endings from ENDING items', () async {
      expect(
        await lint([
          {"type": "SET", "effects": [_rememberBoat]},
          _text("Again?", condition: "meta.flag.knows_boat && meta.ending.end_storm"),
          _ending("end_storm"),
        ]),
        isEmpty,
      );
    });

    test('flags unknown facts, endings and namespaces, and writes to memory', () async {
      final issues = await lint([
        _text("a", condition: "meta.flag.knows_host"),
        _text("b", condition: "meta.ending.end_lost"),
        _text("c", condition: "meta.route.harbor"),
        {"type": "SET", "effects": [{"variable": "meta.flag.knows_host", "op": "set", "value": true}]},
      ]);
      expect(issues, containsAll([
        "error   index.json #2  Unknown memory variable 'meta.route.harbor'. "
            "Use meta.ending.<ending_id> or meta.flag.<name>",
        "error   index.json #3  'meta.flag.knows_host' is read-only. Remember facts with the meta_set op",
        "warning index.json #1  No ENDING has ending_id 'end_lost' (read as 'meta.ending.end_lost')",
      ]));
    });

    test('warns about facts read but never remembered', () async {
      final issues = await lint([_text("a", condition: "meta.flag.knows_host")]);
      expect(issues, ["warning index.json #0  Fact 'meta.flag.knows_host' is read but never remembered with meta_set"]);
    });
  });
}
