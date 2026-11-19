import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, dynamic> _text(String text) => {"type": "TEXT", "text": text, "profile": "nora:0"};

/// Two chapters, a CG and an ending, none of them reached yet.
Map<String, Map<String, dynamic>> _files() => {
      "index": {
        "conversation_id": "cvn",
        "chapter": "Day 1",
        "checkpoint": true,
        "scene": {"mode": "VN", "music": "theme.mp3"},
        "conversations": [
          _text("Morning"),
          {"type": "SET", "effects": [{"variable": "clue_photo", "op": "set", "value": true}]},
          {"type": "JUMP", "target": "day2"},
        ],
      },
      "day2": {
        "conversation_id": "cvn",
        "chapter": "Day 2",
        "checkpoint": true,
        "scene": {"mode": "VN"},
        "conversations": [
          {"type": "MEDIA", "media_type": "CG", "uri": "cg.png", "unlock_id": "cg_pier"},
          {"type": "ENDING", "ending_id": "end_pier", "title": "Pier", "category": "GOOD", "summary": "."},
        ],
      },
    };

void main() {
  setUp(mockAudioChannels);

  StorySetup setupWith(StoryStorage storage) => StorySetup(
        config: const LoaderConfig(),
        loader: FakeEngineLoader(_files()),
        storage: storage,
        audio: SilentAudio.new,
      );

  Future<void> pumpGate(WidgetTester tester, StorySetup setup) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminGate(setup: setup, child: const SizedBox(width: 200, height: 80, child: Text("LAST SEEN"))),
      ),
    ));
  }

  Future<void> tapLogo(WidgetTester tester, int times, {Duration gap = const Duration(milliseconds: 200)}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text("LAST SEEN"));
      await tester.pump(gap);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('seven quick taps open the admin sheet, fewer or slower ones don\'t', (tester) async {
    await pumpGate(tester, setupWith(InMemoryStoryStorage()));

    await tapLogo(tester, 6);
    expect(find.text("Unlock everything"), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tapLogo(tester, 7, gap: const Duration(seconds: 1));
    expect(find.text("Unlock everything"), findsNothing);
    await tester.pump(const Duration(seconds: 1));

    await tapLogo(tester, 7);
    expect(find.text("Unlock everything"), findsOneWidget);
    expect(find.text("Developer tools"), findsOneWidget);
  });

  testWidgets('unlock everything opens every chapter with the variables of a test run', (tester) async {
    final storage = InMemoryStoryStorage();
    await pumpGate(tester, setupWith(storage));
    await tapLogo(tester, 7);

    await tester.runAsync(() async {
      await tester.tap(find.text("Unlock everything"));
      for (var i = 0; i < 20 && find.textContaining("Unlocked").evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    expect(find.text("Unlocked 2 chapters, 1 pictures and clips, 1 endings and 1 tracks."), findsOneWidget);

    final meta = await tester.runAsync(storage.loadMeta);
    expect(meta!.unlockedCheckpoints.keys, unorderedEquals(["index", "day2"]));
    expect(meta.unlockedCheckpoints["day2"]!.dataMap, containsPair("clue_photo", true));
    expect(meta.unlockedMediaIds, {"cg_pier"});
    expect(meta.unlockedEndingIds, {"end_pier"});
  });

  testWidgets('developer tools add Developer to the in-game menu in any build, and stay on', (tester) async {
    final storage = InMemoryStoryStorage();
    final setup = setupWith(storage);
    await pumpGate(tester, setup);
    await tapLogo(tester, 7);
    await tester.tap(find.text("Developer tools"));
    await tester.pumpAndSettle();
    expect(setup.settings.value.developerTools, isTrue);
    expect((await tester.runAsync(storage.loadSettings))!.developerTools, isTrue);

    // A new app, so the admin sheet doesn't stay open over the story.
    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: StoryScreen(setup: setup)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Menu"));
    await tester.pumpAndSettle();
    expect(find.text("Developer", skipOffstage: false), findsOneWidget);
  });
}
