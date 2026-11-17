import 'dart:convert';

import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

const _cast = "sekar:\n  name: Sekar\n  expressions:\n    neutral: sekar.png\n"
    "tasya:\n  name: Tasya\n  expressions:\n    neutral: tasya.png\n";
const _script = "@conversation index\n@scene CHAT channel=sekar_tasya\ntasya\n  en: Hi\n";

CompileResult _compile(String channels) => compileStory(story({"a.cerita": _script}, profiles: _cast, channels: channels));

void main() {
  test("owner compiles to the owner's profile id", () {
    final result = _compile("sekar_tasya:\n  name: Tasya\n  members: [tasya]\n  owner: sekar\n");
    expect(result.diagnostics.items.where((d) => d.severity == Severity.error), isEmpty);
    final channel = ((jsonDecode(result.files["channels.json"]!) as Map)["channels"] as List).single as Map;
    expect(channel["owner"], "sekar");
    expect(channel["members"], ["tasya"]);
  });

  test('a thread without an owner has none in the JSON', () {
    final result = _compile("sekar_tasya:\n  name: Tasya\n  members: [tasya]\n");
    final channel = ((jsonDecode(result.files["channels.json"]!) as Map)["channels"] as List).single as Map;
    expect(channel.containsKey("owner"), isFalse);
  });

  test('an unknown owner or a list is an error', () {
    expect(_compile("sekar_tasya:\n  name: Tasya\n  owner: sekr\n").diagnostics.sorted().map((d) => d.format()),
        ["channels.yaml:3: error: Unknown character 'sekr'"]);
    expect(_compile("sekar_tasya:\n  name: Tasya\n  owner: [sekar]\n").diagnostics.sorted().map((d) => d.format()),
        ["channels.yaml:3: error: 'owner' must be a character name"]);
  });

  test('an owner counts as using the character', () async {
    final project = story({"a.cerita": "@conversation index\n@scene CHAT channel=sekar_tasya\ntasya\n  en: Hi\n"},
        profiles: _cast, channels: "sekar_tasya:\n  name: Tasya\n  owner: sekar\n");
    final warnings = (await lintStory(project)).items.map((d) => d.message);
    expect(warnings, isNot(contains("Character 'sekar' is never used")));
  });
}
