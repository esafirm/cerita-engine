import 'dart:convert';

import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

const _bilingual = "source_locale: id\nlocales: [id, en]\n";

Map<String, dynamic> _compileOne(StoryProject project, [String file = "index.json"]) {
  final result = compileStory(project);
  expect(result.diagnostics.items.where((d) => d.severity == Severity.error), isEmpty);
  return jsonDecode(result.files[file]!) as Map<String, dynamic>;
}

void main() {
  group('Wrong Number', () {
    test('compiles to the hand-written JSON', () {
      final result = compileStory(loadWrongNumber());
      expect(result.diagnostics.items, isEmpty);
      final compiled = {for (final entry in result.files.entries) entry.key: jsonDecode(entry.value)};
      final expected = exampleStoryJson();
      expect(compiled.keys, unorderedEquals(expected.keys));
      for (final file in expected.keys) {
        expect(compiled[file], expected[file], reason: file);
      }
    });

    test('compiles to identical text twice', () {
      expect(compileStory(loadWrongNumber()).files, compileStory(loadWrongNumber()).files);
    });
  });

  test('a bilingual line compiles to an object of locale to text, in locales order', () {
    final json = _compileOne(story({
      "a.cerita": """
@conversation index chapter="Hari 1" chapter.en="Day 1"
nora:smile
  en: Hi
  id: Hai
choice
  id: Jadi?
  en: So?
? Ya | Yes
  -> index
? Tidak
  -> index
""",
    }, config: _bilingual));
    expect(json["chapter"], {"id": "Hari 1", "en": "Day 1"});
    final [line, choice] = json["conversations"] as List;
    expect((line as Map).keys.first, "type");
    expect(jsonEncode(line["text"]), '{"id":"Hai","en":"Hi"}');
    expect(choice["choices"][0]["text"], {"id": "Ya", "en": "Yes"});
    expect(choice["choices"][1]["text"], {"id": "Tidak"});
  });

  test('expressions by name compile to <id>:<index> and the cast to profiles.json', () {
    final result = compileStory(story({
      "a.cerita": "@conversation index\nnora:smile\n  en: Hi\nnora\n  en: Yo\nplayer\n  en: Hey\n",
    }, profiles: "nora:\n  id: 123aaa\n  name: Nora\n  expressions:\n    open: o.png\n    smile: s.png\n"));
    final items = jsonDecode(result.files["index.json"]!)["conversations"] as List;
    expect(items.map((i) => i["profile"]), ["123aaa:1", "123aaa:0", "player"]);
    expect(jsonDecode(result.files["profiles.json"]!), {
      "profiles": [
        {"id": "123aaa", "name": "Nora", "sprites": ["o.png", "s.png"]},
      ],
    });
  });

  test('remember compiles to meta_set and meta conditions pass through', () {
    final json = _compileOne(story({
      "a.cerita": """
@conversation index
narration [if meta.ending.end_a && !meta.flag.saw_boat]
  en: Again?
  remember saw_boat
  +trust
  -trust 2
  set mood "very happy"
  toggle lights
ending end_a GOOD
  en: A
""",
    }));
    final narration = (json["conversations"] as List).first;
    expect(narration["condition"], "meta.ending.end_a && !meta.flag.saw_boat");
    expect(narration["effects"], [
      {"variable": "saw_boat", "op": "meta_set"},
      {"variable": "trust", "op": "add", "value": 1},
      {"variable": "trust", "op": "subtract", "value": 2},
      {"variable": "mood", "op": "set", "value": "very happy"},
      {"variable": "lights", "op": "toggle"},
    ]);
  });

  test('a {locale} voice template names one clip per locale', () {
    final json = _compileOne(story({
      "a.cerita": "@conversation index\nnora voice=vo_01.{locale}.mp3\n  id: Hai\n  en: Hi\n"
          "nora voice=vo_02.mp3 voice.en=vo_02.en.mp3\n  id: Hai\n  en: Hi\n",
    }, config: _bilingual));
    final [first, second] = json["conversations"] as List;
    expect(first["voice"], {"id": "vo_01.id.mp3", "en": "vo_01.en.mp3"});
    expect(second["voice"], {"id": "vo_02.mp3", "en": "vo_02.en.mp3"});
  });

  test('a choice timeout and [default] compile to timeout_ms and default_choice', () {
    final json = _compileOne(story({
      "a.cerita": "@conversation index\nchoice PICK timeout=10s\n  en: Pick\n? A\n  value 1\n? B [default]\n  value b\n",
    }));
    final choice = (json["conversations"] as List).single;
    expect(choice["timeout_ms"], 10000);
    expect(choice["default_choice"], 1);
    expect(choice["choices"].map((c) => c["value"]), [1, "b"]);
  });

  test('fails without output on syntax errors and unknown speakers or expressions', () {
    final result = compileStory(story({
      "a.cerita": "@conversation index\nnora:sad\n  en: Hi\nbob\n  en: Hi\nwait soon\n",
    }));
    expect(result.ok, isFalse);
    expect(result.files, isEmpty);
    expect(result.diagnostics.sorted().map((d) => d.format()), [
      "a.cerita:2: error: Unknown expression 'sad' for 'nora'. Known: open, smile",
      "a.cerita:4: error: Unknown character 'bob'",
      "a.cerita:6: error: Invalid duration 'soon'",
    ]);
  });
}
