import 'dart:convert';
import 'dart:io';

import 'package:cerita_core/cerita_core.dart';
import 'package:cerita_core/io.dart';
import 'package:test/test.dart';

class _FakeEngineLoader extends EngineLoader {
  final Map<String, Object> files;

  _FakeEngineLoader(this.files);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "nora", "name": "Nora", "sprites": ["nora_0.png", "nora_1.png"]},
          ],
        }),
        channels: [const Channel(id: "thread_nora", name: "Nora")],
        conversation: await loadConversation(Conversation.indexKey),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async {
    final file = files[conversationId];
    if (file is! Map<String, dynamic>) throw FormatException("Broken file $conversationId");
    return Conversation.fromJson(file, key: conversationId);
  }

  @override
  Future<List<String>> listConversationKeys() async => files.keys.toList();
}

Map<String, dynamic> _conversation(List<Map<String, dynamic>> items, {Map<String, dynamic>? scene}) => {
      "conversation_id": "cvn",
      "scene": scene ?? {"mode": "VN", "background": "room.png"},
      "conversations": items,
    };

Map<String, dynamic> _text(String text, {String profile = "nora:0", String? condition}) =>
    {"type": "TEXT", "text": text, "profile": profile, "condition": ?condition};

Future<List<String>> _lint(Map<String, Object> files, {bool Function(String)? assetExists}) async =>
    [for (final issue in await StoryLinter(_FakeEngineLoader(files), assetExists: assetExists).lint()) "$issue"];

void main() {
  group('StoryLinter', () {
    test('a clean story has no issues', () async {
      expect(
        await _lint({
          "index": _conversation([
            {"type": "SET", "effects": [{"variable": "trust", "op": "add", "value": 1}]},
            _text("{b}Hi{/b} {{NAME}}", condition: "trust > 0"),
            {"type": "JUMP", "target": "end"},
          ]),
          "end": _conversation([
            {"type": "INPUT", "text": "Name?", "variable": "NAME"},
            {"type": "ENDING", "ending_id": "e", "title": "End", "category": "GOOD", "summary": "."},
          ]),
        }),
        isEmpty,
      );
    });

    test('broken targets and labels', () async {
      final issues = await _lint({
        "index": _conversation([
          {"type": "JUMP", "id": "top", "target": "nowhere", "condition": "x"},
          {"type": "CALL", "target": "#missing"},
          {"type": "BRANCH", "branches": [{"condition": "true", "target": "other#hub"}], "fallback_target": "#top"},
        ]),
        "other": _conversation([_text("a")]),
      });
      expect(issues, containsAll([
        "error   index.json #0  Target 'nowhere' doesn't exist",
        "error   index.json #1  Target '#missing' has no item with id 'missing'",
        "error   index.json #2  Target 'other#hub' has no item with id 'hub'",
      ]));
    });

    test('characters, sprites, expressions, labels and choices', () async {
      final issues = await _lint({
        "index": _conversation([
          _text("a", profile: "miko:0"),
          _text("b", profile: "nora:4"),
          _text("c", condition: "trust >= "),
          {"type": "SET", "id": "x", "effects": [{"variable": "v", "op": "set", "expr": "rnd(1, 2)"}]},
          {"type": "SET", "id": "x"},
          {"type": "CHOICE", "text": "?", "default_choice": 2, "choices": [{"text": "only"}]},
          {"type": "STAGE", "actions": [{"action": "show", "profile": "ghost:0"}]},
          _text("{{v}} {{trust}} {{player}}", profile: "player"),
        ]),
      });
      expect(issues.where((issue) => issue.startsWith("error")), [
        "error   index.json #0  Unknown character 'miko'",
        "error   index.json #1  Nora has no sprite 4 (2 sprites)",
        "error   index.json #2  Bad expression: Unexpected end of 'trust >= '",
        "error   index.json #3  Bad expression: Unknown function 'rnd' in 'rnd(1, 2)'",
        "error   index.json #4  Duplicate id 'x'",
        "error   index.json #5  default_choice 2 isn't one of the 1 options",
        "error   index.json #6  Unknown character 'ghost'",
      ]);
    });

    test('variables read but never set, and set but never read', () async {
      final issues = await _lint({
        "index": _conversation([
          _text("Hi {{curiousity}}", condition: "curiosity > 1"),
          {"type": "SET", "effects": [{"variable": "curiosity", "op": "add", "value": 1}]},
          {"type": "SET", "effects": [{"variable": "unused", "op": "set", "value": true}]},
          {"type": "CHOICE", "text": "?", "variable": "PICK", "choices": [{"text": "a", "condition": "!flag"}]},
        ]),
      });
      expect(issues, unorderedEquals([
        "warning index.json #0  Variable 'curiousity' is read but never set",
        "warning index.json #2  Variable 'unused' is set but never read",
        "warning index.json #3  Variable 'PICK' is set but never read",
        "warning index.json #3  Variable 'flag' is read but never set",
      ]));
    });

    test('unknown tags, unreachable conversations, dead items and chat threads', () async {
      final issues = await _lint({
        "index": _conversation([
          _text("{shaek}Boo{/shaek} {w=500}"),
          {"type": "JUMP", "target": "chat"},
          _text("dead"),
          _text("also dead"),
          {"type": "TEXT", "id": "label", "text": "alive", "profile": "nora:0"},
        ]),
        "chat": _conversation([_text("hey")], scene: {"mode": "CHAT", "channel_id": "thread_miki"}),
        "lonely": _conversation([_text("nobody comes here")], scene: {"mode": "CHAT"}),
      });
      expect(issues, [
        "error   cvn_lonely.json  CHAT scene without a channel_id",
        "warning cvn_chat.json  Chat thread 'thread_miki' isn't in channels.json",
        "warning cvn_lonely.json  No target leads to this conversation",
        "warning index.json #0  Unknown text tag '{shaek}'",
        "warning index.json #2  Never reached: it follows a JUMP or RETURN",
      ]);
    });

    test('files that fail to load and missing assets', () async {
      final issues = await _lint(
        {
          "index": _conversation([
            {"type": "TEXT", "text": "a", "profile": "nora:1", "voice": "vo.mp3"},
            {"type": "STAGE", "actions": [{"action": "music", "file": "theme.mp3"}]},
            {"type": "MEDIA", "media_type": "CG", "uri": "cg.png"},
            {"type": "JUMP", "target": "broken"},
          ]),
          "broken": "not json",
        },
        assetExists: (path) => path.endsWith("room.png") || path.endsWith("nora_0.png"),
      );
      expect(issues, [
        "error   cvn_broken.json  Can't load: FormatException: Broken file broken",
        "error   index.json #0  Missing voice file 'assets/story/music/vo.mp3'",
        "error   index.json #1  Missing music file 'assets/story/music/theme.mp3'",
        "error   index.json #2  Missing media file 'assets/story/bg/cg.png'",
        "error   profiles.json  Missing sprite file 'assets/story/sprites/nora_1.png'",
      ]);
    });
  });

  test('the graph links conversations and renders Mermaid', () async {
    final loader = _FakeEngineLoader({
      "index": {
        "conversation_id": "cvn",
        "chapter": "Prologue",
        "title": "Start \"here\"",
        "conversations": [
          {"type": "CHOICE", "text": "?", "choices": [{"text": "Go", "target": "day1"}, {"text": "Stay", "target": "#x"}]},
          {"type": "CALL", "target": "shared"},
          {"type": "BRANCH", "branches": [{"condition": "a > 1", "target": "end"}], "fallback_target": "day1"},
        ],
      },
      "day1": _conversation([{"type": "JUMP", "target": "end"}]),
      "shared": _conversation([_text("buzz")]),
      "end": _conversation([{"type": "ENDING", "ending_id": "e", "title": "E", "category": "GOOD", "summary": "."}]),
      "orphan": _conversation([_text("?")]),
    });
    final graph = StoryGraph(await StoryCatalog.load(loader).then((catalog) => catalog.conversations));
    expect(graph.reachable, {"index", "day1", "shared", "end"});
    expect(graph.toMermaid(), '''
flowchart TD
    index["Prologue · Start #quot;here#quot;<br/>index"]
    day1["day1"]
    shared["shared"]
    end(["end"])
    orphan["orphan"]
    index -->|"Go"| day1
    index -.->|"CALL"| shared
    index -->|"a > 1"| end
    index -->|"otherwise"| day1
    day1 --> end
''');
  });

  test('reloading keeps the variables and shows the edited item', () async {
    final files = <String, Object>{
      "index": _conversation([
        {"type": "TEXT", "text": "Hi", "profile": "nora:0", "effects": [{"variable": "n", "op": "add", "value": 1}]},
        _text("Next"),
      ]),
    };
    final engine = RealFsseEngine(_FakeEngineLoader(files));
    await engine.next();
    ((files["index"]! as Map)["conversations"] as List)[0] = _text("Hello there");
    expect((await engine.reloadCurrent())?.getText(), "Hello there");
    expect(engine.dataMap["n"], 1, reason: "effects are not applied again");
    expect(engine.history.single.itemType?.getText(), "Hello there");
    expect((await engine.next()).getText(), "Next");
  });

  test('developer jumps keep the variables', () async {
    final engine = RealFsseEngine(_FakeEngineLoader({
      "index": _conversation([_text("a"), {"type": "TEXT", "id": "late", "text": "{{x}}", "profile": "nora:0"}]),
    }));
    await engine.next();
    await engine.setVariable("x", 7);
    await engine.jumpTo("#late");
    expect((await engine.next()).getText(), "7");
  });

  group('cerita command', () {
    late Directory story;

    setUp(() {
      story = Directory.systemTemp.createTempSync("cerita_story");
      void write(String name, Object json) => File("${story.path}/$name").writeAsStringSync(jsonEncode(json));
      write("profiles.json", {
        "profiles": [
          {"id": "nora", "name": "Nora", "sprites": ["nora.png"]},
        ],
      });
      write("index.json", _conversation([_text("hi"), {"type": "JUMP", "target": "day1"}]));
      write("cvn_day1.json", _conversation([_text("bye {{mood}}")]));
      Directory("${story.path}/sprites").createSync();
      File("${story.path}/sprites/nora.png").writeAsStringSync("");
    });

    tearDown(() => story.deleteSync(recursive: true));

    test('lint reports missing files and fails on errors', () async {
      final out = StringBuffer();
      final code = await runCli(["lint", story.path], out: out);
      expect(code, 1);
      expect(out.toString(), contains("error   index.json  Missing background file '${story.path}/bg/room.png'"));
      expect(out.toString(), contains("warning cvn_day1.json #0  Variable 'mood' is read but never set"));
      expect(out.toString(), endsWith("2 error(s), 1 warning(s).\n"));
    });

    test('lint passes warnings unless strict', () async {
      Directory("${story.path}/bg").createSync();
      File("${story.path}/bg/room.png").writeAsStringSync("");
      expect(await runCli(["lint", story.path], out: StringBuffer()), 0);
      expect(await runCli(["lint", "--strict", story.path], out: StringBuffer()), 1);
    });

    test('graph prints Mermaid, and bad arguments print the usage', () async {
      final out = StringBuffer();
      expect(await runCli(["graph", story.path], out: out), 0);
      expect(out.toString(), contains("index --> day1"));

      final usage = StringBuffer();
      expect(await runCli(["lnt"], out: usage), 64);
      expect(usage.toString(), startsWith("Usage: cerita"));
    });
  });
}
