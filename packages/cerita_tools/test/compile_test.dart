import 'dart:convert';

import 'package:cerita_core/cerita_core.dart' as core;
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
      // CE-01 adds source_locale to index.json. Until example/ has it, it's the one key allowed to differ.
      final index = expected["index.json"] as Map;
      if (!index.containsKey("source_locale")) {
        expect((compiled["index.json"] as Map).remove("source_locale"), "en");
      }
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
    expect(json["source_locale"], "id");
    expect(json["locales"], ["id", "en"]);
    expect(json["chapter"], {"id": "Hari 1", "en": "Day 1"});
    final [line, choice] = json["conversations"] as List;
    expect((line as Map).keys.first, "type");
    expect(jsonEncode(line["text"]), '{"id":"Hai","en":"Hi"}');
    expect(choice["choices"][0]["text"], {"id": "Ya", "en": "Yes"});
    expect(choice["choices"][1]["text"], {"id": "Tidak"});
  });

  test('a held cg compiles its Gallery title and caption per locale', () {
    final json = _compileOne(story({
      "a.cerita": """
@conversation index
stage
  cg cg_storm.png unlock=cg_storm title="Badai" title.en="The Storm" caption.en="Pluit, 2 AM"
""",
    }, config: _bilingual));
    final [stage] = json["conversations"] as List;
    expect(stage["actions"], [
      {
        "action": "cg",
        "image": "cg_storm.png",
        "unlock_id": "cg_storm",
        "title": {"id": "Badai", "en": "The Storm"},
        "caption": {"en": "Pluit, 2 AM"},
      },
    ]);
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

  test('voice stays one file name, which the player tries per locale first (CE-01)', () {
    final json = _compileOne(story({
      "a.cerita": "@conversation index\nnora voice=vo_01.mp3\n  id: Hai\n  en: Hi\nmedia AUDIO vn_01.mp3 by=nora\n  id: Halo\n",
    }, config: _bilingual));
    final [line, note] = json["conversations"] as List;
    expect(line["voice"], "vo_01.mp3");
    expect(note["uri"], "vn_01.mp3");
    expect(note["transcript"], {"id": "Halo"});
  });

  test('every engine item has a script form', () {
    final json = _compileOne(story({
      "a.cerita": """
@conversation index
@scene VN bg=room.png music=theme.mp3 ambience=rain.mp3 textbox=nvl
+persistent.runs
set coin = random(0, 1)
remember saw_intro
set [if coin == 1] label=lucky
  set mood "very happy"
  -trust 2
stage wait=0
  show nora:smile far_left transition=slide_left duration=0.7s
  move nora far_right
  hide nora transition=none
  clear
  background none
  music none fade=2s
  ambience rain.mp3
  sound door.mp3
  weather sakura
  shake intensity=8 duration=400
  flash color=#E05050
  zoom 1.2 focus=left
  cg cg_storm.png unlock=cg_storm focus=left transition=dissolve
  cg_move zoom=1.3 focus=top_right duration=8s
  cg none
  textbox adv
  page
  +staged
choice label=hub
  en: Ask?
? Again [once]
  -> #hub
? Remember? [if meta.flag.saw_intro] [memory_marker]
  -> shared#start
? Leave
call shared#start
-> next [if coin == 0]
return

@conversation shared
narration label=start
  en: Shared
return
""",
    }));
    final items = json["conversations"] as List;
    expect(json["scene"], {"mode": "VN", "background": "room.png", "music": "theme.mp3", "ambience": "rain.mp3", "textbox": "nvl"});
    // Effect lines that follow each other at column 0 share one SET.
    expect(items.take(2), [
      {
        "type": "SET",
        "effects": [
          {"variable": "persistent.runs", "op": "add", "value": 1},
          {"variable": "coin", "op": "set", "expr": "random(0, 1)"},
          {"variable": "saw_intro", "op": "meta_set"},
        ],
      },
      {
        "type": "SET",
        "id": "lucky",
        "condition": "coin == 1",
        "effects": [{"variable": "mood", "op": "set", "value": "very happy"}, {"variable": "trust", "op": "subtract", "value": 2}],
      },
    ]);
    expect(items[2], {
      "type": "STAGE",
      "wait_ms": 0,
      "actions": [
        {"action": "show", "profile": "nora:1", "position": "far_left", "transition": "slide_left", "duration_ms": 700},
        {"action": "move", "profile": "nora", "position": "far_right"},
        {"action": "hide", "profile": "nora", "transition": "none"},
        {"action": "clear"},
        {"action": "background", "image": null},
        {"action": "music", "file": null, "fade_ms": 2000},
        {"action": "ambience", "file": "rain.mp3"},
        {"action": "sound", "file": "door.mp3"},
        {"action": "weather", "name": "sakura"},
        {"action": "shake", "intensity": 8, "duration_ms": 400},
        {"action": "flash", "color": "#E05050"},
        {"action": "zoom", "scale": 1.2, "focus": "left"},
        {"action": "cg", "image": "cg_storm.png", "unlock_id": "cg_storm", "focus": "left", "transition": "dissolve"},
        {"action": "cg_move", "zoom": 1.3, "focus": "top_right", "duration_ms": 8000},
        {"action": "cg", "image": null},
        {"action": "textbox", "style": "adv"},
        {"action": "page"},
      ],
      "effects": [{"variable": "staged", "op": "add", "value": 1}],
    });
    expect(items[3]["choices"], [
      {"text": "Again", "once": true, "target": "#hub"},
      {"text": "Remember?", "condition": "meta.flag.saw_intro", "memory_marker": true, "target": "shared#start"},
      {"text": "Leave"},
    ]);
    expect(items.skip(4), [
      {"type": "CALL", "target": "shared#start"},
      {"type": "JUMP", "condition": "coin == 0", "target": "next"},
      {"type": "RETURN"},
    ]);
  });

  test('clues.yaml compiles to clues.json, clue lines award clues and evidence compiles to an evidence question', () {
    const clues = """
show_counts: true
clues:
  pier_photo:
    title: { id: Foto dermaga, en: Pier photo }
    description: { id: Ada perahu., en: There's a boat. }
    image: clue_pier.png
    key: true
    chapter: { id: Hari 2, en: Day 2 }
  harbor_log:
    title: Harbor log
""";
    final project = story({
      "a.cerita": """
@conversation index
clue pier_photo
choice
  id: Ke mana?
  en: Where to?
? Pelabuhan | Harbor
  clue harbor_log
  -> #ask
? Pulang | Home
  -> #ask
evidence PRESENTED by=nora timeout=20s retries=1 label=ask
  id: Petunjuk mana?
  en: Which clue?
? harbor_log
  -trust 2
  -> #caught
? pier_photo
? [retry]
? [fallback]
  -trust 5
  -> #caught
? [timeout]
  -> #caught
ending caught GOOD label=caught
  id: Ketahuan
  en: Caught
""",
    }, config: _bilingual, clues: clues);
    final result = compileStory(project);
    expect(result.diagnostics.items, isEmpty);
    expect(jsonDecode(result.files["clues.json"]!), {
      "show_counts": true,
      "clues": [
        {
          "id": "pier_photo",
          "title": {"id": "Foto dermaga", "en": "Pier photo"},
          "description": {"id": "Ada perahu.", "en": "There's a boat."},
          "image": "clue_pier.png",
          "key": true,
          "chapter": {"id": "Hari 2", "en": "Day 2"},
        },
        {"id": "harbor_log", "title": "Harbor log"},
      ],
    });

    final items = (jsonDecode(result.files["index.json"]!) as Map)["conversations"] as List;
    expect(items[0], {
      "type": "SET",
      "effects": [{"variable": "clue_pier_photo", "op": "set", "value": true}],
    });
    final harbor = (items[1]["choices"] as List).first as Map;
    expect(harbor["effects"], [{"variable": "clue_harbor_log", "op": "set", "value": true}]);
    expect(items[2], {
      "type": "CHOICE",
      "id": "ask",
      "source": "clues",
      "text": {"id": "Petunjuk mana?", "en": "Which clue?"},
      "variable": "PRESENTED",
      "profile": "nora:0",
      "timeout_ms": 20000,
      "retries": 1,
      "responses": [
        {"clue": "harbor_log", "effects": [{"variable": "trust", "op": "subtract", "value": 2}], "target": "#caught"},
        {"clue": "pier_photo"},
      ],
      "retry": {},
      "fallback": {"effects": [{"variable": "trust", "op": "subtract", "value": 5}], "target": "#caught"},
      "timeout": {"target": "#caught"},
    });

    // The engine reads it as an evidence question.
    final question = core.ItemType.fromJson(Map<String, dynamic>.from(items[2] as Map));
    expect(question, isA<core.EvidenceItemType>());
    final responses = (question as core.EvidenceItemType).responses;
    expect(responses.map((response) => response.clue), ["harbor_log", "pier_photo"]);
    expect(question.retries, 1);
  });

  test('[offstage] compiles to "offstage": true and has no position', () {
    final json = _compileOne(story({
      "a.cerita": "@conversation index\nnora:smile [offstage] voice=tape.mp3\n  en: Hello?\nnora\n  en: Hi\n",
    }));
    final [offstage, onStage] = json["conversations"] as List;
    expect(offstage["offstage"], isTrue);
    expect(offstage["voice"], "tape.mp3");
    expect(onStage.containsKey("offstage"), isFalse);

    final result = compileStory(story({"a.cerita": "@conversation index\nnora [offstage] [left]\n  en: Hi\n"}));
    expect(result.diagnostics.sorted().map((d) => d.format()), ["a.cerita:2: error: An [offstage] line has no position"]);
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

  test('[silent] marks one option and a silent choice marks them all', () {
    final json = _compileOne(story({
      "a.cerita": "@conversation index\nchoice PICK\n  en: Pick\n? Say hi\n? Say nothing [silent]\n"
          "choice silent\n  en: Reply?\n? Type \"sorry\"\n? Close the app\n",
    }));
    final [one, all] = json["conversations"] as List;
    expect(one["variable"], "PICK");
    expect(one.containsKey("silent"), isFalse);
    expect(one["choices"].map((c) => c["silent"]), [null, true]);
    expect(all["silent"], isTrue);
    expect(all.containsKey("variable"), isFalse, reason: "`silent` isn't taken as the variable");
  });

  test('`silent` on a choice line is a keyword: never a variable, and a silent choice needs none', () {
    final json = _compileOne(story({
      "a.cerita": "@conversation index\nchoice silent by=nora timeout=5s\n  en: Reply?\n? Ok\n"
          "choice PICK silent\n  en: Pick\n? A\n",
    }));
    final [bySpeaker, named] = json["conversations"] as List;
    expect(bySpeaker["silent"], isTrue);
    expect(bySpeaker.containsKey("variable"), isFalse);
    expect(bySpeaker["profile"], startsWith("nora"));
    expect(named["variable"], "PICK");
    expect(named["silent"], isTrue);

    final result = compileStory(story({"a.cerita": "@conversation index\nchoice silent silent\n  en: Pick\n? A\n"}));
    expect(result.diagnostics.sorted().map((d) => d.format()),
        ["a.cerita:2: error: `silent` is a keyword here, name the variable differently"]);
  });

  test('ring= makes a CALL scene ring in, and only a CALL scene', () {
    final json = _compileOne(story({
      "a.cerita": "@conversation index\n@scene CALL ring=ring.mp3\nnora\n  en: Hi\n",
    }));
    expect(json["scene"], {"mode": "CALL", "ring": "ring.mp3"});
    expect(core.Scene.fromJson(json["scene"] as Map<String, dynamic>).ring, "ring.mp3");

    final result = compileStory(story({"a.cerita": "@conversation index\n@scene VN ring=ring.mp3\nnora\n  en: Hi\n"}));
    expect(result.diagnostics.sorted().map((d) => d.format()), ["a.cerita:2: error: ring is only for CALL scenes"]);
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
