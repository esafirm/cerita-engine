import 'dart:convert';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, Map<String, dynamic>> _story(List<Map<String, dynamic>> items) => {
      "index": {"conversation_id": "cvn", "chapter": "Prologue", "scene": {"mode": "VN"}, "conversations": items},
    };

void main() {
  Future<void> pumpGallery(
    WidgetTester tester,
    List<Map<String, dynamic>> items, {
    Set<String> unlocked = const {},
  }) async {
    final storage = InMemoryStoryStorage();
    await storage.saveMeta(GlobalMetaState(unlockedMediaIds: unlocked));
    final setup = StorySetup(config: const LoaderConfig(), loader: FakeEngineLoader(_story(items)), storage: storage);
    await tester.pumpWidget(
      DefaultAssetBundle(bundle: _PixelBundle(), child: MaterialApp(home: GalleryScreen(setup: setup))),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('a story with nothing to collect shows an empty gallery, without tabs', (tester) async {
    await pumpGallery(tester, [
      {"type": "TEXT", "text": "Hi", "profile": "nora:0"},
    ]);
    expect(find.text("Nothing to collect in this story yet"), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('only the kinds the story has get a tab, and a held CG is listed by its title', (tester) async {
    await pumpGallery(tester, unlocked: {"cg_storm"}, [
      {
        "type": "STAGE",
        "actions": [
          {"action": "cg", "image": "cg_storm.png", "unlock_id": "cg_storm", "title": "The Storm"},
        ],
      },
      {"type": "MEDIA", "media_type": "AUDIO", "uri": "vo.mp3", "unlock_id": "vo"},
    ]);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text("Videos"), findsNothing);
    expect(find.text("The Storm"), findsOneWidget);
  });

  testWidgets('a story with one kind shows it without tabs', (tester) async {
    await pumpGallery(tester, [
      {"type": "MEDIA", "media_type": "AUDIO", "uri": "vo.mp3", "unlock_id": "vo"},
    ]);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text("Voice notes"), findsOneWidget);
    expect(find.text("Unlocked in Prologue"), findsOneWidget);
  });
}

/// Serves a 1×1 PNG for any asset.
class _PixelBundle extends CachingAssetBundle {
  static final _pixel = base64Decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  );

  @override
  Future<ByteData> load(String key) async {
    if (key == "AssetManifest.bin") return const StandardMessageCodec().encodeMessage(<String, Object?>{})!;
    return ByteData.sublistView(_pixel);
  }
}
