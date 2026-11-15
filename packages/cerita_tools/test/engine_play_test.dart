import 'dart:convert';
import 'dart:io';

import 'package:cerita_core/cerita_core.dart';
import 'package:cerita_tools/cerita_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// Serves story files from memory, the way the Flutter asset loader serves them from the bundle.
class _MapLoader extends EngineLoader {
  final Map<String, String> files;

  _MapLoader(this.files);

  Map<String, dynamic> _json(String name) => jsonDecode(files[name]!) as Map<String, dynamic>;

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        conversation: await loadConversation(Conversation.indexKey),
        profiles: ProfileData.fromJson(_json("profiles.json")),
        channels: files.containsKey("channels.json") ? Channel.listFromJson(_json("channels.json")) : const [],
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async {
    final name = conversationId == Conversation.indexKey ? "index.json" : "cvn_$conversationId.json";
    return Conversation.fromJson(_json(name), key: conversationId);
  }
}

/// Plays a story headlessly, like example/test/story_test.dart, and records every item the engine returns.
Future<(String, List<Map<String, dynamic>>)> _play(
  EngineLoader loader, {
  required String Function(ChoiceItemType item) pick,
  Map<String, String> inputs = const {},
}) async {
  final engine = RealFsseEngine(loader);
  final transcript = <Map<String, dynamic>>[];
  ItemResult? result;
  for (var step = 0; step < 200; step++) {
    final item = await engine.next(prevResult: result);
    transcript.add(item.toJson());
    result = null;
    switch (item) {
      case EndingItemType():
        return (item.endingId, transcript);
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
  final compiled = compileStory(loadWrongNumber());
  final handWritten = {
    for (final file in Directory(exampleStoryDir).listSync().whereType<File>().where((f) => f.path.endsWith(".json")))
      p.basename(file.path): file.readAsStringSync(),
  };

  final routes = <String, (String, String Function(ChoiceItemType), Map<String, String>)>{
    "secret": (
      "end_04_secret",
      (item) => switch (item.text) {
            "\"Are you going to check it?\"" => "Yeah",
            "How do you reply?" => "Who is Luna",
            "What now?" => "📞",
            "Say something" => "I'll tell her",
            _ => "[Show Luna's photo]",
          },
      {"NAME": "Rin", "PASSCODE": "2019"},
    ),
    "true": (
      "end_01_true",
      (item) => switch (item.text) {
            "How do you reply?" => "Who is Luna",
            "What now?" => "📞",
            "Say something" => "I'll tell her",
            "What do you tell Luna?" => "Miki is sorry",
            _ => "",
          },
      const {},
    ),
    "good": (
      "end_02_good",
      (item) => switch (item.text) {
            "\"Are you going to check it?\"" => "Nah",
            "How do you reply?" => "Who is Luna",
            "What now?" => "I'll find Luna",
            "What do you tell Luna?" => "Miki is sorry",
            _ => "",
          },
      const {},
    ),
    "bad": (
      "end_03_bad",
      (item) => switch (item.text) {
            "How do you reply?" => "Wrong number",
            "What now?" => "I'll find Luna",
            "What do you tell Luna?" => "Nothing",
            _ => "",
          },
      const {},
    ),
  };

  test('the compiled script has no problems', () {
    expect(compiled.ok, isTrue, reason: compiled.diagnostics.items.join("\n"));
  });

  for (final MapEntry(key: name, value: (ending, pick, inputs)) in routes.entries) {
    test('compiled Wrong Number reaches the $name ending, like the hand-written story', () async {
      final (scriptEnding, scriptRun) = await _play(_MapLoader(compiled.files), pick: pick, inputs: inputs);
      final (jsonEnding, jsonRun) = await _play(_MapLoader(handWritten), pick: pick, inputs: inputs);
      expect(scriptEnding, ending);
      expect(jsonEnding, ending);
      expect(scriptRun, jsonRun);
    });
  }
}
