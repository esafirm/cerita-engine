import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

/// At 60 wpm a word takes a second, so every number below can be checked by hand.
const _config = """
source_locale: en
locales: [en, id]
stats:
  wpm: { en: 60, id: 30 }
  choice_seconds: 2
  input_seconds: 5
  media_seconds: 3
""";

const _script = """
@conversation index chapter=One
narration
  en: one two three four
nora typing=1s
  en: hello {{NAME}}
choice
  en: Go where?
? Left
  -> left
? Right
  -> right

@conversation left chapter=Two
wait 10s
narration [if lucky]
  en: maybe this
ending end_left GOOD
  en: Left

@conversation right chapter=Two
ending end_right BAD
  en: Right end
  id: Tamat kanan
""";

void main() {
  final stats = storyStats(story({"a.cerita": _script}, config: _config));

  test('counts words and time per conversation and chapter', () {
    expect([for (final c in stats.conversations) (c.key, c.total.words, c.total.seconds)], [
      ("index", 10, 13.0), // 4 words, 2 words + 1s typing, 4 words + 2s to decide
      ("left", 3, 13.0), // 10s wait, 2 words, 1 word
      ("right", 2, 2.0),
    ]);
    expect([for (final c in stats.chapters) (c.name, c.total.words, c.total.seconds)], [
      ("One", 10, 13.0),
      ("Two", 5, 15.0),
    ]);
  });

  test('finds the shortest and longest run to each ending and the critical path', () {
    final left = stats.endings.firstWhere((e) => e.id == "end_left");
    expect(left.shortest.measure.seconds, 24); // skips the conditional narration
    expect(left.longest.measure.seconds, 26);
    expect(left.longest.path, ["index", "left"]);
    final right = stats.endings.firstWhere((e) => e.id == "end_right");
    expect((right.shortest.measure.seconds, right.longest.measure.seconds), (15, 15));
    expect(stats.criticalPath!.measure.seconds, 26);
    expect(stats.criticalPath!.measure.words, 13);
  });

  test('reads another locale at its own speed, falling back to the source text', () {
    final id = storyStats(story({"a.cerita": _script}, config: _config), locale: "id");
    expect(id.wpm, 30);
    final right = id.conversations.firstWhere((c) => c.key == "right");
    expect((right.total.words, right.total.seconds), (2, 4.0));
    final index = id.conversations.firstWhere((c) => c.key == "index");
    expect((index.total.words, index.total.seconds), (10, 23.0)); // English text at 30 wpm
  });

  test('--wpm overrides the configured speed', () {
    expect(storyStats(story({"a.cerita": _script}, config: _config), wpm: 120).conversations.last.total.seconds, 1);
  });

  test('a CALL takes as long as the section it calls, and a STAGE as long as its longest action', () {
    final called = storyStats(story({
      "a.cerita": "@conversation index\ncall shared#bit\nstage\n  shake\n  flash duration=2s\nending end GOOD\n  en: E\n"
          "@conversation shared\nnarration\n  en: skipped\nnarration label=bit\n  en: one two three\nreturn\nnarration\n  en: after return\n",
    }, config: _config));
    // 3 words in the called section, 2 s of stage, 1 word of ending title.
    expect(called.endings.single.longest.measure.seconds, 6);
  });

  test('counts words across scripts and placeholders', () {
    expect(countWords("Hai, {{NAME}}! 🙏 ...kidding — ok"), 4);
  });

  test('Wrong Number has a run to each of its four endings', () {
    final wrongNumber = storyStats(loadWrongNumber());
    expect(wrongNumber.endings.map((e) => e.id),
        unorderedEquals(["end_01_true", "end_02_good", "end_03_bad", "end_04_secret"]));
    for (final ending in wrongNumber.endings) {
      expect(ending.shortest.measure.seconds, lessThanOrEqualTo(ending.longest.measure.seconds));
      expect(ending.longest.path.first, "index");
    }
    expect(wrongNumber.criticalPath!.path, contains("call_miki"));
  });
}
