import 'dart:convert';

import 'package:cerita_core/cerita_core.dart' as core;
import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

Map<String, dynamic> _scene(String header) {
  final result = compileStory(story({"a.cerita": "@conversation index\n$header\nnarration\n  en: Hi\n"}));
  expect(result.diagnostics.items.where((d) => d.severity == Severity.error), isEmpty);
  return (jsonDecode(result.files["index.json"]!) as Map<String, dynamic>)["scene"] as Map<String, dynamic>;
}

void main() {
  hangUpTests();
  castMeasureTests();
  test('status= replaces the channel status, status=none hides it', () {
    expect(_scene('@scene CHAT channel=dm status="last seen Thursday 11:40 PM"')["status"],
        "last seen Thursday 11:40 PM");
    final hidden = _scene("@scene CHAT channel=dm status=none");
    expect(hidden.containsKey("status"), isTrue);
    expect(hidden["status"], isNull);
    expect(_scene("@scene CHAT channel=dm").containsKey("status"), isFalse);
  });
}

void hangUpTests() {
  test('hangup= sends an ended call to its target, stay= is the thought when it can\'t be ended', () {
    final skippable = _scene("@scene CALL hangup=after#top");
    expect(skippable["hangup"], "after#top");
    expect(core.Scene.fromJson(skippable).hangUp, "after#top");
    final stuck = _scene('@scene CALL stay="Not now."');
    expect(stuck["stay"], "Not now.");
    expect(core.Scene.fromJson(stuck).stay?.toJson(), "Not now.");

    final errors = compileStory(
      story({
        "a.cerita":
            '@conversation index\n@scene VN hangup=x stay="No."\nnarration\n  en: Hi\n'
            '@conversation b\n@scene CALL hangup=x stay="No."\nnarration\n  en: Hi\n',
      }),
    ).diagnostics.sorted().map((d) => d.format());
    expect(errors, [
      "a.cerita:2: error: hangup is only for CALL scenes",
      "a.cerita:2: error: stay is for a call that can't be hung up, so not with hangup",
      "a.cerita:2: error: stay is only for CALL scenes",
      "a.cerita:6: error: stay is for a call that can't be hung up, so not with hangup",
    ]);
  });

  test('a missing hangup target is reported at the scene line, and its target counts as reachable', () async {
    final script =
        "@conversation index\n@scene CALL hangup=after\nnarration\n  en: Hi\n"
        "@conversation b\n@scene CALL hangup=nowhere\nnarration\n  en: Hi\n"
        "@conversation after\nnarration\n  en: Bye\n";
    final issues = (await lintStory(story({"a.cerita": script}))).sorted().map((d) => d.format()).toList();
    expect(issues, contains("a.cerita:6: error: Target 'nowhere' doesn't exist"));
    expect(issues.where((issue) => issue.startsWith("a.cerita:9:")), isEmpty, reason: "index's hangup leads to after");
  });
}

void castMeasureTests() {
  test('height and framing in profiles.yaml reach profiles.json, and bad values are errors', () {
    const cast =
        "nora:\n  name: Nora\n  height: 172\n  framing: 0.7\n  expressions:\n    open: nora_open.png\n"
        "bob:\n  name: Bob\n  height: tall\n  framing: 1.4\n";
    final result = compileStory(story({"a.cerita": "@conversation index\nnora\n  en: Hi\n"}, profiles: cast));
    expect(result.diagnostics.sorted().map((d) => d.format()), [
      "profiles.yaml:9: error: 'height' must be a number above 0",
      "profiles.yaml:10: error: 'framing' must be a number above 0, up to 1",
    ]);

    final ok = compileStory(
      story({
        "a.cerita": "@conversation index\nnora\n  en: Hi\n",
      }, profiles: "nora:\n  name: Nora\n  height: 172\n  framing: 0.7\n  expressions:\n    open: nora_open.png\n"),
    );
    final profiles = core.ProfileData.fromJson(jsonDecode(ok.files["profiles.json"]!) as Map<String, dynamic>);
    expect(profiles.byId("nora")?.height, 172);
    expect(profiles.byId("nora")?.framing, 0.7);
  });
}
