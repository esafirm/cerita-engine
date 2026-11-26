import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays the bundled demo story headlessly, so every route and JSON file is exercised.
Future<(EndingItemType, RealFsseEngine)> _play({
  required String Function(ChoiceItemType item) pick,
  String Function(EvidenceItemType item)? present,
  Map<String, String> inputs = const {},
  StoryStorage? storage,
}) async {
  final engine = RealFsseEngine(AssetEngineLoader(const LoaderConfig()), storage: storage);
  ItemResult? result;
  for (var step = 0; step < 200; step++) {
    final item = await engine.next(prevResult: result);
    result = null;
    switch (item) {
      case EndingItemType():
        return (item, engine);
      case EvidenceItemType():
        final id = present?.call(item) ??
            item.responses.map((r) => r.clue).firstWhere((id) => engine.state["clue_$id"] == true);
        result = ItemResult.present(item, engine.clues.byId(id)!);
      case ChoiceItemType():
        final text = pick(item);
        final choice = item.choices.firstWhere((c) => c.text.startsWith(text), orElse: () => item.availableChoices.first);
        expect(choice.locked, isFalse, reason: "'${choice.text}' is locked");
        result = ItemResult.choice(item.variable, choice);
      case InputItemType():
        result = ItemResult.input(item.variable, inputs[item.variable] ?? item.defaultValue!);
      default:
        break;
    }
  }
  fail("No ending reached");
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every text tag in the story is a known tag', () async {
    final loader = AssetEngineLoader(const LoaderConfig());
    final catalog = await StoryCatalog.load(loader);
    for (final conversation in catalog.conversations) {
      for (final item in conversation.conversations) {
        // Variables are filled in before the tags are read.
        final text = item.getText()?.replaceAll(variablePattern, "");
        if (text == null) continue;
        expect(TextMarkup.plain(text), isNot(contains("{")), reason: "'$text' in ${conversation.key}");
      }
    }
  });

  test('the Chapters flowchart runs Prologue, Day 1, Day 2 and the four endings', () async {
    final catalog = await StoryCatalog.load(AssetEngineLoader(const LoaderConfig()));
    final map = RouteMap(StoryGraph(catalog.conversations));
    expect([for (final row in map.rows) "$row"], [
      "[index]",
      "[day1]",
      "[day2]",
      "[ending end_04_secret, ending end_01_true, ending end_02_good, ending end_03_bad]",
    ], reason: "the call scene folds into Day 1");
    expect(map.branches, isTrue);
  });

  test('secret ending: curious, call, photo and the right passcode', () async {
    final storage = InMemoryStoryStorage();
    final (ending, engine) = await _play(
      storage: storage,
      inputs: {"NAME": "Rin", "PASSCODE": "2019"},
      pick: (item) => switch (item.text) {
        "\"Are you going to check it?\"" => "Yeah",
        "How do you reply?" => "Who is Luna",
        "What now?" => "📞",
        "Say something" => "I'll tell her",
        _ => "[Show Luna's photo]",
      },
    );
    expect(ending.category, EndingCategory.secret);
    expect(engine.dataMap["NAME"], "Rin");

    final meta = await storage.loadMeta();
    expect(meta.unlockedMediaIds,
        {"photo_luna_cafe", "voice_miki_01", "video_last_evening", "photo_unsent_note", "cg_luna_cafe"});
    expect(meta.unlockedCheckpoints.keys, containsAll(["index", "day1", "day2"]));
  });

  test('true ending: apology after the call', () async {
    final (ending, _) = await _play(
      pick: (item) => switch (item.text) {
        "How do you reply?" => "Who is Luna",
        "What now?" => "📞",
        "Say something" => "I'll tell her",
        "What do you tell Luna?" => "Miki is sorry",
        _ => "",
      },
    );
    expect(ending.endingId, "end_01_true");
  });

  test('good ending: chat route to Nora\'s thread', () async {
    final (ending, engine) = await _play(
      pick: (item) => switch (item.text) {
        "\"Are you going to check it?\"" => "Nah",
        "How do you reply?" => "Who is Luna",
        "What now?" => "I'll find Luna",
        "What do you tell Luna?" => "Miki is sorry",
        _ => "",
      },
    );
    expect(ending.endingId, "end_02_good");
    expect(engine.currentScene?.channelId, "thread_nora");
  });

  test('bad ending: dismissive and silent', () async {
    final (ending, engine) = await _play(
      pick: (item) => switch (item.text) {
        "How do you reply?" => "Wrong number",
        "What now?" => "I'll find Luna",
        "What do you tell Luna?" => "Nothing",
        _ => "",
      },
    );
    expect(ending.endingId, "end_03_bad");
    expect(engine.dataMap["miki_trust"], -10);
  });

  test('prologue hub: the "once" question loops back and disappears, runs are counted across games', () async {
    final storage = InMemoryStoryStorage();
    final asked = <List<String>>[];
    await _play(
      storage: storage,
      pick: (item) {
        if (item.text == "\"Are you going to check it?\"") {
          asked.add(item.choices.map((c) => c.text).toList());
          return asked.length == 1 ? "Who had" : "Nah";
        }
        return "";
      },
    );
    expect(asked, hasLength(2));
    expect(asked[0], hasLength(3));
    expect(asked[1], isNot(contains(startsWith("Who had"))));
    expect((await storage.loadMeta()).persistent["runs"], 1);

    final (_, replay) = await _play(storage: storage, pick: (_) => "");
    expect(replay.state["persistent.runs"], 2);
  });

  test('catalog lists every collectible, ending and checkpoint', () async {
    final loader = AssetEngineLoader(const LoaderConfig());
    final catalog = await StoryCatalog.load(loader);
    expect(catalog.media, hasLength(5));
    expect(catalog.endings.map((e) => e.item.category), unorderedEquals(EndingCategory.values.toSet()..remove(EndingCategory.normal)));
    expect(catalog.checkpoints.map((c) => c.chapter), ["Prologue", "Day 1", "Day 2"]);

    final credits = await loader.loadCredits();
    expect(credits, isNotNull);
    expect(credits!.rollAfter, containsAll(["end_01_true", "end_04_secret"]));
  });

  test('Day 2 evidence question retries once on the wrong clue, then accepts proof', () async {
    var attempts = 0;
    final (ending, engine) = await _play(
      pick: (item) => switch (item.text) {
        "How do you reply?" => "Who is Luna",
        "What now?" => "I'll find Luna",
        "What do you tell Luna?" => "Miki is sorry",
        _ => "",
      },
      present: (_) => ++attempts == 1 ? "miki_voicemail" : "unsent_note",
    );
    expect(engine.clues.clues.map((c) => c.id), ["luna_photo", "miki_voicemail", "unsent_note"]);
    expect(attempts, 2);
    expect(engine.dataMap["PROOF"], "unsent_note");
    expect(ending.endingId, "end_02_good");
  });
}
