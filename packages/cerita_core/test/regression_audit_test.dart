import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

class _MapLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> channels;

  _MapLoader(this.files, {this.profiles = const [], this.channels = const []});

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({"profiles": profiles}),
        channels: Channel.listFromJson({"channels": channels}),
        conversation: await loadConversation(Conversation.indexKey),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);

  @override
  Future<List<String>> listConversationKeys() async => files.keys.toList();
}

class _CountingRandom implements Random {
  int calls = 0;

  @override
  int nextInt(int max) {
    calls++;
    return 0;
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  group('ConditionEvaluator fixes', () {
    test('modulo by zero throws ConditionException and syntaxError handles it', () {
      const evaluator = ConditionEvaluator();
      expect(() => evaluator.value("10 % x", const {}), throwsA(isA<ConditionException>()));
      expect(ConditionEvaluator.syntaxError("10 % x"), isNull);
    });

    test('syntaxError catches trailing syntax errors even after value errors', () {
      expect(ConditionEvaluator.syntaxError("1 / x ) ) unknownFunc()"), isNotNull);
    });

    test('&& and || short-circuit without evaluating RHS or consuming random rolls', () {
      final rng = _CountingRandom();
      final evaluator = ConditionEvaluator(rng);
      expect(evaluator.evaluate("x != 0 && 10 / x > 2", {"x": 0}), isFalse);
      expect(evaluator.evaluate("x == 0 || 10 / x > 2", {"x": 0}), isTrue);

      expect(evaluator.evaluate("flag && random(1, 6) == 1", {"flag": false}), isFalse);
      expect(rng.calls, 0);
      expect(evaluator.evaluate("flag || random(1, 6) == 1", {"flag": true}), isTrue);
      expect(rng.calls, 0);
    });

    test('! precedence is symmetric with comparisons', () {
      const evaluator = ConditionEvaluator();
      expect(evaluator.evaluate("!a == false", {"a": true}), isTrue);
      expect(evaluator.evaluate("false == !a", {"a": true}), isTrue);
    });
  });

  group('RealFsseEngine & StageState fixes', () {
    test('BRANCH applies item effects before branching', () async {
      final engine = RealFsseEngine(_MapLoader({
        "index": {
          "conversation_id": "index",
          "conversations": [
            {
              "type": "BRANCH",
              "effects": [
                {"variable": "flag", "op": "set", "value": true},
              ],
              "branches": [
                {"condition": "flag == true", "target": "#yes"},
              ],
              "fallback_target": "#no",
            },
            {"type": "TEXT", "id": "yes", "text": "Took yes"},
            {"type": "TEXT", "id": "no", "text": "Took no"},
          ],
        },
      }));
      await engine.start();
      final item = await engine.next();
      expect(item.getText(), "Took yes");
      expect(engine.dataMap["flag"], isTrue);
    });

    test('ChoiceItemType with random() condition only rolls once', () async {
      final rng = _CountingRandom();
      final engine = RealFsseEngine(
        _MapLoader({
          "index": {
            "conversation_id": "index",
            "conversations": [
              {
                "type": "CHOICE",
                "text": "Pick",
                "choices": [
                  {"text": "Lucky", "condition": "random(1, 6) == 1"},
                ],
              },
            ],
          },
        }),
        evaluator: ConditionEvaluator(rng),
      );
      await engine.start();
      await engine.next();
      expect(rng.calls, 1);
    });

    test('seenItems flushes meta-state to storage on next()', () async {
      final storage = InMemoryStoryStorage();
      final engine = RealFsseEngine(
        _MapLoader({
          "index": {
            "conversation_id": "index",
            "conversations": [
              {"type": "TEXT", "text": "Hello"},
            ],
          },
        }),
        storage: storage,
      );
      await engine.start();
      await engine.next();
      final saved = await storage.loadMeta();
      expect(saved.seenItems, contains("index#0"));
    });

    test('StageState.enterScene compares against current background after BackgroundAction', () {
      final stage = StageState();
      const sceneA = Scene(mode: SceneMode.vn, background: "bg_a.png");
      stage.enterScene(sceneA);
      stage.apply(ShowAction(ProfileInfo.fromIdentifier("nora:0")));
      stage.apply(const BackgroundAction("bg_b.png"));

      // Entering a scene with bg_b.png matches the current stage background, so sprites stay.
      stage.enterScene(const Scene(mode: SceneMode.vn, background: "bg_b.png"), previous: sceneA);
      expect(stage.sprites, isNotEmpty);

      // Entering a scene with bg_a.png differs from current stage background (bg_b.png), so sprites clear.
      stage.enterScene(sceneA, previous: const Scene(mode: SceneMode.vn, background: "bg_b.png"));
      expect(stage.sprites, isEmpty);
    });
  });

  group('ClueCatalog, RouteMap & StoryLinter fixes', () {
    test('ClueCatalog.groups merges chapters regardless of locale key order', () {
      final catalog = ClueCatalog([
        Clue(id: "a", title: const LocalizedText("A"), chapter: LocalizedText.locales({"id": "Hari 1", "en": "Day 1"})),
        Clue(id: "b", title: const LocalizedText("B"), chapter: LocalizedText.locales({"en": "Day 1", "id": "Hari 1"})),
      ]);
      expect(catalog.groups.length, 1);
      expect(catalog.groups.single.clues.map((c) => c.id), ["a", "b"]);
    });

    test('RouteMap includes CALL scene hangup targets and handles empty graphs', () {
      final empty = RouteMap(const StoryGraph([]));
      expect(empty.rows, isEmpty);

      final graph = StoryGraph([
        Conversation.fromJson({
          "conversation_id": "index",
          "checkpoint": true,
          "scene": {"mode": "CALL", "hangup": "hung_up"},
          "conversations": [
            {"type": "TEXT", "text": "Ring"},
            {"type": "ENDING", "ending_id": "end_stay", "title": "Stayed"},
          ],
        }, key: "index"),
        Conversation.fromJson({
          "conversation_id": "hung_up",
          "conversations": [
            {"type": "ENDING", "ending_id": "end_hangup", "title": "Hung up"},
          ],
        }, key: "hung_up"),
      ]);
      final map = RouteMap(graph);
      expect(map.nodes.map((n) => n.id), containsAll(["index", "end_stay", "end_hangup"]));
    });

    test('StoryLinter checks localized maps, HideAction/MoveAction, Channel.avatar, and read-only meta.*', () async {
      final loader = _MapLoader(
        {
          "index": {
            "conversation_id": "index",
            "locales": ["id", "en"],
            "conversations": [
              {
                "type": "TEXT",
                "text": {"id": "Halo {{MISSING_VAR}}", "en": "Hi {badtag}"},
              },
              {
                "type": "INPUT",
                "text": "Name?",
                "variable": "meta.flag.nope",
              },
              {
                "type": "STAGE",
                "actions": [
                  {"action": "hide", "profile": "ghost"},
                  {"action": "move", "profile": "ghost2", "position": "left"},
                ],
              },
              {"type": "ENDING", "ending_id": "end", "title": "Done"},
            ],
          },
        },
        profiles: [
          {"id": "nora", "name": "Nora", "sprites": ["n.png"]},
        ],
        channels: [
          {"id": "c1", "name": "C1", "avatar": "missing_avatar.png", "members": ["nora"]},
        ],
      );
      final issues = await StoryLinter(loader, assetExists: (_) => false).lint();
      final messages = issues.map((i) => i.message).toList();
      expect(messages, contains(contains("MISSING_VAR")));
      expect(messages, contains(contains("Unknown text tag '{badtag}'")));
      expect(messages, contains(contains("'meta.flag.nope' is read-only")));
      expect(messages, contains(contains("Unknown character 'ghost'")));
      expect(messages, contains(contains("Unknown character 'ghost2'")));
      expect(messages, contains(contains("Missing avatar file")));
    });

    test('ChoiceItemType skips when its own effects lock every option', () async {
      final engine = RealFsseEngine(
        _MapLoader({
          "index": {
            "conversation_id": "index",
            "conversations": [
              {
                "type": "SET",
                "effects": [
                  {"variable": "tickets", "op": "set", "value": 1},
                ],
              },
              {
                "type": "CHOICE",
                "text": "Pick",
                "effects": [
                  {"variable": "tickets", "op": "set", "value": 0},
                ],
                "choices": [
                  {"text": "Use ticket", "condition": "tickets > 0"},
                ],
              },
              {"type": "TEXT", "text": "Moved on"},
            ],
          },
        }),
      );
      final item = await engine.next();
      expect(item, isA<TextItemType>());
      expect(item.getText(), "Moved on");
    });

    test('snapshot on a pending CHOICE does not replay its item-level effects on reload', () async {
      final loader = _MapLoader({
        "index": {
          "conversation_id": "index",
          "conversations": [
            {
              "type": "CHOICE",
              "text": "Pick",
              "effects": [
                {"variable": "visits", "op": "add", "value": 1},
              ],
              "choices": [
                {"text": "Go"},
              ],
            },
            {"type": "TEXT", "text": "Visits: {{visits}}"},
          ],
        },
      });
      final engine = RealFsseEngine(loader);
      await engine.next();
      expect(engine.dataMap["visits"], 1);
      final saved = engine.snapshot(slotId: 1);

      final restored = RealFsseEngine(loader);
      await restored.start(save: saved);
      final choice = await restored.next() as ChoiceItemType;
      expect(restored.dataMap["visits"], 1);
      final after = await restored.next(prevResult: ItemResult.choice(choice.variable, choice.choices.first));
      expect(after.getText(), "Visits: 1");
    });

    test('final silent SET meta_set flushes meta-state when hitting EndOfStoryException', () async {
      final storage = InMemoryStoryStorage();
      final engine = RealFsseEngine(
        _MapLoader({
          "index": {
            "conversation_id": "index",
            "conversations": [
              {"type": "TEXT", "text": "Last line"},
              {
                "type": "SET",
                "effects": [
                  {"variable": "saw_final", "op": "meta_set"},
                  {"variable": "persistent.runs", "op": "add", "value": 1},
                ],
              },
            ],
          },
        }),
        storage: storage,
      );
      await engine.next();
      await expectLater(engine.next(), throwsA(isA<EndOfStoryException>()));
      final meta = await storage.loadMeta();
      expect(meta.rememberedFacts, contains("saw_final"));
      expect(meta.persistent["runs"], 1);
    });

    test('replay stays in chapter when a continuation omits a secondary translation', () async {
      final engine = RealFsseEngine(
        _MapLoader({
          "index": {
            "conversation_id": "index",
            "source_locale": "id",
            "locales": ["id", "en"],
            "chapter": {"id": "Hari 1", "en": "Day 1"},
            "checkpoint": true,
            "conversations": [
              {"type": "TEXT", "text": "Line 1"},
              {"type": "JUMP", "target": "part2"},
            ],
          },
          "part2": {
            "conversation_id": "part2",
            "chapter": {"id": "Hari 1"},
            "conversations": [
              {"type": "TEXT", "text": "Line 2"},
            ],
          },
        }),
      );
      engine.locale = "en";
      await engine.start(
        checkpoint: Checkpoint(conversationKey: "index", dataMap: const {}, unlockedAt: DateTime(2026)),
        replay: true,
      );
      expect((await engine.next()).getText(), "Line 1");
      expect((await engine.next()).getText(), "Line 2");
    });

    test('reloadCurrent clears loader cache before reloading', () async {
      var cleared = 0;
      final files = <String, Map<String, dynamic>>{
        "index": {
          "conversation_id": "index",
          "conversations": [
            {"type": "TEXT", "text": "Old"},
          ],
        },
      };
      final engine = RealFsseEngine(
        _ClearTrackingLoader(files, onClear: () => cleared++),
      );
      expect((await engine.next()).getText(), "Old");
      files["index"] = {
        "conversation_id": "index",
        "conversations": [
          {"type": "TEXT", "text": "New"},
        ],
      };
      final reloaded = await engine.reloadCurrent();
      expect(cleared, 1);
      expect(reloaded?.getText(), "New");
    });

    test('StoryLinter checks CgAction text without treating scene stay/status as interpolated reads', () async {
      final loader = _MapLoader({
        "index": {
          "conversation_id": "index",
          "scene": {
            "mode": "CALL",
            "stay": "Wait {{NEVER_READ}}",
            "status": "Status {literal}",
          },
          "conversations": [
            {
              "type": "STAGE",
              "actions": [
                {
                  "action": "cg",
                  "image": "cg.png",
                  "unlock_id": "cg_1",
                  "title": "CG {badcg}",
                  "caption": "By {{UNSET_CG}}",
                },
              ],
            },
            {"type": "ENDING", "ending_id": "e1", "title": "Done"},
          ],
        },
      });
      final issues = await StoryLinter(loader).lint();
      final messages = issues.map((i) => i.message).toList();
      expect(messages, contains(contains("Unknown text tag '{badcg}'")));
      expect(messages, contains(contains("UNSET_CG")));
      expect(messages.any((m) => m.contains("NEVER_READ") || m.contains("{literal}")), isFalse);
    });

    test('skipped ChoiceItemType does not commit item-level effects', () async {
      final storage = InMemoryStoryStorage();
      final engine = RealFsseEngine(
        _MapLoader({
          "index": {
            "conversation_id": "index",
            "conversations": [
              {
                "type": "SET",
                "effects": [
                  {"variable": "tickets", "op": "set", "value": 1},
                ],
              },
              {
                "type": "CHOICE",
                "text": "Pick",
                "effects": [
                  {"variable": "tickets", "op": "set", "value": 0},
                  {"variable": "persistent.tries", "op": "add", "value": 1},
                ],
                "choices": [
                  {"text": "Use ticket", "condition": "tickets > 0"},
                ],
              },
              {"type": "TEXT", "text": "Skipped"},
            ],
          },
        }),
        storage: storage,
      );
      expect((await engine.next()).getText(), "Skipped");
      expect(engine.dataMap["tickets"], 1);
      expect((await storage.loadMeta()).persistent["tries"], isNull);
    });

    test('peekExit applies preceding SET before BRANCH and defers on unrecorded random()', () async {
      final engine = RealFsseEngine(
        _MapLoader({
          "index": {
            "conversation_id": "index",
            "conversations": [
              {"type": "TEXT", "text": "Start"},
              {
                "type": "SET",
                "effects": [
                  {"variable": "divisor", "op": "set", "value": 1},
                ],
              },
              {
                "type": "BRANCH",
                "effects": [
                  {"variable": "ratio", "op": "set", "expr": "10 / divisor"},
                ],
                "branches": [
                  {"condition": "ratio == 10", "target": "next_conv"},
                ],
              },
            ],
          },
          "next_conv": {
            "conversation_id": "next_conv",
            "conversations": [
              {"type": "TEXT", "text": "Arrived"},
            ],
          },
        }),
      );
      await engine.next();
      final exit = await engine.peekExit();
      expect(exit?.next?.key, "next_conv");
      expect(engine.dataMap["divisor"], isNull, reason: "peekExit must not mutate live state");

      final randomEngine = RealFsseEngine(
        _MapLoader({
          "index": {
            "conversation_id": "index",
            "conversations": [
              {"type": "TEXT", "text": "Before roll"},
              {
                "type": "BRANCH",
                "branches": [
                  {"condition": "random(1, 2) == 1", "target": "next_conv"},
                ],
                "fallback_target": "next_conv",
              },
            ],
          },
          "next_conv": {
            "conversation_id": "next_conv",
            "conversations": [
              {"type": "TEXT", "text": "After roll"},
            ],
          },
        }),
      );
      await randomEngine.next();
      expect(await randomEngine.peekExit(), isNull, reason: "unrecorded random() defers prediction");
    });

    test('rollback to pending CHOICE preserves pre-effect snapshot state across save/load', () async {
      final loader = _MapLoader({
        "index": {
          "conversation_id": "index",
          "scene": {"mode": "VN"},
          "conversations": [
            {
              "type": "CHOICE",
              "text": "Pick",
              "effects": [
                {"variable": "visits", "op": "add", "value": 1},
              ],
              "choices": [
                {"text": "Go"},
              ],
            },
            {"type": "TEXT", "text": "After"},
          ],
        },
      });
      final engine = RealFsseEngine(loader);
      final choice = await engine.next() as ChoiceItemType;
      await engine.next(prevResult: ItemResult.choice(choice.variable, choice.choices.first));
      engine.rollback();
      final saved = engine.snapshot(slotId: 1);

      final restored = RealFsseEngine(loader);
      await restored.start(save: saved);
      await restored.next();
      expect(restored.dataMap["visits"], 1);
    });
  });
}

class _ClearTrackingLoader extends _MapLoader {
  final void Function() onClear;

  _ClearTrackingLoader(super.files, {required this.onClear});

  @override
  void clearCache() => onClear();
}
