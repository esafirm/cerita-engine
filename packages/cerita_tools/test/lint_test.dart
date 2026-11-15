import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

const _bilingual = "source_locale: id\nlocales: [id, en]\n";
const _assets = {"bg/room.png", "sprites/nora_open.png", "sprites/nora_smile.png"};
const _noCast = "{}";
const _cast = "nora:\n  name: Nora\n  expressions:\n    open: nora_open.png\n    smile: nora_smile.png\n    sad: nora_sad.png\n"
    "bob:\n  name: Bob\n";

/// A story with script problems and JSON problems, to check both layers report with script lines.
const _broken = '''
@conversation index chapter="Hari 1"
@scene VN bg=room.png music=missing.mp3

nora:smirk
  id: Halo {{NAME}}
  en: Hello {{NAME}}

narration [if meta.flag.saw_boat || meta.ending.end_x || meta.lol]
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
  -> home#nowhere
? Tetap | Stay
  -> home

@conversation home
@scene CHAT
set unused 1
nora
  id: Sampai {b}tebal{/b} {shaek}
  en: Home
-> index
ending end_home GOOD
  id: Pulang
  en: Home

@conversation orphan
clue boat
narration label=start
  id: Sendiri
  en: Alone
narration label=start
  id: Lagi
  en: Again
-> index
''';

Future<List<String>> _lint(StoryProject project, {bool release = false}) async =>
    (await lintStory(project, release: release)).sorted().map((d) => d.format()).toList();

void main() {
  test('reports script and engine problems together, each at its script line', () async {
    expect(await _lint(story({"a.cerita": _broken}, config: _bilingual, profiles: _cast, assets: _assets)), [
      // Script checks.
      "a.cerita:1: warning: Missing 'en' text",
      // From cerita_core's StoryLinter, run on the compiled story.
      "a.cerita:2: error: Missing music file 'music/missing.mp3'",
      "a.cerita:4: error: Unknown expression 'smirk' for 'nora'. Known: open, smile, sad",
      "a.cerita:4: warning: Variable 'NAME' is read but never set",
      "a.cerita:8: error: Unknown memory variable 'meta.lol'. Use meta.ending.<ending_id> or meta.flag.<name>",
      "a.cerita:8: warning: Fact 'meta.flag.saw_boat' is read but never remembered with meta_set",
      "a.cerita:8: warning: No ENDING has ending_id 'end_x' (read as 'meta.ending.end_x')",
      "a.cerita:12: error: Bad expression: Unexpected end of 'trust >='",
      "a.cerita:12: warning: Variable 'trust' is read but never set",
      "a.cerita:16: error: Target 'cafe' doesn't exist",
      "a.cerita:16: error: Target 'home#nowhere' has no item with id 'nowhere'",
      "a.cerita:16: warning: Variable 'trsut' is read but never set",
      "a.cerita:17: warning: Missing 'en' text",
      "a.cerita:26: error: CHAT scene without a channel_id",
      "a.cerita:27: warning: Variable 'unused' is set but never read",
      "a.cerita:28: warning: Unknown text tag '{shaek}'",
      "a.cerita:32: warning: Never reached: it follows a JUMP or RETURN",
      "a.cerita:36: warning: No target leads to this conversation",
      "a.cerita:37: error: 'clue' is reserved for the Case Board (CE-05) and isn't supported yet",
      "a.cerita:41: error: Duplicate id 'start'",
      "profiles.yaml:5: warning: Expression 'nora:smile' is never used",
      "profiles.yaml:6: error: Missing sprite file 'sprites/nora_sad.png'",
      "profiles.yaml:6: warning: Expression 'nora:sad' is never used",
      "profiles.yaml:7: warning: Character 'bob' is never used",
    ]);
  });

  test('--release turns every warning into an error', () async {
    final project = story({"a.cerita": "@conversation index\nending end GOOD\n  id: Tamat\n"}, config: _bilingual, profiles: _noCast, assets: _assets);
    expect(await _lint(project), ["a.cerita:3: warning: Missing 'en' text"]);
    expect(await _lint(project, release: true), ["a.cerita:3: error: Missing 'en' text"]);
  });

  test('a voice clip can ship per locale instead of shared (CE-01)', () async {
    const script = "@conversation index\nnora voice=vo_01.mp3\n  id: Hai\n  en: Hi\nending end GOOD\n  id: T\n  en: E\n";
    final perLocale = {..._assets, "music/vo_01.id.mp3", "music/vo_01.en.mp3"};
    expect(await _lint(story({"a.cerita": script}, config: _bilingual, profiles: "nora:\n  name: Nora\n  expressions:\n    open: nora_open.png\n", assets: perLocale)), isEmpty);
    expect(await _lint(story({"a.cerita": script}, config: _bilingual, profiles: "nora:\n  name: Nora\n  expressions:\n    open: nora_open.png\n", assets: {..._assets, "music/vo_01.id.mp3"})),
        ["a.cerita:2: error: Missing voice file 'music/vo_01.mp3'"]);
  });

  test('asset checks are skipped with a note while drafting and required in release mode', () async {
    final project = story({"a.cerita": "@conversation index\nending end GOOD\n  en: The end\n"}, profiles: _noCast);
    expect(await _lint(project), ["note: Asset checks skipped: set 'assets' in cerita.yaml or pass --assets"]);
    expect(await _lint(project, release: true),
        ["error: Release checks need the asset folder: set 'assets' in cerita.yaml or pass --assets"]);
  });

  test('a story needs an index conversation', () async {
    expect(await _lint(story({"a.cerita": "@conversation start\nending end GOOD\n  en: E\n"}, profiles: _noCast, assets: {})),
        ["error: No 'index' conversation. The story starts at '@conversation index'"]);
  });

  test('syntax errors are all reported and parsing carries on', () async {
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
stage
  show
  spin nora
  move nora middle
-> nowhere#
ending end GOOD
  en: The end
  -> index
""",
    }, assets: _assets);
    expect(await _lint(project), [
      "a.cerita:1: error: Statements must come after an @conversation line",
      "a.cerita:4: error: @scene needs a mode: VN, CHAT or CALL",
      "a.cerita:5: error: Missing text: a line needs text, e.g. '  en: ...'",
      "a.cerita:5: error: Unknown attribute 'mood'",
      "a.cerita:5: error: Unknown modifier '[up]'",
      "a.cerita:6: error: Unknown locale 'fr'. The story's locales are en",
      "a.cerita:7: error: Unknown line '+'",
      "a.cerita:8: error: An option must follow a choice or another option",
      "a.cerita:9: error: media needs a file name",
      "a.cerita:11: error: show needs a character",
      "a.cerita:12: error: Unknown stage action 'spin'",
      "a.cerita:13: error: Unknown position 'middle'. Use far_left, left, center, right, far_right",
      "a.cerita:14: error: Invalid target 'nowhere#'. Use day2, #label or day2#label",
      "a.cerita:17: error: A target only goes under a choice option or in a branch",
      "profiles.yaml:5: warning: Expression 'nora:smile' is never used",
    ]);
  });

  test('statements under a broken @conversation belong to no conversation', () {
    final project = story({"a.cerita": "@conversation index\nending end GOOD\n  en: E\n@conversation bad-key\nnarration\n  en: Lost\n"});
    expect(project.conversations.single.items, hasLength(1));
    expect(project.diagnostics.items.map((d) => d.format()),
        ["a.cerita:4: error: Invalid conversation key 'bad-key': use letters, digits and _"]);
  });

  test('Wrong Number has no problems, even in release mode', () async {
    expect(await _lint(loadWrongNumber(), release: true), isEmpty);
  });
}
