import 'dart:convert';

import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

Map<String, dynamic> _scene(String header) {
  final result = compileStory(story({"a.cerita": "@conversation index\n$header\nnarration\n  en: Hi\n"}));
  expect(result.diagnostics.items.where((d) => d.severity == Severity.error), isEmpty);
  return (jsonDecode(result.files["index.json"]!) as Map<String, dynamic>)["scene"] as Map<String, dynamic>;
}

void main() {
  test('status= replaces the channel status, status=none hides it', () {
    expect(_scene('@scene CHAT channel=dm status="last seen Thursday 11:40 PM"')["status"],
        "last seen Thursday 11:40 PM");
    final hidden = _scene("@scene CHAT channel=dm status=none");
    expect(hidden.containsKey("status"), isTrue);
    expect(hidden["status"], isNull);
    expect(_scene("@scene CHAT channel=dm").containsKey("status"), isFalse);
  });
}
