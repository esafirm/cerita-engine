import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Map<String, dynamic> _jump(String target) => {"type": "JUMP", "target": target};

Map<String, dynamic> _branch(Map<String, String> targets, String fallback) => {
      "type": "BRANCH",
      "branches": [for (final MapEntry(key: condition, value: target) in targets.entries) {"condition": condition, "target": target}],
      "fallback_target": fallback,
    };

/// Wrong Number's shape: two reached checkpoints, then an unreached Day 2 with its four endings.
Map<String, Map<String, dynamic>> _wrongNumber() => {
      "index": _chapter("Prologue", "A Quiet Evening", 0, [_jump("day1")]),
      "day1": _chapter("Day 1", "Wrong Number", 1, [_jump("day2")]),
      "day2": _chapter("Day 2", "The Second Call", 2, [
        _branch({"a": "good", "b": "bad", "c": "secret"}, "true"),
      ]),
      for (final id in ["good", "bad", "secret", "true"])
        id: {"conversation_id": "cvn", "conversations": [_ending("end_$id", "Ending $id")]},
    };

/// The ten endings of [_lastSeen], by `ending_id`.
const _lastSeenEndings = {
  "end_handed": "Handed Over",
  "end_wrong": "Wrong Name",
  "end_storm": "The Storm",
  "end_undertow": "Undertow",
  "end_still": "Still Water",
  "end_episode": "Episode 12",
  "end_unsent": "Unsent",
  "end_low": "Low Tide",
  "end_record": "Off the Record",
  "end_runaway": "Runaway",
};

/// Last Seen's shape (specs/last-seen.md): Day 5 splits into the Harbor and Network routes, which meet again at
/// Day 7, and 10 endings. Bad ends come off Day 3, both Day 5s and both Day 6s, the other seven off Day 7. Its
/// rows are: 4 single checkpoints, Day 4 with an ending, the two Day 5s, the two Day 6s with an ending, Day 7
/// with an ending, and 7 endings.
Map<String, Map<String, dynamic>> _lastSeen() => {
      "index": _chapter("Prolog", "Panggilan Dinda", 0, [_jump("day1")]),
      "day1": _chapter("Hari 1", "Rumah Kosong", 1, [_jump("day2")]),
      "day2": _chapter("Hari 2", "Grup Chat", 2, [_jump("day3")]),
      "day3": _chapter("Hari 3", "Dermaga", 3, [_branch({"gave_phone": "end_handed"}, "day4")]),
      "day4": _chapter("Hari 4", "Malam Itu", 4, [
        {
          "type": "CHOICE",
          "text": "Ke mana?",
          "choices": [
            {"text": "Pelabuhan", "target": "harbor5"},
            {"text": "Jaringan", "target": "network5"},
          ],
        },
      ]),
      "harbor5": _chapter("Hari 5", "Retak di Pelabuhan", 5, [_branch({"wrong": "end_wrong"}, "harbor6")]),
      "network5": _chapter("Hari 5", "Retak di Jaringan", 5, [_branch({"wrong": "end_wrong"}, "network6")]),
      "harbor6": _chapter("Hari 6", "Badai di Muara", 6, [_branch({"unprepared": "end_storm"}, "day7")]),
      "network6": _chapter("Hari 6", "Badai di Server", 6, [_branch({"unprepared": "end_storm"}, "day7")]),
      "day7": _chapter("Hari 7", "Terakhir Terlihat", 7, [
        _branch({
          "true_end": "end_undertow",
          "still": "end_still",
          "episode": "end_episode",
          "unsent": "end_unsent",
          "low": "end_low",
          "record": "end_record",
        }, "end_runaway"),
      ]),
      for (final MapEntry(key: id, value: title) in _lastSeenEndings.entries)
        id: {"conversation_id": "cvn", "conversations": [_ending(id, title)]},
    };

Checkpoint _checkpoint(String key) => Checkpoint(conversationKey: key, dataMap: const {}, unlockedAt: DateTime(2026));

GlobalMetaState _reached(List<String> checkpoints, {Set<String> endings = const {}}) => GlobalMetaState(
      unlockedCheckpoints: {for (final key in checkpoints) key: _checkpoint(key)},
      unlockedEndingIds: endings,
    );

/// Lays the screen out as a 360 x 640 dp phone.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Every [text] on the chart is laid out whole inside its node: nothing cut off with an ellipsis or by the card.
void _expectWhole(WidgetTester tester, String text) {
  final found = find.text(text);
  expect(found, findsWidgets);
  for (var index = 0; index < found.evaluate().length; index++) {
    final finder = found.at(index);
    expect(tester.renderObject<RenderParagraph>(finder).didExceedMaxLines, isFalse, reason: "$text is cut off");
    final card = tester.getRect(find.ancestor(of: finder, matching: find.byType(Card)));
    final rect = tester.getRect(finder);
    expect(card.contains(rect.topLeft) && card.contains(rect.bottomRight - const Offset(0.01, 0.01)), isTrue,
        reason: "$text spills out of its node");
  }
}

/// Every node of the chart lies within the phone's width, and the chart only scrolls down.
void _expectWithinWidth(WidgetTester tester) {
  for (final rect in tester.widgetList(find.byType(Card)).map((card) => tester.getRect(find.byWidget(card)))) {
    expect(rect.left >= 0 && rect.right <= 360, isTrue, reason: "a node at $rect is cut off at the side");
  }
  final scrollables = tester.widgetList<Scrollable>(find.byType(Scrollable));
  expect(scrollables.map((scrollable) => axisDirectionToAxis(scrollable.axisDirection)), everyElement(Axis.vertical));
}

void main() {
  /// Pumps the Chapters screen, by default for a player who has only taken the Harbor route, to the Storm ending.
  Future<List<String>> pumpChapters(
    WidgetTester tester, {
    Map<String, Map<String, dynamic>>? story,
    GlobalMetaState? meta,
    String locale = "en",
  }) async {
    final storage = InMemoryStoryStorage();
    await storage.saveMeta(meta ?? _reached(["index", "harbor"], endings: {"end_storm"}));
    final picked = <String>[];
    final loader = FakeEngineLoader(story ?? _story());
    final setup = StorySetup(config: const LoaderConfig(), loader: loader, storage: storage);
    final language = StoryLanguage(locale: locale, locales: const StoryLocales(locales: ["id", "en"]));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => StoryLanguageScope(language: language, child: child!),
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

  testWidgets('a Wrong Number-sized chart fits a 360 dp phone with whole titles and endings counts', (tester) async {
    _phone(tester);
    await pumpChapters(tester, story: _wrongNumber(), meta: _reached(["index", "day1"]), locale: "id");
    expect(find.byType(RouteFlowchart), findsOneWidget);

    _expectWhole(tester, "A Quiet Evening");
    _expectWhole(tester, "Wrong Number");
    expect(find.text("0 dari 4 ending ditemukan"), findsNWidgets(2));
    _expectWhole(tester, "0 dari 4 ending ditemukan");
    expect(find.text("The Second Call"), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(5), reason: "Day 2 and its four endings");
    _expectWithinWidth(tester);
  });

  testWidgets('a Last Seen-sized chart keeps its titles and endings counts whole on a 360 dp phone', (tester) async {
    _phone(tester);
    final picked = await pumpChapters(
      tester,
      story: _lastSeen(),
      meta: _reached(["index", "day1", "day2", "day3", "day4", "harbor5", "harbor6", "day7"]),
      locale: "id",
    );
    expect(find.byType(RouteFlowchart), findsOneWidget);

    _expectWhole(tester, "0 dari 10 ending ditemukan");
    _expectWhole(tester, "Retak di Pelabuhan");
    _expectWhole(tester, "0 dari 7 ending ditemukan");
    expect(find.text("Retak di Jaringan"), findsNothing, reason: "the Network route isn't reached");
    expect(find.text("???"), findsNWidgets(2));
    for (final title in _lastSeenEndings.values) {
      expect(find.text(title), findsNothing, reason: "no ending is found yet");
    }
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(12), reason: "two Network checkpoints and ten endings");
    _expectWithinWidth(tester);

    await tester.ensureVisible(find.text("Badai di Muara"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Badai di Muara"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Mainkan ulang bab ini"));
    await tester.pumpAndSettle();
    expect(picked, ["replay harbor6"]);
  });

  testWidgets('every ending of a Last Seen-sized chart can be scrolled to on a 360 dp phone', (tester) async {
    _phone(tester);
    await pumpChapters(
      tester,
      story: _lastSeen(),
      meta: _reached(
        ["index", "day1", "day2", "day3", "day4", "harbor5", "network5", "harbor6", "network6", "day7"],
        endings: _lastSeenEndings.keys.toSet(),
      ),
      locale: "id",
    );
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    _expectWithinWidth(tester);

    const screen = Rect.fromLTWH(0, 0, 360, 640);
    for (final title in _lastSeenEndings.values) {
      final node = find.ancestor(of: find.text(title), matching: find.byType(Card));
      await tester.ensureVisible(node);
      await tester.pumpAndSettle();
      final rect = tester.getRect(node);
      expect(screen.intersect(rect), rect, reason: "$title can be scrolled fully into view");
      _expectWhole(tester, title);
    }
    expect(find.text("10 dari 10 ending ditemukan"), findsNWidgets(4), reason: "the Prologue to Day 3");
    _expectWhole(tester, "10 dari 10 ending ditemukan");
  });

  testWidgets('nodes grow with the player\'s text size instead of overflowing', (tester) async {
    _phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpChapters(
      tester,
      story: _lastSeen(),
      meta: _reached(["index", "day1", "day2", "day3", "day4", "harbor5", "harbor6", "day7"], endings: {"end_storm"}),
      locale: "id",
    );
    _expectWhole(tester, "1 dari 10 ending ditemukan");
    _expectWhole(tester, "Dermaga");
    _expectWhole(tester, "The Storm");
    _expectWithinWidth(tester);
  });
}
