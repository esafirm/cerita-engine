import 'dart:convert';
import 'dart:io';

import 'package:cerita_core/cerita_core.dart';
import 'package:cerita_core/io.dart';
import 'package:test/test.dart';

/// Case Board clues (backlog CE-05) and evidence questions (backlog CE-06).

class _FakeEngineLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;
  final Map<String, dynamic>? clues;

  _FakeEngineLoader(this.files, {this.clues = _clues});

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "tasya", "name": "Tasya", "sprites": ["tasya.png"]},
          ],
        }),
        conversation: await loadConversation(Conversation.indexKey),
        clues: clues == null ? ClueCatalog.empty : ClueCatalog.fromJson(clues!),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);

  @override
  Future<List<String>> listConversationKeys() async => files.keys.toList();
}

class _Listener with EngineListener {
  final found = <String>[];

  @override
  void onNewScene(Scene scene) {}

  @override
  void onClueFound(Clue clue) => found.add(clue.id);
}

const _clues = {
  "show_counts": true,
  "clues": [
    {
      "id": "pier_photo",
      "title": {"id": "Foto dermaga", "en": "Pier photo"},
      "image": "pier.png",
      "key": true,
      "chapter": "Day 2",
    },
    {"id": "unsent_message", "title": "Unsent message", "chapter": "Day 2"},
    {"id": "harbor_log", "title": "Harbor log", "chapter": "Day 3"},
    {"id": "receipt", "title": "Receipt"},
  ],
};

Map<String, dynamic> _conversation(List<Map<String, dynamic>> items,
        {String? chapter, bool checkpoint = false, String mode = "VN"}) =>
    {
      "conversation_id": "cvn",
      "chapter": ?chapter,
      "checkpoint": checkpoint,
      "scene": {"mode": mode, if (mode == "CHAT") "channel_id": "thread_tasya"},
      "conversations": items,
    };

Map<String, dynamic> _text(String text, {String? id, String? condition, List<Map<String, dynamic>>? effects}) =>
    {"type": "TEXT", "id": ?id, "text": text, "profile": "tasya:0", "condition": ?condition, "effects": ?effects};

Map<String, dynamic> _award(String clue) => {"variable": "clue_$clue", "op": "set", "value": true};

const _endWrong = {"type": "ENDING", "ending_id": "wrong", "title": "Wrong", "category": "BAD", "summary": "."};

/// Tasya asks which clue proves Sekar knew. One retry. The unsent message is right, the pier photo gets a
/// specific dismissive reply that leads back to the question.
Map<String, dynamic> _question({int retries = 1, Map<String, dynamic>? retry, int? timeoutMs}) => {
      "type": "CHOICE",
      "id": "ask",
      "source": "clues",
      "text": "What makes you think Sekar knew?",
      "profile": "tasya:0",
      "variable": "presented",
      "retries": retries,
      "timeout_ms": ?timeoutMs,
      "responses": [
        {"clue": "unsent_message", "effects": [{"variable": "trust", "op": "add", "value": 1}], "target": "#right"},
        {"clue": "pier_photo", "target": "#pier"},
      ],
      "retry": ?retry,
      "fallback": {"effects": [{"variable": "trust", "op": "subtract", "value": 5}], "target": "#wrong"},
      "timeout": {"target": "#late"},
    };

Map<String, Map<String, dynamic>> _story({Map<String, dynamic>? question, bool award = true}) => {
      "index": _conversation([
        _text("Day two.", effects: [if (award) ...[_award("pier_photo"), _award("unsent_message")]]),
        {
          "type": "CHOICE",
          "text": "Check the receipt?",
          "choices": [
            {"text": "Yes", "effects": [_award("receipt")]},
            {"text": "No"},
          ],
        },
        question ?? _question(),
        _text("Fine, try again.", id: "try_again"),
        {"type": "JUMP", "target": "#ask"},
        _text("Just a pier.", id: "pier"),
        {"type": "JUMP", "target": "#ask"},
        _text("You're right.", id: "right"),
        _text("Too slow.", id: "late"),
        {"id": "wrong", ..._endWrong},
      ], chapter: "Day 2"),
    };

Future<RealFsseEngine> _start(Map<String, Map<String, dynamic>> files,
    {StoryStorage? storage, SaveSlot? save, Checkpoint? checkpoint, EngineListener? listener}) async {
  final engine = RealFsseEngine(_FakeEngineLoader(files), storage: storage, listener: listener);
  await engine.start(save: save, checkpoint: checkpoint);
  return engine;
}

/// Plays up to the evidence question, picking the receipt or not on the way.
Future<EvidenceItemType> _toQuestion(RealFsseEngine engine, {bool receipt = false}) async {
  await engine.next();
  final choice = await engine.next() as ChoiceItemType;
  return await engine.next(prevResult: ItemResult.choice(null, choice.choices[receipt ? 0 : 1])) as EvidenceItemType;
}

Future<ItemType> _present(RealFsseEngine engine, EvidenceItemType question, String clue) =>
    engine.next(prevResult: ItemResult.present(question, engine.clues.byId(clue)!));

void main() {
  group('clues.json', () {
    test('groups clues by chapter, newest chapter first and loose clues last', () {
      final catalog = ClueCatalog.fromJson(_clues);
      expect(catalog.showCounts, isTrue);
      expect([for (final group in catalog.groups) group.chapter?.toString()], ["Day 3", "Day 2", null]);
      expect([for (final clue in catalog.groups[1].clues) clue.id], ["pier_photo", "unsent_message"]);
      final pier = catalog.byId("pier_photo")!;
      expect(
        (pier.title.resolve("en"), pier.title.toString(), pier.isKey, pier.image, pier.variable),
        ("Pier photo", "Foto dermaga", true, "pier.png", "clue_pier_photo"),
      );
      expect(catalog.byId("receipt")!.isKey, isFalse);
    });

    test('a clue needs an id and a title', () {
      expect(() => ClueCatalog.fromJson({"clues": [{"title": "x"}]}), throwsFormatException);
      expect(() => ClueCatalog.fromJson({"clues": [{"id": "x"}]}), throwsFormatException);
    });

    test('the file loader reads clues.json when it exists', () async {
      final dir = Directory.systemTemp.createTempSync("cerita_clues");
      addTearDown(() => dir.deleteSync(recursive: true));
      File("${dir.path}/profiles.json").writeAsStringSync(jsonEncode({"profiles": []}));
      File("${dir.path}/index.json").writeAsStringSync(jsonEncode(_conversation([])));
      expect((await FileEngineLoader.directory(dir.path).initialLoad()).clues.isEmpty, isTrue);

      File("${dir.path}/clues.json").writeAsStringSync(jsonEncode(_clues));
      expect((await FileEngineLoader.directory(dir.path).initialLoad()).clues.clues, hasLength(4));
    });
  });

  group('Finding clues', () {
    test('a clue is found when its variable becomes true, and notifies once', () async {
      final listener = _Listener();
      final engine = await _start({
        "index": _conversation([
          _text("A photo.", effects: [_award("pier_photo")]),
          _text("The photo again.", effects: [_award("pier_photo")]),
          _text("Found it.", condition: "clue_pier_photo == true"),
          _text("Not yet.", condition: "!clue_harbor_log"),
        ]),
      }, listener: listener);

      expect(engine.foundClues, isEmpty);
      await engine.next();
      expect([for (final clue in engine.foundClues) clue.id], ["pier_photo"]);
      await engine.next();
      expect(listener.found, ["pier_photo"]);
      expect((await engine.next()).getText(), "Found it.");
      expect((await engine.next()).getText(), "Not yet.");
    });

    test('New game empties the board, and saves and checkpoints restore it', () async {
      final storage = InMemoryStoryStorage();
      final engine = await _start(_story(), storage: storage);
      await _toQuestion(engine, receipt: true);
      expect(engine.foundClues, hasLength(3));
      await engine.saveTo(1);

      final fresh = await _start(_story(), storage: storage);
      expect(fresh.foundClues, isEmpty);

      final loaded = await _start(_story(), storage: storage, save: await storage.loadSlot(1));
      expect([for (final clue in loaded.foundClues) clue.id], ["pier_photo", "unsent_message", "receipt"]);
    });

    test('rolling back past an award takes the clue off the board, without a notification', () async {
      final listener = _Listener();
      final engine = await _start(_story(), listener: listener);
      await _toQuestion(engine, receipt: true);
      expect(engine.foundClues, hasLength(3));
      expect(listener.found, ["pier_photo", "unsent_message", "receipt"]);

      engine.rollback(); // to the receipt choice
      expect([for (final clue in engine.foundClues) clue.id], ["pier_photo", "unsent_message"]);
      engine.rollback(); // to the first line
      expect(engine.foundClues, hasLength(2));
      expect(listener.found, hasLength(3));
    });

    test('viewed clues are saved, and older saves and checkpoints count found clues as viewed', () async {
      final storage = InMemoryStoryStorage();
      final engine = await _start(_story(), storage: storage);
      await _toQuestion(engine, receipt: true);
      expect([for (final clue in engine.newClues) clue.id], ["pier_photo", "unsent_message", "receipt"]);
      engine.markCluesViewed(["pier_photo"]);
      engine.rollback();
      expect(engine.viewedClues, {"pier_photo"});
      await engine.saveTo(1);

      final save = (await storage.loadSlot(1))!;
      final loaded = await _start(_story(), save: save);
      expect([for (final clue in loaded.newClues) clue.id], ["unsent_message"]);

      final older = SaveSlot.fromJson(save.toJson()..remove("viewed_clues"));
      expect((await _start(_story(), save: older)).newClues, isEmpty);

      final checkpoint = Checkpoint(
        conversationKey: "index",
        dataMap: {"clue_pier_photo": true},
        unlockedAt: DateTime(2026),
      );
      final replayed = await _start(_story(), checkpoint: checkpoint);
      expect(replayed.foundClues, hasLength(1));
      expect(replayed.newClues, isEmpty);
    });
  });

  group('Evidence questions', () {
    test('parse as a CHOICE without options', () async {
      final question = ItemType.fromJson(_question()) as EvidenceItemType;
      expect(question, isA<ChoiceItemType>());
      expect(question.choices, isEmpty);
      expect((question.retries, question.responses.length, question.fallback!.target), (1, 2, "#wrong"));
      expect(() => ItemType.fromJson({..._question(), "source": "profiles"}), throwsFormatException);
    });

    test('the right clue plays its response and is recorded as presented', () async {
      final engine = await _start(_story());
      final question = await _toQuestion(engine);
      expect(question.getText(), "What makes you think Sekar knew?");

      expect((await _present(engine, question, "unsent_message")).getText(), "You're right.");
      expect(engine.dataMap["presented"], "unsent_message");
      expect(engine.dataMap["trust"], 1);
      final reply = engine.history[engine.history.length - 2];
      expect((reply.isPlayer, reply.clueId, reply.playerText), (true, "unsent_message", const LocalizedText("Unsent message")));
      expect(TranscriptEntry.fromJson(jsonDecode(jsonEncode(reply.toJson()))).clueId, "unsent_message");
    });

    test('a specific reply can lead back to the question without using a retry', () async {
      final engine = await _start(_story());
      var question = await _toQuestion(engine);
      expect((await _present(engine, question, "pier_photo")).getText(), "Just a pier.");
      question = await engine.next() as EvidenceItemType;
      expect((await _present(engine, question, "pier_photo")).getText(), "Just a pier.");
      question = await engine.next() as EvidenceItemType;
      expect((await _present(engine, question, "unsent_message")).getText(), "You're right.");
    });

    test('a presented clue keeps its title in every language, also in a save', () async {
      final engine = await _start(_story());
      final question = await _toQuestion(engine);
      await _present(engine, question, "pier_photo");
      final reply = engine.history.firstWhere((entry) => entry.clueId != null);
      final saved = TranscriptEntry.fromJson(jsonDecode(jsonEncode(reply.toJson())));
      for (final entry in [reply, saved]) {
        expect(entry.playerText!.resolve("en"), "Pier photo");
        expect(entry.playerText!.resolve("id"), "Foto dermaga");
      }
    });

    test('with one retry, the retry plays after the first wrong clue and the fallback after the second', () async {
      final engine = await _start(_story(question: _question(retry: {"target": "#try_again"})));
      var question = await _toQuestion(engine, receipt: true);
      expect((await _present(engine, question, "receipt")).getText(), "Fine, try again.");
      question = await engine.next() as EvidenceItemType;
      expect(await _present(engine, question, "receipt"), isA<EndingItemType>());
      expect(engine.dataMap["trust"], -5);
    });

    test('a retry without a target asks again, and retries count again next time', () async {
      final engine = await _start(_story());
      var question = await _toQuestion(engine, receipt: true);
      expect(await _present(engine, question, "receipt"), isA<EvidenceItemType>());
      question = engine.history.last.itemType as EvidenceItemType;
      // A specific reply resets the count: the next wrong clue retries again.
      expect((await _present(engine, question, "pier_photo")).getText(), "Just a pier.");
      question = await engine.next() as EvidenceItemType;
      expect(await _present(engine, question, "receipt"), isA<EvidenceItemType>());
    });

    test('with no retries, a wrong clue plays the fallback', () async {
      final engine = await _start(_story(question: _question(retries: 0)));
      final question = await _toQuestion(engine, receipt: true);
      expect(await _present(engine, question, "receipt"), isA<EndingItemType>());
    });

    test('a timeout plays the timeout outcome and adds no reply', () async {
      final engine = await _start(_story(question: _question(timeoutMs: 5000)));
      final question = await _toQuestion(engine);
      expect(question.timeoutMs, 5000);
      final length = engine.history.length;
      expect((await engine.next(prevResult: const ItemResult.evidenceTimeout())).getText(), "Too slow.");
      expect(engine.history.length, length + 1);
    });

    test('with no clue found, the question is skipped and the fallback plays', () async {
      final engine = await _start(_story(award: false));
      await engine.next();
      final choice = await engine.next() as ChoiceItemType;
      expect(await engine.next(prevResult: ItemResult.choice(null, choice.choices[1])), isA<EndingItemType>());
      expect(engine.dataMap["trust"], -5);
    });

    test('a save at the question asks it again, and retries used survive saves and rollback', () async {
      final storage = InMemoryStoryStorage();
      final engine = await _start(_story(), storage: storage);
      var question = await _toQuestion(engine, receipt: true);
      await _present(engine, question, "receipt"); // uses the retry, asked again
      await engine.saveTo(1);

      final loaded = await _start(_story(), storage: storage, save: await storage.loadSlot(1));
      question = await loaded.next() as EvidenceItemType;
      expect(await _present(loaded, question, "receipt"), isA<EndingItemType>());

      // Back to the question as it was asked the second time: no retry left.
      expect(loaded.rollback(), isA<EvidenceItemType>());
      expect(await _present(loaded, question, "receipt"), isA<EndingItemType>());
      // Back to the first time: the retry is there again.
      expect(loaded.rollback(), isA<EvidenceItemType>());
      expect(loaded.rollback(), isA<EvidenceItemType>());
      expect(await _present(loaded, question, "receipt"), isA<EvidenceItemType>());
    });
  });

  group('Linter', () {
    Future<List<String>> lint(Map<String, Map<String, dynamic>> files, {Map<String, dynamic>? clues = _clues}) async =>
        [for (final issue in await StoryLinter(_FakeEngineLoader(files, clues: clues)).lint()) "$issue"];

    test('a story whose clues are all awarded before the question is clean of clue issues', () async {
      final issues = await lint(_story());
      expect(issues.where((issue) => issue.contains("lue")), [
        "warning clues.json  Clue 'harbor_log' is never awarded: no effect sets 'clue_harbor_log'",
      ]);
    });

    test('undeclared clues, bad ids and bad evidence questions', () async {
      final issues = await lint({
        "index": _conversation([
          _text("?", condition: "clue_boat == true", effects: [
            for (final clue in ["pier_photo", "harbor_log", "receipt", "unsent_message"]) _award(clue),
          ]),
          {
            "type": "CHOICE",
            "source": "clues",
            "text": "?",
            "default_choice": 0,
            "retries": -1,
            "responses": [{"clue": "pier"}, {"clue": "pier"}],
          },
          {"type": "CHOICE", "source": "clues", "text": "?"},
        ]),
      }, clues: {
        "clues": [..._clues["clues"] as List, {"id": "bad id", "title": "x"}, {"id": "receipt", "title": "x"}],
      });
      expect(issues, containsAll([
        "error   clues.json  Clue id 'bad id' can only use letters, digits and _",
        "error   clues.json  Duplicate clue id 'receipt'",
        "error   index.json #0  Clue 'boat' isn't declared in clues.json (used as 'clue_boat')",
        "error   index.json #1  An evidence question takes no default_choice. Use a timeout outcome",
        "error   index.json #1  retries can't be negative",
        "error   index.json #1  Two responses for clue 'pier'",
        "error   index.json #1  Clue 'pier' isn't declared in clues.json",
        "error   index.json #1  No clue with a response can be found before this evidence question",
        "error   index.json #2  Evidence question without responses",
      ]));
    });

    test('a clue counts when awarded earlier, before the conversation or in a called one', () async {
      Map<String, dynamic> ask(String clue) => {
            "type": "CHOICE",
            "source": "clues",
            "text": "?",
            "responses": [{"clue": clue}],
          };
      final issues = await lint({
        "index": _conversation([
          {"type": "CALL", "target": "shared"},
          ask("receipt"), // awarded in the called conversation
          ask("unsent_message"), // only awarded later in this file
          _text("Later.", effects: [_award("unsent_message")]),
          {"type": "JUMP", "target": "day3"},
        ]),
        "shared": _conversation([_text("Here.", effects: [_award("receipt"), _award("pier_photo")])]),
        "day3": _conversation([ask("pier_photo"), ask("harbor_log"), _text("x", effects: [_award("harbor_log")])]),
      });
      final answers = issues.where((issue) => issue.contains("before this evidence question")).toList();
      expect(answers, [
        "error   cvn_day3.json #1  No clue with a response can be found before this evidence question",
        "error   index.json #2  No clue with a response can be found before this evidence question",
      ]);
    });

    test('without clues.json, clue_ variables are ordinary', () async {
      final issues = await lint({
        "index": _conversation([
          _text("?", condition: "clue_count > 1", effects: [{"variable": "clue_count", "op": "add", "value": 1}]),
        ]),
      }, clues: null);
      expect(issues, isEmpty);
    });

    test('the graph shows evidence outcomes', () async {
      final links = StoryLink.of(Conversation.fromJson(_story()["index"]!, key: "index")).toList();
      expect([for (final link in links) (link.target, link.label)], containsAll([
        ("#right", "Present unsent_message"),
        ("#pier", "Present pier_photo"),
        ("#wrong", null),
        ("#late", "time out"),
      ]));
    });
  });
}
