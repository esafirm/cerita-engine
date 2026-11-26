import 'dart:convert';
import 'dart:io';

import 'package:cerita_tools/cerita_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

Future<(int, String, String)> _run(List<String> args) async {
  final out = StringBuffer(), err = StringBuffer();
  final code = await CeritaCli(out, err).run(args);
  return (code, out.toString(), err.toString());
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync("cerita_tools_test"));
  tearDown(() => temp.deleteSync(recursive: true));

  test('compile writes the files and --check verifies them', () async {
    final out = p.join(temp.path, "story");
    final (code, stdout, _) = await _run(["compile", wrongNumberDir, out]);
    expect(code, exitOk);
    expect(stdout, contains("Compiled 12 files"));
    expect(File(p.join(out, "cvn_day1.json")).readAsStringSync(), compileStory(loadWrongNumber()).files["cvn_day1.json"]);

    expect((await _run(["compile", "--check", wrongNumberDir, out])).$1, exitOk);

    File(p.join(out, "cvn_day2.json")).writeAsStringSync("{}");
    File(p.join(out, "cvn_old.json")).writeAsStringSync("{}");
    final (checkCode, _, stderr) = await _run(["compile", "--check", wrongNumberDir, out]);
    expect(checkCode, exitProblems);
    expect(stderr, contains("cvn_day2.json doesn't match the scripts"));
    expect(stderr, contains("cvn_old.json has no conversation in the scripts"));
  });

  test('compile reports errors and writes nothing', () async {
    final story = _writeStory(temp, "@conversation index\nbob\n  en: Hi\n");
    final out = p.join(temp.path, "out");
    final (code, _, stderr) = await _run(["compile", story, out]);
    expect(code, exitProblems);
    expect(stderr, contains("${p.join(story, "a.cerita")}:2: error: Unknown character 'bob'"));
    expect(Directory(out).existsSync(), isFalse);
  });

  test('lint prints file:line problems and fails on errors', () async {
    final story = _writeStory(temp, "@conversation index\n-> nowhere\n");
    final (code, _, stderr) = await _run(["lint", story]);
    expect(code, exitProblems);
    expect(stderr.split("\n"), containsAll([
      "${p.join(story, "a.cerita")}:2: error: Target 'nowhere' doesn't exist",
      "1 problem (1 error, 0 warnings)",
    ]));
    expect((await _run(["lint", wrongNumberDir])).$1, exitOk);
  });

  test('stats --json prints the report as JSON', () async {
    final (code, stdout, _) = await _run(["stats", "--json", wrongNumberDir]);
    expect(code, exitOk);
    final json = jsonDecode(stdout) as Map<String, dynamic>;
    expect(json["locale"], "en");
    expect(json["endings"], hasLength(4));
    expect((await _run(["stats", "--locale", "fr", wrongNumberDir])).$1, exitUsage);
  });

  test('tts-manifest and assets write their reports', () async {
    final file = p.join(temp.path, "manifest.json");
    expect((await _run(["tts-manifest", wrongNumberDir, "--out", file])).$1, exitOk);
    expect((jsonDecode(File(file).readAsStringSync())["lines"] as List), hasLength(7));

    final (code, stdout, _) = await _run(["assets", "--json", wrongNumberDir]);
    expect(code, exitOk);
    expect(jsonDecode(stdout), isEmpty);
  });

  test('usage errors exit with 64', () async {
    expect((await _run(["lint"])).$1, exitUsage);
    expect((await _run(["nope"])).$1, exitUsage);
  });
}

/// Writes a one-script story into [dir] and returns its folder.
String _writeStory(Directory dir, String script) {
  final story = p.join(dir.path, "src");
  Directory(story).createSync();
  File(p.join(story, "cerita.yaml")).writeAsStringSync("source_locale: en\n");
  File(p.join(story, "profiles.yaml")).writeAsStringSync("{}");
  File(p.join(story, "a.cerita")).writeAsStringSync(script);
  return story;
}
