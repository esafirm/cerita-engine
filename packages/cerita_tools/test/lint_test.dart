import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

const _bilingual = "source_locale: id\nlocales: [id, en]\n";
const _assets = {"bg/room.png", "sprites/nora_open.png", "sprites/nora_smile.png"};

/// A story with one of every problem the linter knows.
const _broken = '''
@conversation index chapter="Hari 1"
@scene VN bg=room.png music=missing.mp3

nora:smirk
  id: Halo {{NAME}}
  en: Hello {{NAME}}

narration label=start [if meta.flag.saw_boat || meta.ending.end_x || clue.boat]
  id: Lagi?
  en: Again?

narration label=start [if trust >= ]
  id: Rusak
  en: Broken

choice
  id: Pilih
? Ke kafe | To the cafe
  -> cafe
? Ke rumah | Home [if trsut > 3]
  -> home

@conversation home
@scene CHAT
nora
  id: Sampai
  en: Home
-> index
ending end_home GOOD
  id: Pulang
  en: Home

@conversation orphan
clue boat
narration
  id: Sendiri
  en: Alone

@conversation home
narration
  id: Dua
  en: Twice
''';

List<String> _lint(StoryProject project, {bool release = false}) =>
    lintStory(project, release: release).sorted().map((d) => d.format()).toList();

void main() {
  test('reports every problem with its file and line', () {
    expect(_lint(story({"a.cerita": _broken}, config: _bilingual, assets: _assets)), [
      "a.cerita:1: warning: Missing 'en' text",
      "a.cerita:2: error: Missing music file 'music/missing.mp3'",
      "a.cerita:4: error: Unknown expression 'smirk' for 'nora'. Known: open, smile",
      "a.cerita:5: error: Variable 'NAME' is read but never set",
      "a.cerita:6: error: Variable 'NAME' is read but never set",
      "a.cerita:8: error: Memory flag 'saw_boat' is read but no 'remember saw_boat' sets it",
      "a.cerita:8: error: Unknown ending 'end_x' in 'meta.ending.end_x'",
      "a.cerita:8: error: Unknown name 'clue.boat'. Dotted names are meta.ending.<id> and meta.flag.<name>",
      "a.cerita:12: error: Duplicate label 'start' in 'index'",
      "a.cerita:12: error: Invalid condition 'trust >=': Unexpected end",
      "a.cerita:17: warning: Missing 'en' text",
      "a.cerita:19: error: Target 'cafe' doesn't exist",
      "a.cerita:20: error: Variable 'trsut' is read but never set",
      "a.cerita:24: error: A CHAT scene needs channel=",
      "a.cerita:29: error: Ending 'end_home' can't be reached",
      "a.cerita:33: error: Conversation 'orphan' can't be reached from index",
      "a.cerita:34: error: 'clue' is reserved for the Case Board (CE-05) and isn't supported yet",
      "a.cerita:39: error: Conversation 'home' is also declared at a.cerita:23",
    ]);
  });

  test('--release turns missing translations into errors', () {
    final project = story({"a.cerita": "@conversation index\nending end GOOD\n  id: Tamat\n"}, config: _bilingual, assets: _assets);
    expect(_lint(project), ["a.cerita:3: warning: Missing 'en' text"]);
    expect(_lint(project, release: true), ["a.cerita:3: error: Missing 'en' text"]);
  });

  test('asset checks are skipped with a note while drafting and required in release mode', () {
    final project = story({"a.cerita": "@conversation index\nending end GOOD\n  en: The end\n"});
    expect(_lint(project), ["note: Asset checks skipped: set 'assets' in cerita.yaml or pass --assets"]);
    expect(_lint(project, release: true),
        ["error: Release checks need the asset folder: set 'assets' in cerita.yaml or pass --assets"]);
  });

  test('a route that runs out of items stops the story', () {
    final project = story({
      "a.cerita": "@conversation index\nchoice\n  en: Go?\n? Yes\n  -> next\n? No\n"
          "@conversation next\n-> index [if again]\n",
    }, assets: _assets);
    expect(_lint(project), [
      "a.cerita:2: error: The story stops here: 'index' can run out of items without an ending or a jump",
      "a.cerita:8: error: The story stops here: 'next' can run out of items without an ending or a jump",
      "a.cerita:8: error: Variable 'again' is read but never set",
    ]);
  });

  test('a story needs an index conversation', () {
    expect(_lint(story({"a.cerita": "@conversation start\nending end GOOD\n  en: E\n"}, assets: _assets)),
        ["error: No 'index' conversation. The story starts at '@conversation index'"]);
  });

  test('syntax errors are all reported and parsing carries on', () {
    final project = story({
      "a.cerita": """
narration
  en: Too early
@conversation index
@scene WEB
nora [up] mood=sad
  fr: Bonjour
  +
? Orphan option
media IMAGE
ending end GOOD
  en: The end
  -> index
""",
    }, assets: _assets);
    expect(_lint(project), [
      "a.cerita:1: error: Statements must come after an @conversation line",
      "a.cerita:4: error: @scene needs a mode: VN, CHAT or CALL",
      "a.cerita:5: error: Missing text: a line needs text, e.g. '  en: ...'",
      "a.cerita:5: error: Unknown attribute 'mood'",
      "a.cerita:5: error: Unknown modifier '[up]'",
      "a.cerita:6: error: Unknown locale 'fr'. The story's locales are en",
      "a.cerita:7: error: Unknown line '+'",
      "a.cerita:8: error: An option must follow a choice or another option",
      "a.cerita:9: error: media needs a file name",
      "a.cerita:12: error: A target only goes under a choice option or in a branch",
    ]);
  });

  test('statements under a broken @conversation belong to no conversation', () {
    final project = story({"a.cerita": "@conversation index\nending end GOOD\n  en: E\n@conversation bad-key\nnarration\n  en: Lost\n"});
    expect(project.conversations.single.items, hasLength(1));
    expect(project.diagnostics.items.map((d) => d.format()),
        ["a.cerita:4: error: Invalid conversation key 'bad-key': use letters, digits and _"]);
  });

  test('Wrong Number has no problems, even in release mode', () {
    expect(_lint(loadWrongNumber(), release: true), isEmpty);
  });
}
