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
      "a.cerita:17: warning: Missing 'en' text",
      "a.cerita:19: error: Target 'cafe' doesn't exist",
      "a.cerita:20: warning: Variable 'trsut' is read but never set",
      "a.cerita:21: error: Target 'home#nowhere' has no item with id 'nowhere'",
      "a.cerita:26: error: CHAT scene without a channel_id",
      "a.cerita:27: warning: Variable 'unused' is set but never read",
      "a.cerita:28: warning: Unknown text tag '{shaek}'",
      "a.cerita:32: warning: Never reached: it follows a JUMP or RETURN",
      "a.cerita:36: warning: No target leads to this conversation",
      "a.cerita:37: error: Clue 'boat' isn't declared: add it to clues.yaml",
      "a.cerita:37: warning: Variable 'clue_boat' is set but never read",
      "a.cerita:41: error: Duplicate id 'start'",
      "profiles.yaml:5: warning: Expression 'nora:smile' is never used",
      "profiles.yaml:6: error: Missing sprite file 'sprites/nora_sad.png'",
      "profiles.yaml:6: warning: Expression 'nora:sad' is never used",
      "profiles.yaml:7: warning: Character 'bob' is never used",
    ]);
  });

  test('engine problems inside an item point at the effect, stage action or route line', () async {
    const script = '''
@conversation index
@scene VN bg=room.png
set
  +trust 1
  set roll = rnd(1, 6)
stage
  show nora
  music gone.mp3
branch
  if trust > roll -> nowhere
  -> index
''';
    const cast = "nora:\n  name: Nora\n  expressions:\n    open: nora_open.png\n";
    expect(await _lint(story({"a.cerita": script}, profiles: cast, assets: _assets)), [
      "a.cerita:5: error: Bad expression: Unknown function 'rnd' in 'rnd(1, 6)'",
      "a.cerita:8: error: Missing music file 'music/gone.mp3'",
      "a.cerita:10: error: Target 'nowhere' doesn't exist",
    ]);
  });

  test('clue and evidence problems point at the clue line, the answer line or clues.yaml', () async {
    const clues = "clues:\n  boat:\n    title: { id: Perahu }\n    image: clue_boat.png\n  log:\n    title: Log\n";
    const script = '''
@conversation index
@scene VN bg=room.png
evidence
  id: Yang mana?
  en: Which?
? boat
  -> nowhere
? ghost
  set x = rnd(1)
? [fallback]
  -> index
clue phantom
clue boat
ending e GOOD
  id: T
  en: E
''';
    final project = story({"a.cerita": script}, config: _bilingual, clues: clues, profiles: _noCast, assets: _assets);
    expect(await _lint(project), [
      "a.cerita:3: error: No clue with a response can be found before this evidence question",
      "a.cerita:7: error: Target 'nowhere' doesn't exist",
      "a.cerita:8: error: Clue 'ghost' isn't declared in clues.yaml",
      "a.cerita:9: error: Bad expression: Unknown function 'rnd' in 'rnd(1)'",
      "a.cerita:9: warning: Variable 'x' is set but never read",
      "a.cerita:12: error: Clue 'phantom' isn't declared in clues.yaml (used as 'clue_phantom')",
      "clues.yaml:3: warning: Missing 'en' text",
      "clues.yaml:4: error: Missing clue image file 'media/clue_boat.png'",
      "clues.yaml:5: warning: Clue 'log' is never awarded: no effect sets 'clue_log'",
    ]);
  });

  test('evidence syntax errors, and clues without clues.yaml', () async {
    const script = '''
@conversation index
evidence
  en: Which?
? [fallback]
? [fallback]
? not a clue
? pier
  en: words
  value 3
evidence
  en: Again?
? [retry]
clue bad-id
clue boat
ending e GOOD
  en: E
''';
    expect(await _lint(story({"a.cerita": script}, profiles: _noCast, assets: {})), [
      "a.cerita:2: error: No clue with a response can be found before this evidence question",
      "a.cerita:5: error: An evidence question has only one [fallback]",
      "a.cerita:6: error: An evidence answer is a clue id, or [retry], [fallback] or [timeout]",
      "a.cerita:7: error: Clue 'pier' isn't declared in clues.yaml",
      "a.cerita:8: error: An evidence answer has no text: the player presents the clue",
      "a.cerita:9: error: value doesn't go under an evidence answer: the presented clue's id is stored",
      "a.cerita:10: error: Evidence question without responses",
      "a.cerita:10: error: No clue with a response can be found before this evidence question",
      "a.cerita:13: error: Invalid clue id 'bad-id': use letters, digits and _",
      "a.cerita:14: error: Clue 'boat' isn't declared: add it to clues.yaml",
      "a.cerita:14: warning: Variable 'clue_boat' is set but never read",
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

  test('`choice silent` next to a read of a variable named silent is reported', () async {
    const choice = "@conversation index\nchoice silent\n  en: Reply?\n? Yes\n? No\n";
    Future<List<String>> silentIssues(String rest) async => [
          for (final issue in await _lint(story({"a.cerita": "$choice$rest"})))
            if (issue.contains("silent")) issue,
        ];

    expect(await silentIssues("nora [if silent == 'Yes']\n  en: Good\nending e GOOD\n  en: E\n"), [
      "a.cerita:2: error: `silent` is a keyword here, so this choice stores no variable, but the story reads "
          "'silent'. Name the variable differently, e.g. choice PICK silent",
      "a.cerita:6: warning: Variable 'silent' is read but never set",
    ]);
    expect(await silentIssues("nora\n  en: You said {{silent}}\nending e GOOD\n  en: E\n"), hasLength(2));
    expect(await silentIssues("nora\n  en: Good\nending e GOOD\n  en: E\n"), isEmpty,
        reason: "a silent choice without a variable is fine when nothing reads one");
  });

  test('Wrong Number has no problems, even in release mode', () async {
    expect(await _lint(loadWrongNumber(), release: true), isEmpty);
  });
}
