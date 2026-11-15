import 'dart:convert';

import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

class _Loader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  _Loader(this.files);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "raka", "name": "Raka", "bio": {"id": "Lagi di Pluit", "en": "Somewhere in Pluit"}},
          ],
        }),
        channels: Channel.listFromJson({
          "channels": [
            {
              "id": "dm",
              "name": {"id": "Grup Kos", "en": "Boarding house"},
              "status": {"id": "daring", "en": "online"},
            },
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

Map<String, dynamic> _text(Object text) => {"type": "TEXT", "text": text, "profile": "raka:0"};

/// A bilingual story: Indonesian source, English translation with one gap.
_Loader _story({Map<String, dynamic> index = const {"source_locale": "id", "locales": ["id", "en"]}}) => _Loader({
      "index": {
        ...index,
        "conversation_id": "cvn_index",
        "chapter": {"id": "Hari 1", "en": "Day 1"},
        "checkpoint": true,
        "scene": {"mode": "CHAT", "channel_id": "dm"},
        "conversations": [
          {"type": "INPUT", "text": {"id": "Namamu?", "en": "Your name?"}, "variable": "NAME", "default_value": "Raka"},
          _text({"id": "Halo {{NAME}}", "en": "Hi {{NAME}}"}),
          _text({"id": "Belum diterjemahkan"}),
          {
            "type": "CHOICE",
            "text": {"id": "Balas?", "en": "Reply?"},
            "variable": "REPLY",
            "choices": [
              {"text": {"id": "Iya", "en": "Yes"}},
              {"text": {"id": "Jangan", "en": "Don't"}, "condition": "never == true"},
            ],
          },
          _text({"id": "Kamu jawab {{REPLY}}", "en": "You said {{REPLY}}"}),
          {
            "type": "MEDIA",
            "media_type": "AUDIO",
            "uri": "vo_raka.mp3",
            "unlock_id": "vo_raka",
            "title": {"id": "Pesan Raka", "en": "Raka's message"},
          },
          {
            "type": "ENDING",
            "ending_id": "end",
            "title": {"id": "Tamat", "en": "The End"},
            "summary": {"id": "Selesai.", "en": "Done."},
          },
        ],
      },
    });

void main() {
  group('LocalizedText', () {
    final text = LocalizedText.fromJson({"id": "Hai", "en": "Hi", "ja": "やあ"})!;

    test('falls back from the active locale to the source, then the first key', () {
      expect(text.resolve("en"), "Hi");
      expect(text.resolve("fr"), "Hai");
      expect(text.resolve(null), "Hai");
      expect(text.resolve("fr", source: "en"), "Hi");
      expect(LocalizedText.fromJson({"ja": "やあ", "en": "Hi"})!.resolve("fr"), "やあ");
    });

    test('a plain string is the same in every language', () {
      final plain = LocalizedText.fromJson("Hello")!;
      expect(plain.isLocalized, isFalse);
      expect(plain.resolve("en"), "Hello");
      expect(plain.resolve("id"), "Hello");
    });

    test('keeps its JSON form and compares by value', () {
      expect(text.toJson(), {"id": "Hai", "en": "Hi", "ja": "やあ"});
      expect(LocalizedText.fromJson("Hello")!.toJson(), "Hello");
      expect(LocalizedText.fromJson({"en": "Hi", "id": "Hai"}), LocalizedText.locales({"id": "Hai", "en": "Hi"}));
      expect(LocalizedText.fromJson(null), isNull);
      expect(() => LocalizedText.fromJson(42), throwsFormatException);
      expect(() => LocalizedText.fromJson({}), throwsFormatException);
    });

    test('localizedAssetName inserts the locale before the extension', () {
      expect(localizedAssetName("vo_raka.mp3", "en"), "vo_raka.en.mp3");
      expect(localizedAssetName("assets/story/music/vo.v2.mp3", "id"), "assets/story/music/vo.v2.id.mp3");
      expect(localizedAssetName("assets/v.1/voice", "en"), "assets/v.1/voice.en");
    });

    test('story locales default to an Indonesian source', () {
      expect(const StoryLocales().supported, ["id"]);
      expect(StoryLocales.fromJson({"source_locale": "en"}).supported, ["en"]);
      expect(StoryLocales.fromJson({"locales": ["en", "ja"]}).supported, ["en", "ja", "id"]);
    });
  });

  group('Localized items', () {
    test('items resolve every localizable field and keep their JSON', () {
      final media = ItemType.fromJson({
        "type": "MEDIA",
        "media_type": "IMAGE",
        "uri": "a.png",
        "title": {"id": "Foto", "en": "Photo"},
        "caption": {"id": "Lihat", "en": "Look"},
      }, localizer: const Localizer(locale: "en")) as MediaItemType;
      expect((media.title, media.caption), ("Photo", "Look"));
      expect(media.localized(const Localizer(locale: "id")).title, "Foto");
      expect(media.toJson()["title"], {"id": "Foto", "en": "Photo"});
    });

    test('interpolation fills each language and leaves logic fields alone', () {
      final json = interpolateItemJson({
        "type": "TEXT",
        "text": {"id": "Halo {{NAME}}", "en": "Hi {{NAME}}"},
        "condition": "NAME == '{{NAME}}'",
      }, {"NAME": "Sari"});
      expect(json["text"], {"id": "Halo Sari", "en": "Hi Sari"});
      expect(json["condition"], "NAME == '{{NAME}}'");
    });

    test('a localized choice stores its source text, a plain one its text', () {
      final choice = Choice.fromJson({"text": {"id": "Iya", "en": "Yes"}}, localizer: const Localizer(locale: "en"));
      expect(choice.text, "Yes");
      expect(ItemResult.choice("R", choice).value, "Iya");
      expect(ItemResult.choice("R", Choice.fromJson({"text": "Blue"})).value, "Blue");
      expect(ItemResult.choice("R", Choice.fromJson({"text": {"en": "Yes"}, "value": 1})).value, 1);
    });

    test('a localized CHOICE keeps its locked options in another language', () {
      final item = (ItemType.fromJson({
        "type": "CHOICE",
        "text": {"id": "Balas?", "en": "Reply?"},
        "choices": [
          {"text": {"id": "Iya", "en": "Yes"}},
          {"text": {"id": "Tidak", "en": "No"}, "condition": "x"},
        ],
      }) as ChoiceItemType)
          .withAvailability((condition) => condition == null);
      final english = item.localized(const Localizer(locale: "en"));
      expect(english.text, "Reply?");
      expect(english.choices.map((c) => (c.text, c.locked)), [("Yes", false), ("No", true)]);
    });
  });

  group('Engine locale', () {
    test('shows the active locale, falls back to the source and switches mid-run', () async {
      final engine = RealFsseEngine(_story())..locale = "en";
      final input = await engine.next() as InputItemType;
      expect(input.text, "Your name?");

      expect((await engine.next(prevResult: ItemResult.input("NAME", "Dewi"))).getText(), "Hi Dewi");
      expect((await engine.next()).getText(), "Belum diterjemahkan");

      engine.locale = "id";
      final choice = await engine.next() as ChoiceItemType;
      expect(choice.text, "Balas?");
      expect(choice.choices.map((c) => (c.text, c.locked)), [("Iya", false), ("Jangan", true)]);
    });

    test('the transcript keeps every language and state stays language-free', () async {
      final engine = RealFsseEngine(_story())..locale = "en";
      await engine.next();
      await engine.next(prevResult: ItemResult.input("NAME", "Dewi"));
      await engine.next();
      final choice = await engine.next() as ChoiceItemType;
      expect((await engine.next(prevResult: ItemResult.choice(choice.variable, choice.choices.first))).getText(),
          "You said Iya");
      expect(engine.dataMap, {"NAME": "Dewi", "REPLY": "Iya"});

      String line(TranscriptEntry entry, Localizer localizer) =>
          entry.isPlayer ? localizer.resolve(entry.playerText!) : entry.itemIn(localizer)!.getText()!;
      const id = Localizer(locale: "id");
      const en = Localizer(locale: "en");
      expect(engine.history.map((e) => line(e, id)),
          ["Namamu?", "Dewi", "Halo Dewi", "Belum diterjemahkan", "Balas?", "Iya", "Kamu jawab Iya"]);
      expect(engine.history.map((e) => line(e, en)),
          ["Your name?", "Dewi", "Hi Dewi", "Belum diterjemahkan", "Reply?", "Yes", "You said Iya"]);
    });

    test('profiles, channels, unlocks and checkpoints follow the locale', () async {
      final storage = InMemoryStoryStorage();
      final unlocked = <String?>[];
      final engine = RealFsseEngine(_story(), storage: storage, listener: _Unlocks(unlocked))..locale = "en";
      await engine.start();
      expect(engine.getProfileById("raka")?.bio, "Somewhere in Pluit");
      expect(engine.getChannel("dm")?.status, "online");
      engine.locale = "id";
      expect(engine.getProfileById("raka")?.bio, "Lagi di Pluit");
      expect(engine.getChannel("dm")?.name, "Grup Kos");

      engine.locale = "en";
      ItemResult? result;
      while (true) {
        final item = await engine.next(prevResult: result);
        result = switch (item) {
          InputItemType() => ItemResult.input(item.variable, "Dewi"),
          ChoiceItemType() => ItemResult.choice(item.variable, item.availableChoices.first),
          _ => null,
        };
        if (item is EndingItemType) {
          expect((item.title, item.summary), ("The End", "Done."));
          break;
        }
      }
      expect(unlocked, ["Raka's message"]);
      final checkpoint = (await storage.loadMeta()).unlockedCheckpoints["index"]!;
      expect(checkpoint.chapter?.resolve("en"), "Day 1");
    });

    test('a save made in one language loads in another', () async {
      final storage = InMemoryStoryStorage();
      final engine = RealFsseEngine(_story(), storage: storage)..locale = "id";
      await engine.next();
      await engine.next(prevResult: ItemResult.input("NAME", "Dewi"));
      await engine.saveTo(1);

      final slot = (await storage.loadSlot(1))!;
      expect(slot.chapter?.toJson(), {"id": "Hari 1", "en": "Day 1"});

      final restored = RealFsseEngine(_story(), storage: storage)..locale = "en";
      await restored.start(save: slot);
      expect(restored.history.last.itemIn(restored.localizer)?.getText(), "Hi Dewi");
      expect((await restored.next()).getText(), "Belum diterjemahkan");
    });

    test('saves from before localization still load', () async {
      final old = SaveSlot.fromJson(jsonDecode('''{
        "slot_id": 1, "conversation_key": "index", "dialog_index": 2, "data_map": {"NAME": "Dewi"},
        "updated_at": "2026-11-01T10:00:00.000", "chapter": "Day 1", "title": "Wrong Number",
        "history": [
          {"conversation_key": "index", "mode": "CHAT", "channel_id": "dm",
           "item": {"type": "INPUT", "text": "Your name?", "variable": "NAME"}},
          {"conversation_key": "index", "mode": "CHAT", "channel_id": "dm", "player_text": "Dewi"}
        ]
      }''') as Map<String, dynamic>);
      expect(old.chapter, const LocalizedText("Day 1"));
      expect(old.history.last.playerText, const LocalizedText("Dewi"));

      final engine = RealFsseEngine(_story())..locale = "en";
      await engine.start(save: old);
      expect(engine.history.first.itemIn(engine.localizer)?.getText(), "Your name?");
      expect((await engine.next()).getText(), "Belum diterjemahkan");
    });

    test('the story declares its source locale', () async {
      final engine = RealFsseEngine(_story(index: const {"source_locale": "en"}));
      await engine.next();
      final hello = await engine.next(prevResult: ItemResult.input("NAME", "Ann"));
      expect(engine.storyLocales.source, "en");
      expect(hello.getText(), "Hi Ann");
    });

    test('the language is a player setting', () async {
      final storage = InMemoryStoryStorage();
      expect((await storage.loadSettings()).locale, isNull);
      await storage.saveSettings((await storage.loadSettings()).copyWith(locale: "en", musicVolume: 0.5));
      await storage.clear();
      expect((await storage.loadSettings()).locale, "en");
      expect(PlayerSettings.fromJson(const PlayerSettings(locale: "id").toJson()).locale, "id");
      expect(const PlayerSettings().toJson().containsKey("locale"), isFalse);
    });
  });
}

class _Unlocks with EngineListener {
  final List<String?> titles;

  _Unlocks(this.titles);

  @override
  void onNewScene(Scene scene) {}

  @override
  void onMediaUnlocked(MediaItemType item) => titles.add(item.title);
}
