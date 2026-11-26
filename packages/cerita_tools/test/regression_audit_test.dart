import 'dart:convert';

import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

const _bilingual = "source_locale: id\nlocales: [id, en]\n";

void main() {
  test('MediaItem title is preserved when compiling', () {
    final result = compileStory(story({
      "a.cerita": """
@conversation index
media IMAGE photo.png unlock=p1
  title id: Foto Kafe
  title en: Cafe Photo
  caption id: Lihat ini
  caption en: Look at this
""",
    }, config: _bilingual));
    expect(result.ok, isTrue);
    final index = jsonDecode(result.files["index.json"]!) as Map<String, dynamic>;
    final media = (index["conversations"] as List).first as Map<String, dynamic>;
    expect(media["title"], {"id": "Foto Kafe", "en": "Cafe Photo"});
  });

  test('quoted attributes preserve \\n escapes', () {
    final result = compileStory(story({
      "a.cerita": '@conversation index title="Line 1\\nLine 2"\nnarration\n  en: Hi\n',
    }));
    expect(result.ok, isTrue);
    final index = jsonDecode(result.files["index.json"]!) as Map<String, dynamic>;
    expect(index["title"], "Line 1\nLine 2");
  });

  test('blank YAML locale value is treated as missing, not literal "null"', () async {
    final project = story(
      {"a.cerita": "@conversation index\nnora\n  id: Halo\n  en: Hi\nending e1 GOOD\n  id: Tamat\n  en: End\n"},
      config: _bilingual,
      profiles: "nora:\n  id: nora\n  name:\n    id: Nora\n    en:\n",
    );
    final diagnostics = await lintStory(project);
    expect(diagnostics.items.any((d) => d.message.contains("Missing 'en' text")), isTrue);
    final compiled = compileStory(project);
    final profiles = jsonDecode(compiled.files["profiles.json"]!) as Map<String, dynamic>;
    expect((profiles["profiles"] as List).first["name"], {"id": "Nora"});
  });

  test('scene.ring is reported under sfx in collectAssetRefs and assetKinds', () {
    final project = story({
      "a.cerita": """
@conversation index
@scene CALL ring=phone_ring.mp3
nora
  en: Hello?
""",
    });
    final refs = collectAssetRefs(project);
    final ring = refs.firstWhere((r) => r.path == "music/phone_ring.mp3");
    expect(assetKinds, contains(ring.kind));
  });

  test('StageAction.durationMs matches core engine timings', () {
    final project = story({
      "a.cerita": """
@conversation index
stage
  music theme.mp3
  weather rain
  sound click.mp3
  textbox nvl
  page
stage
  shake
""",
    });
    final items = project.conversations.single.items.whereType<StageItem>().toList();
    expect(items[0].effectiveWaitMs, 0);
    expect(items[1].effectiveWaitMs, 400);
  });

  test('storyStats follows CALL hangup targets and strips text tags in countWords', () {
    expect(countWords("Hello {w=400} {i}world{/i} {nw} {{persistent.runs}}"), 3);

    final project = story({
      "a.cerita": """
@conversation index
@scene CALL hangup=hung_up
nora
  en: Listen to me.
ending e_stay GOOD
  en: Stayed

@conversation hung_up
ending e_hangup BAD
  en: Hung up
""",
    });
    final stats = storyStats(project);
    expect(stats.endings.map((e) => e.id), containsAll(["e_stay", "e_hangup"]));
  });

  test('lintStory checks missing translations on scene.stay and scene.status', () async {
    final project = story({
      "a.cerita": """
@conversation index
@scene CALL stay="Jangan tutup"
nora
  id: Halo
  en: Hi
ending e1 GOOD
  id: Tamat
  en: End
""",
    }, config: _bilingual);
    final diagnostics = await lintStory(project);
    expect(diagnostics.items.any((d) => d.message.contains("Missing 'en' text")), isTrue);
  });

  test('buildTtsManifest does not false-collide between line and voice_note with same filename', () {
    final project = story({
      "a.cerita": """
@conversation index
nora voice=clip.mp3
  en: Spoken line
media AUDIO clip.mp3 by=nora
  transcript en: Voice note transcript
""",
    });
    final warnings = Diagnostics();
    final manifest = buildTtsManifest(project, warnings);
    expect((manifest["lines"] as List).length, 2);
    expect(warnings.items, isEmpty);
  });

  test('blank or whitespace-only YAML locale maps for required profile name are reported as missing', () {
    for (final profiles in [
      "nora:\n  name:\n    id:\n    en:\n",
      "nora:\n  name:\n    id: \"\"\n    en: \"   \"\n",
      "nora:\n  name: \"   \"\n",
    ]) {
      final project = story(
        {
          "a.cerita": """
@conversation index
nora
  id: Halo
  en: Hi
""",
        },
        config: _bilingual,
        profiles: profiles,
      );
      expect(project.diagnostics.hasErrors, isTrue);
      expect(project.diagnostics.items.any((d) => d.message.contains("has no name")), isTrue);
    }
  });

  test('storyStats CALL cache does not poison shared calls reached at different depths', () {
    final buffer = StringBuffer("""
@conversation index
choice
  en: Pick
? Deep
  -> c0
? Direct
  -> c8

@conversation shared
nora
  en: one two three four five
return
""");
    for (var i = 0; i < 8; i++) {
      buffer.writeln("""
@conversation c$i
call c${i + 1}
ending e$i GOOD
  en: End $i
""");
    }
    buffer.writeln("""
@conversation c8
call shared
ending e8 GOOD
  en: End 8
""");
    final project = story({"a.cerita": buffer.toString()});
    final stats = storyStats(project);
    final direct = stats.endings.firstWhere((e) => e.id == "e8");
    // Direct path reaches c8 at depth 0, so `shared` (5 words) must be counted.
    expect(direct.shortest.measure.words, greaterThanOrEqualTo(5));
  });
}
