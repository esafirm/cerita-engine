import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, dynamic> _chapter(String chapter, String title, int day, List<Map<String, dynamic>> items) => {
      "conversation_id": "cvn",
      "chapter": chapter,
      "title": title,
      "checkpoint": true,
      "scene": {"mode": "VN", "day": day},
      "conversations": items,
    };

Map<String, dynamic> _ending(String id, String title, {String? condition}) =>
    {"type": "ENDING", "ending_id": id, "title": title, "category": "GOOD", "condition": ?condition};

/// Day 5 splits into the Harbor and Network routes. Harbor has two endings, Network one.
Map<String, Map<String, dynamic>> _story() => {
      "index": _chapter("Prologue", "The Call", 0, [
        {
          "type": "CHOICE",
          "text": "Where to?",
          "choices": [
            {"text": "Harbor", "target": "harbor"},
            {"text": "Network", "target": "network"},
          ],
        },
      ]),
      "harbor": _chapter("Day 5", "The Pier", 5, [
        {"type": "BRANCH", "branches": [{"condition": "storm", "target": "storm"}], "fallback_target": "calm"},
      ]),
      "network": _chapter("Day 5", "The Server Room", 5, [_ending("end_net", "Signal Lost")]),
      "storm": {"conversation_id": "cvn", "conversations": [_ending("end_storm", "Into the Storm")]},
      "calm": {"conversation_id": "cvn", "conversations": [_ending("end_calm", "Still Water")]},
    };

Checkpoint _checkpoint(String key) => Checkpoint(conversationKey: key, dataMap: const {}, unlockedAt: DateTime(2026));

void main() {
  /// Pumps the Chapters screen for a player who has only taken the Harbor route, to the Storm ending.
  Future<List<String>> pumpChapters(WidgetTester tester, {Map<String, Map<String, dynamic>>? story}) async {
    final storage = InMemoryStoryStorage();
    await storage.saveMeta(GlobalMetaState(
      unlockedCheckpoints: {"index": _checkpoint("index"), "harbor": _checkpoint("harbor")},
      unlockedEndingIds: {"end_storm"},
    ));
    final picked = <String>[];
    final loader = FakeEngineLoader(story ?? _story());
    final setup = StorySetup(config: const LoaderConfig(), loader: loader, storage: storage);
    await tester.pumpWidget(MaterialApp(
      home: ChaptersScreen(
        setup: setup,
        onSelect: (checkpoint) => picked.add("play ${checkpoint.conversationKey}"),
        onReplay: (checkpoint) => picked.add("replay ${checkpoint.conversationKey}"),
      ),
    ));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('a branching story opens on the flowchart, with unreached routes and endings locked', (tester) async {
    await pumpChapters(tester);
    expect(find.byType(RouteFlowchart), findsOneWidget);

    expect(find.text("Prologue"), findsOneWidget);
    expect(find.text("The Pier"), findsOneWidget);
    expect(find.text("Day 5"), findsOneWidget, reason: "only the reached Day 5 shows its chapter");
    expect(find.text("The Server Room"), findsNothing);
    expect(find.text("???"), findsOneWidget);

    expect(find.text("Into the Storm"), findsOneWidget);
    expect(find.text("Still Water"), findsNothing);
    expect(find.text("Signal Lost"), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(3), reason: "one locked route and two locked endings");

    expect(find.text("1 of 3 endings found"), findsOneWidget);
    expect(find.text("1 of 2 endings found"), findsOneWidget);
  });

  testWidgets('tapping a reached checkpoint offers to play or replay it, unreached ones do nothing', (tester) async {
    final picked = await pumpChapters(tester);

    await tester.tap(find.text("???"));
    await tester.pumpAndSettle();
    expect(find.text("Play from here"), findsNothing);

    await tester.tap(find.text("The Pier"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Play from here"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Prologue"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Replay this chapter"));
    await tester.pumpAndSettle();
    expect(picked, ["play harbor", "replay index"]);
  });

  testWidgets('the app bar switches to the list, and a linear story opens on the list', (tester) async {
    await pumpChapters(tester);
    await tester.tap(find.byTooltip("Show list"));
    await tester.pumpAndSettle();
    expect(find.byType(RouteFlowchart), findsNothing);
    expect(find.text("Not reached yet"), findsOneWidget);
    await tester.tap(find.byTooltip("Show flowchart"));
    await tester.pumpAndSettle();
    expect(find.byType(RouteFlowchart), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpChapters(tester, story: {
      "index": _chapter("Prologue", "The Call", 0, [{"type": "JUMP", "target": "harbor"}]),
      "harbor": _chapter("Day 5", "The Pier", 5, [_ending("end_storm", "Into the Storm")]),
    });
    expect(find.byType(RouteFlowchart), findsNothing);
    expect(find.byTooltip("Show flowchart"), findsOneWidget);
  });
}
