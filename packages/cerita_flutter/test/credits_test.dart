import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class _CreditsLoader extends FakeEngineLoader {
  final Map<String, dynamic>? credits;

  _CreditsLoader(super.files, {this.credits});

  @override
  Future<Credits?> loadCredits() async => credits == null ? null : Credits.fromJson(credits!);
}

/// A bundle whose manifest lists [assets] and nothing else.
class _Bundle extends CachingAssetBundle {
  final List<String> assets;

  _Bundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    if (key != "AssetManifest.bin") throw FlutterError("No asset $key");
    return const StandardMessageCodec().encodeMessage({for (final asset in assets) asset: <Object?>[]})!;
  }
}

const _credits = {
  "sections": [
    {
      "title": {"id": "Cerita", "en": "Story"},
      "people": [
        {"name": "Esa", "role": {"id": "Penulis", "en": "Writer"}},
      ],
    },
  ],
  "assets": [
    {
      "title": {"id": "Hujan", "en": "Rain"},
      "author": "Jane Doe",
      "source": "example.org/rain",
      "license": "CC0 1.0",
    },
  ],
  "roll_after": ["end_true"],
};

Map<String, Map<String, dynamic>> _story(String endingId) => {
      "index": {
        "conversation_id": "cvn",
        "scene": {"mode": "VN"},
        "conversations": [
          {"type": "TEXT", "text": "Goodbye", "profile": "nora:0"},
          {"type": "ENDING", "ending_id": endingId, "title": "The last word", "category": "TRUE"},
        ],
      },
    };

void main() {
  setUp(mockAudioChannels);

  StorySetup setup({Map<String, dynamic>? credits, String endingId = "end_true"}) => StorySetup(
        config: const LoaderConfig(),
        loader: _CreditsLoader(_story(endingId), credits: credits),
        storage: InMemoryStoryStorage(),
        audio: SilentAudio.new,
      );

  testWidgets('the credits screen lists people and assets in the active language and links the licenses',
      (tester) async {
    final language = StoryLanguage(locale: "id", locales: const StoryLocales(locales: ["id", "en"]));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => StoryLanguageScope(language: language, child: child!),
      home: CreditsScreen(setup: setup(credits: _credits)),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Kredit"), findsOneWidget);
    expect(find.text("CERITA"), findsOneWidget);
    expect(find.text("Penulis"), findsOneWidget);
    expect(find.text("Esa"), findsOneWidget);
    expect(find.text("ASET PIHAK KETIGA"), findsOneWidget);
    for (final text in ["Hujan", "oleh Jane Doe", "Sumber: example.org/rain", "Lisensi: CC0 1.0"]) {
      expect(find.text(text), findsOneWidget);
    }

    await language.select("en");
    await tester.pumpAndSettle();
    expect(find.text("Writer"), findsOneWidget);
    expect(find.text("License: CC0 1.0"), findsOneWidget);

    await tester.tap(find.text("Open-source licenses"));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('credits roll after a chosen ending, and a tap skips them', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StoryScreen(setup: setup(credits: _credits)),
          )),
          child: const Text("Title screen"),
        ),
      ),
    ));
    await tester.tap(find.text("Title screen"));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(VnStage));
    await tester.pumpAndSettle();
    expect(find.text("The last word"), findsOneWidget);

    await tester.tap(find.text("Back to title"));
    await tester.pump();
    expect(find.byType(RollingCredits), findsOneWidget);
    expect(find.text("Esa"), findsOneWidget);
    expect(find.byType(StoryScreen), findsOneWidget, reason: "the credits roll before leaving");

    await tester.tap(find.byType(RollingCredits));
    await tester.pumpAndSettle();
    expect(find.byType(StoryScreen), findsNothing);
    expect(find.text("Title screen"), findsOneWidget);
  });

  testWidgets('credits roll to the end by themselves, and other endings leave at once', (tester) async {
    Future<void> reachEnding(StorySetup setup) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryScreen(setup: setup))),
            child: const Text("Title screen"),
          ),
        ),
      ));
      await tester.tap(find.text("Title screen"));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VnStage));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Back to title"));
      await tester.pump();
    }

    await reachEnding(setup(credits: _credits));
    expect(find.byType(RollingCredits), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("Title screen"), findsOneWidget, reason: "the roll ends by itself");

    await reachEnding(setup(credits: _credits, endingId: "end_bad"));
    expect(find.byType(RollingCredits), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text("Title screen"), findsOneWidget);
  });

  testWidgets('reaching an ending clears the autosave, with or without rolling credits', (tester) async {
    /// Plays to the ending and back to the title, then returns the autosave the title screen would continue.
    Future<SaveSlot?> finish(StorySetup setup) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryScreen(setup: setup))),
            child: const Text("Title screen"),
          ),
        ),
      ));
      await tester.tap(find.text("Title screen"));
      await tester.pumpAndSettle();
      final before = await tester.runAsync<SaveSlot?>(() => setup.storage.loadSlot(SaveSlot.autoSlotId));
      expect(before, isNotNull, reason: "lines before the ending are autosaved");
      await tester.tap(find.byType(VnStage));
      await tester.pumpAndSettle();
      expect(find.text("Back to title"), findsOneWidget);
      await tester.tap(find.text("Back to title"));
      await tester.pump();
      if (find.byType(RollingCredits).evaluate().isNotEmpty) await tester.tap(find.byType(RollingCredits));
      await tester.pumpAndSettle();
      expect(find.text("Title screen"), findsOneWidget);
      final save = await tester.runAsync<SaveSlot?>(() => setup.storage.loadSlot(SaveSlot.autoSlotId));
      await tester.pumpWidget(const SizedBox());
      return save;
    }

    // A finished playthrough leaves nothing to continue. See docs/decisions.md.
    expect(await finish(setup(credits: _credits)), isNull);
    expect(await finish(setup()), isNull);
  });

  test('a bundled story without credits.json has no credits', () async {
    final loader = AssetEngineLoader(const LoaderConfig(), bundle: _Bundle(["assets/story/index.json"]));
    expect(await loader.loadCredits(), isNull);
  });
}
