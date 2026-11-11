import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

class _FakeEngineLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  _FakeEngineLoader(this.files);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "nora", "name": "Nora", "sprites": ["a.png"]},
            {"id": "miki", "name": "Miki", "sprites": ["c.png"]},
          ],
        }),
        conversation: await loadConversation(Conversation.indexKey),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);

  @override
  Future<List<String>> listConversationKeys() async => files.keys.toList();
}

Map<String, dynamic> _text(String text, {String profile = "nora:0", String? voice}) =>
    {"type": "TEXT", "text": text, "profile": profile, "voice": ?voice};

Map<String, dynamic> _stage(List<Map<String, dynamic>> actions) => {"type": "STAGE", "actions": actions};

void main() {
  group('TextMarkup', () {
    test('styles nest and close in any order', () {
      final markup = TextMarkup.parse("a{b}b{i}c{/b}d{/i}e");
      expect(markup.tokens, [
        const MarkupText("a", MarkupStyle()),
        const MarkupText("b", MarkupStyle(bold: true)),
        const MarkupText("c", MarkupStyle(bold: true, italic: true)),
        const MarkupText("d", MarkupStyle(italic: true)),
        const MarkupText("e", MarkupStyle()),
      ]);
    });

    test('values, effects, pauses and no-wait', () {
      final markup = TextMarkup.parse("Wait.{w=600} {shake}{color=#E05050}Why{/color}{/shake}{w}{speed=0.5}...{nw}");
      expect(markup.tokens, [
        const MarkupText("Wait.", MarkupStyle()),
        const MarkupPause(600),
        const MarkupText(" ", MarkupStyle()),
        const MarkupText("Why", MarkupStyle(effect: MarkupEffect.shake, color: "#E05050")),
        const MarkupPause(null),
        const MarkupText("...", MarkupStyle(speed: 0.5)),
      ]);
      expect(markup.noWait, isTrue);
      expect(markup.text, "Wait. Why...");
      expect(markup.hasTiming, isTrue);
    });

    test('unknown tags, bad values and stray closings are shown as written', () {
      expect(TextMarkup.plain("{draft} {color=red}x{/color} {/b} {size=big}y {w=soon}"),
          "{draft} {color=red}x{/color} {/b} {size=big}y {w=soon}");
      expect(TextMarkup.parse("{draft}{b}x").tokens, [
        const MarkupText("{draft}", MarkupStyle()),
        const MarkupText("x", MarkupStyle(bold: true)),
      ]);
    });

    test('unclosed tags last to the end of the line', () {
      expect(TextMarkup.parse("{size=1.5}{u}big").tokens, [
        const MarkupText("big", MarkupStyle(size: 1.5, underline: true)),
      ]);
    });
  });

  group('NVL page', () {
    test('starts with the conversation, a switch to NVL and a page action', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": {
          "conversation_id": "cvn",
          "scene": {"mode": "VN", "textbox": "nvl"},
          "conversations": [
            _text("one"),
            _stage([{"action": "page"}]),
            _text("two"),
            _stage([{"action": "textbox", "style": "adv"}]),
            _text("three"),
            _stage([{"action": "textbox", "style": "nvl"}]),
            _text("four"),
            _stage([{"action": "textbox", "style": "nvl"}]),
            _text("five"),
          ],
        },
      }));

      await engine.next();
      expect(engine.stage.textbox, TextboxStyle.nvl);
      expect(engine.stage.pageStart, 0);
      await engine.next(); // page
      await engine.next();
      expect(engine.stage.pageStart, 1);
      await engine.next(); // adv
      await engine.next();
      expect(engine.stage.textbox, TextboxStyle.adv);
      await engine.next(); // nvl
      await engine.next();
      expect(engine.stage.pageStart, 3, reason: "switching to NVL starts a page");
      await engine.next(); // already nvl
      await engine.next();
      expect(engine.stage.pageStart, 3);
      expect(engine.history.skip(engine.stage.pageStart).map((e) => e.itemType?.getText()), ["four", "five"]);

      // The text box and page roll back with the stage.
      expect(engine.rollback()?.getText(), "four");
      expect(engine.rollback()?.getText(), "three");
      expect(engine.stage.textbox, TextboxStyle.adv);
      expect(engine.rollback()?.getText(), "two");
      expect(engine.stage.textbox, TextboxStyle.nvl);
      expect(engine.stage.pageStart, 1);
    });

    test('stage text box, page and ambience survive a save', () {
      final stage = StageState(ambience: "rain.mp3", textbox: TextboxStyle.nvl, pageStart: 4);
      final restored = StageState.fromJson(stage.toJson());
      expect(restored.ambience, "rain.mp3");
      expect(restored.textbox, TextboxStyle.nvl);
      expect(restored.pageStart, 4);
      expect(StageState.fromJson(StageState().toJson()).textbox, TextboxStyle.adv);
    });
  });

  group('Audio', () {
    test('scene and stage ambience, and music fades', () async {
      final engine = RealFsseEngine(_FakeEngineLoader({
        "index": {
          "conversation_id": "cvn",
          "scene": {"mode": "VN", "music": "theme.mp3", "ambience": "rain.mp3"},
          "conversations": [
            _text("one"),
            _stage([
              {"action": "music", "file": "night.mp3", "fade_ms": 3000},
              {"action": "ambience", "file": null},
            ]),
          ],
        },
      }));
      await engine.next();
      expect(engine.stage.ambience, "rain.mp3");
      final stage = await engine.next() as StageItemType;
      expect((stage.actions[0] as MusicAction).fadeMs, 3000);
      expect(engine.stage.ambience, isNull);
      expect(engine.stage.music, "night.mp3");
    });

    test('per-character voice volumes', () async {
      const settings = PlayerSettings(voiceVolume: 0.5, voiceVolumes: {"miki": 0.4});
      expect(settings.voiceVolumeOf("miki"), closeTo(0.2, 1e-9));
      expect(settings.voiceVolumeOf("nora"), 0.5);
      expect(settings.voiceVolumeOf(null), 0.5);
      expect(PlayerSettings.fromJson(settings.toJson()), settings);
      expect(PlayerSettings.fromJson({"voice_volumes": {"miki": 3}}).voiceVolumes, {"miki": 1.0});
      expect(const PlayerSettings().toJson().containsKey("voice_volumes"), isFalse);
    });

    test('the catalog lists voiced characters', () async {
      final catalog = await StoryCatalog.load(_FakeEngineLoader({
        "index": {
          "conversation_id": "cvn",
          "conversations": [
            _text("a", profile: "miki:0", voice: "m1.mp3"),
            _text("b", profile: "nora:0"),
            _text("c", profile: "player", voice: "p.mp3"),
            _text("d", profile: "miki:0", voice: "m2.mp3"),
          ],
        },
      }));
      expect(catalog.voicedProfiles, ["miki"]);
    });
  });
}
