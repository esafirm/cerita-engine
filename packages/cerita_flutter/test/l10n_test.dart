import 'dart:convert';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class _Loader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  _Loader(this.files);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "sari", "name": "Sari"},
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

/// An asset bundle whose manifest lists [assets]. Every image is a transparent pixel.
class _Bundle extends CachingAssetBundle {
  static final _pixel = base64Decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  );

  final List<String> assets;

  _Bundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith(".png")) return ByteData.sublistView(_pixel);
    if (key != "AssetManifest.bin") throw FlutterError("No asset $key");
    return const StandardMessageCodec().encodeMessage({
      for (final asset in assets) asset: <Object?>[],
    })!;
  }
}

/// Indonesian source with English, except one untranslated line.
Map<String, Map<String, dynamic>> _story() => {
      "index": {
        "conversation_id": "cvn_index",
        "source_locale": "id",
        "locales": ["id", "en"],
        "chapter": {"id": "Hari 1", "en": "Day 1"},
        "scene": {"mode": "CHAT", "channel_id": "dm"},
        "conversations": [
          {"type": "TEXT", "text": {"id": "Halo", "en": "Hi"}, "profile": "sari:0", "typing_delay_ms": 0},
          {"type": "TEXT", "text": {"id": "Cuma bahasa Indonesia"}, "profile": "sari:0", "typing_delay_ms": 0},
          {
            "type": "CHOICE",
            "text": {"id": "Balas?", "en": "Reply?"},
            "variable": "REPLY",
            "choices": [
              {"text": {"id": "Iya", "en": "Yes"}},
            ],
          },
          {
            "type": "MEDIA",
            "media_type": "IMAGE",
            "uri": "photo.png",
            "unlock_id": "photo",
            "title": {"id": "Foto kafe", "en": "Café photo"},
            "typing_delay_ms": 0,
          },
          {
            "type": "ENDING",
            "ending_id": "end",
            "category": "GOOD",
            "title": {"id": "Akhir bahagia", "en": "Happy ending"},
          },
        ],
      },
    };

StorySetup _setup(InMemoryStoryStorage storage) => StorySetup(
      config: const LoaderConfig(),
      loader: _Loader(_story()),
      storage: storage,
      audio: SilentAudio.new,
      assets: LocalizedAssets(_Bundle([])),
    );

Widget _app(StoryLanguage language, Widget home) => MaterialApp(
      builder: (context, child) => DefaultAssetBundle(
        bundle: _Bundle([]),
        child: StoryLanguageScope(language: language, child: child!),
      ),
      home: home,
    );

void main() {
  group('StoryLanguage', () {
    test('picks the saved language, then the device language, then the source', () async {
      final storage = InMemoryStoryStorage();
      final language = StoryLanguage();
      expect(language.locale, isNull);
      expect(language.strings.newGame, "New game");

      await language.load(_setup(storage), deviceLocale: "fr");
      expect(language.locale, "id");
      expect(language.available, ["id", "en"]);

      await language.load(_setup(storage), deviceLocale: "en");
      expect(language.locale, "en");

      await language.select("id");
      await language.load(_setup(storage), deviceLocale: "en");
      expect(language.locale, "id");
      expect(language.strings.newGame, "Main baru");
    });

    test('apps add engine strings for more languages', () {
      final language = StoryLanguage(locale: "ja", strings: {"ja": const _Japanese()});
      expect(language.strings.gallery, "ギャラリー");
      expect(language.languageName("ja"), "日本語");
      expect(StoryLanguage(locale: "fr").strings.gallery, "Gallery");
      expect(StoryLanguage().languageName("fr"), "fr");
    });

    test('voice clips prefer the active language', () async {
      final assets = LocalizedAssets(_Bundle(["assets/story/music/vo.en.mp3", "assets/story/music/vo.mp3"]));
      expect(await assets.resolve("assets/story/music/vo.mp3", "en"), "assets/story/music/vo.en.mp3");
      expect(await assets.resolve("assets/story/music/vo.mp3", "id"), "assets/story/music/vo.mp3");
    });
  });

  testWidgets('switching language mid-chat re-renders the thread, menus and ending', (tester) async {
    mockAudioChannels();
    final storage = InMemoryStoryStorage();
    final setup = _setup(storage);
    final language = StoryLanguage();
    await language.load(setup, deviceLocale: "id");
    await tester.pumpWidget(_app(language, StoryScreen(setup: setup)));

    // Chat paces itself: two lines, then the choice.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text("Halo"), findsOneWidget);
    expect(find.text("Cuma bahasa Indonesia"), findsOneWidget);
    expect(find.text("Balas?"), findsOneWidget);
    expect(find.text("Hari 1"), findsNothing);

    await language.select("en");
    await tester.pump();
    expect(find.text("Hi"), findsOneWidget);
    expect(find.text("Halo"), findsNothing);
    expect(find.text("Cuma bahasa Indonesia"), findsOneWidget, reason: "falls back to the source language");
    expect(find.text("Reply?"), findsOneWidget);
    expect((await tester.runAsync(storage.loadSettings))!.locale, "en");

    await tester.tap(find.text("Yes"));
    var toast = false;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      toast |= find.text("Gallery unlocked: Café photo").evaluate().isNotEmpty;
    }
    expect(toast, isTrue, reason: "the unlock is named by its title, not its id");
    expect(find.text("Yes"), findsOneWidget, reason: "the player's reply bubble");
    expect(find.text("Happy ending"), findsOneWidget);
    expect(find.text("GOOD ENDING"), findsOneWidget);

    await language.select("id");
    await tester.pump();
    expect(find.text("Iya"), findsOneWidget);
    expect(find.text("Akhir bahagia"), findsOneWidget);
    expect(find.text("ENDING BAIK"), findsOneWidget);
    expect(find.text("Kembali ke menu utama"), findsOneWidget);

    // Saves keep every language.
    final save = (await tester.runAsync(() => storage.loadSlot(SaveSlot.autoSlotId)))!;
    expect(save.chapter, LocalizedText.locales({"id": "Hari 1", "en": "Day 1"}));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('gallery and endings screens follow the language', (tester) async {
    final storage = InMemoryStoryStorage();
    await storage.saveMeta(GlobalMetaState(unlockedMediaIds: {"photo"}, unlockedEndingIds: {"end"}));
    final setup = _setup(storage);
    final language = StoryLanguage(locale: "en", locales: const StoryLocales(locales: ["id", "en"]));

    await tester.pumpWidget(_app(language, GalleryScreen(setup: setup)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text("Café photo"), findsOneWidget);
    expect(find.text("Photos & CGs"), findsOneWidget);

    await language.select("id");
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text("Foto kafe"), findsOneWidget);
    expect(find.text("Foto & CG"), findsOneWidget);

    await tester.pumpWidget(_app(language, EndingsScreen(setup: setup)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text("Akhir bahagia"), findsOneWidget);
    expect(find.text("1 / 1 ending"), findsOneWidget);
  });

  testWidgets('settings switch the language, and reset keeps it', (tester) async {
    final storage = InMemoryStoryStorage();
    final setup = _setup(storage);
    final language = StoryLanguage();
    await language.load(setup, deviceLocale: "id");
    await tester.pumpWidget(_app(language, SettingsScreen(settings: setup.settings)));
    await tester.pump();
    expect(find.text("Pengaturan"), findsOneWidget);
    expect(find.text("Bahasa Indonesia"), findsOneWidget);

    await tester.tap(find.text("Bahasa"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("English"));
    await tester.pumpAndSettle();
    expect(find.text("Settings"), findsOneWidget);
    expect(setup.settings.value.locale, "en");

    await tester.tap(find.text("Reset"));
    await tester.pump();
    expect(setup.settings.value.locale, "en");
    expect(language.locale, "en");
  });

  test('saves keep the localized chapter as JSON', () {
    final slot = SaveSlot.fromJson(jsonDecode(jsonEncode(SaveSlot(
      slotId: 1,
      conversationKey: "index",
      dialogIndex: 0,
      dataMap: const {},
      history: const [],
      updatedAt: DateTime(2026),
      chapter: LocalizedText.locales({"id": "Hari 1", "en": "Day 1"}),
    ).toJson())) as Map<String, dynamic>);
    expect(const Localizer(locale: "en").maybe(slot.chapter), "Day 1");
  });
}

class _Japanese extends EnglishCeritaStrings {
  const _Japanese();

  @override
  String get languageName => "日本語";

  @override
  String get gallery => "ギャラリー";
}
