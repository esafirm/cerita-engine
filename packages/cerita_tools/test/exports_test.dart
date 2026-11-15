import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('tts-manifest', () {
    test('lists every voiced line and voice note per locale', () {
      final project = story(
        {
          "a.cerita": """
@conversation index
nora:smile voice=vo_01.mp3
  id: Kapal itu nggak pernah balik.
  en: That boat never came back.
  tts id: Kapal itu... nggak pernah balik.
  delivery: low, staring at the water
nora voice=vo_02.mp3
  id: Satu klip saja.
  en: Just one clip.
narration
  id: Tanpa suara
  en: Not voiced
media AUDIO vn_03.mp3 by=nora
  id: Halo?
ending end GOOD
  id: Tamat
  en: The end
""",
        },
        config: "source_locale: id\nlocales: [id, en]\n",
      );
      final warnings = Diagnostics();
      final lines = buildTtsManifest(project, warnings)["lines"] as List;
      // Each entry names the per-locale file the player looks for first (CE-01, data schema §5.4).
      expect(lines.map((l) => (l["file"], l["locale"], l["text"])), [
        ("vo_01.id.mp3", "id", "Kapal itu nggak pernah balik."),
        ("vo_01.en.mp3", "en", "That boat never came back."),
        ("vo_02.id.mp3", "id", "Satu klip saja."),
        ("vo_02.en.mp3", "en", "Just one clip."),
        ("vn_03.id.mp3", "id", "Halo?"),
      ]);
      expect(lines.first, {
        "id": "vo_01",
        "file": "vo_01.id.mp3",
        "kind": "line",
        "speaker": "nora",
        "speaker_name": "Nora",
        "locale": "id",
        "text": "Kapal itu nggak pernah balik.",
        "tts_text": "Kapal itu... nggak pernah balik.",
        "delivery": "low, staring at the water",
        "conversation": "index",
        "source": "a.cerita:2",
      });
      expect(lines.last["kind"], "voice_note");
      expect(warnings.items.map((d) => d.format()), ["a.cerita:13: warning: No 'en' text to voice for 'vn_03.en.mp3'"]);
    });

    test('lists every voiced line of Wrong Number', () {
      final warnings = Diagnostics();
      final lines = buildTtsManifest(loadWrongNumber(), warnings)["lines"] as List;
      expect(lines.map((l) => l["file"]), [
        "vo_nora_01.en.mp3",
        "vo_nora_02.en.mp3",
        "voice_miki_01.en.mp3",
        "vo_miki_call_01.en.mp3",
        "vo_miki_call_02.en.mp3",
        "vo_luna_01.en.mp3",
        "vo_luna_01.en.mp3",
      ]);
      // Text tags style the line on screen and aren't spoken.
      expect(lines[1]["text"], "Your phone is buzzing again. You should really look.");
      // Day 2's two greetings share one clip.
      expect(warnings.items.map((d) => d.format()), [
        "scripts/04_day2.cerita:17: warning: 'vo_luna_01.en.mp3' is also voiced at scripts/04_day2.cerita:15 with other text, "
            "so one of them won't match",
      ]);
    });
  });

  group('assets', () {
    test('lists files the story uses that are missing, by kind', () {
      final project = story(
        {
          "a.cerita": """
@conversation index
@scene VN bg=room.png music=theme.mp3
nora voice=vo_01.mp3 sfx=ding.mp3
  en: Hi
media CG cg_01.png
media VIDEO clip.mp4
media AUDIO note.mp3
media IMAGE photo.png
ending end GOOD
  en: E
""",
        },
        profiles: "nora:\n  name: Nora\n  avatar: assets/story/sprites/nora_avatar.png\n"
            "  expressions:\n    open: nora_open.png\n",
        channels: "thread:\n  name: Thread\n  avatar: thread.png\n",
        clues: "clues:\n  boat:\n    title: Boat\n    image: clue_boat.png\n",
        assets: {"bg/room.png", "sprites/nora_open.png", "media/photo.png"},
      );
      expect([for (final ref in missingAssets(project)!) "${ref.kind} ${ref.path} ${ref.span}"], [
        "avatar sprites/nora_avatar.png profiles.yaml:3",
        "avatar sprites/thread.png channels.yaml:3",
        "clue media/clue_boat.png clues.yaml:4",
        "music music/theme.mp3 a.cerita:2",
        "sfx music/ding.mp3 a.cerita:3",
        "voice music/vo_01.en.mp3 a.cerita:3",
        "cg bg/cg_01.png a.cerita:5",
        "video media/clip.mp4 a.cerita:6",
        "voice_note media/note.en.mp3 a.cerita:7",
      ]);
    });

    test('is unknown without an asset folder', () {
      expect(missingAssets(story({"a.cerita": "@conversation index\n"})), isNull);
    });

    test('Wrong Number has every asset', () {
      expect(missingAssets(loadWrongNumber()), isEmpty);
    });
  });
}
