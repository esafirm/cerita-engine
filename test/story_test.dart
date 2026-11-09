import 'package:flutter_test/flutter_test.dart';
import 'package:fsse/fsse.dart';

/// Plays the bundled demo story headlessly, so every route and JSON file is exercised.
Future<(EndingItemType, RealFsseEngine)> _play({
  required String Function(ChoiceItemType item) pick,
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

  test('catalog lists every collectible, ending and checkpoint', () async {
    final catalog = await StoryCatalog.load(AssetEngineLoader(const LoaderConfig()));
    expect(catalog.media, hasLength(5));
    expect(catalog.endings.map((e) => e.item.category), unorderedEquals(EndingCategory.values.toSet()..remove(EndingCategory.normal)));
    expect(catalog.checkpoints.map((c) => c.chapter), ["Prologue", "Day 1", "Day 2"]);
  });
}
