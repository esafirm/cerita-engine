import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The Case Board, the clue notification and evidence questions (backlogs CE-05 and CE-06).

const _strings = CeritaStrings.en;

const _clues = {
  "clues": [
    {
      "id": "pier_photo",
      "title": "Pier photo",
      "description": "A boat at the end of the pier.",
      "key": true,
      "chapter": "Day 2",
    },
    {"id": "harbor_log", "title": "Harbor log", "chapter": "Day 3"},
  ],
};

Map<String, dynamic> _text(String text, {String? id, List<Map<String, dynamic>>? effects}) =>
    {"type": "TEXT", "id": ?id, "text": text, "profile": "nora:0", "effects": ?effects};

Map<String, Map<String, dynamic>> _story({String mode = "VN"}) => {
      "index": {
        "conversation_id": "cvn",
        "scene": {"mode": mode, if (mode == "CHAT") "channel_id": "thread_nora"},
        "conversations": [
          _text("Look at this.", effects: [{"variable": "clue_pier_photo", "op": "set", "value": true}]),
          {
            "type": "CHOICE",
            "source": "clues",
            "text": "Which clue?",
            "profile": "nora:0",
            "responses": [{"clue": "pier_photo", "target": "#right"}],
            "fallback": {"target": "#right"},
          },
          _text("Right.", id: "right"),
          _text("The end."),
        ],
      },
    };

/// A HUD much taller than the default one, as a skin may draw it.
class _TallHudSkin extends StorySkin {
  const _TallHudSkin();

  @override
  Widget vnHud(BuildContext context, VnHud hud) => SafeArea(
        child: SizedBox(
          height: 160,
          child: Align(
            alignment: Alignment.topRight,
            child: TextButton(onPressed: hud.onBacklog, child: const Text("LOG")),
          ),
        ),
      );
}

/// Fails if anything is drawn over [finder]: points across its whole area must reach it.
void expectUncovered(WidgetTester tester, Finder finder) {
  final target = tester.renderObject(finder);
  final rect = tester.getRect(finder).deflate(1);
  for (final x in [0.0, 0.25, 0.5, 0.75, 1.0]) {
    for (final y in [0.0, 0.5, 1.0]) {
      final point = Offset(rect.left + rect.width * x, rect.top + rect.height * y);
      final result = HitTestResult();
      tester.binding.hitTestInView(result, point, tester.view.viewId);
      expect(result.path.any((entry) => entry.target == target), isTrue,
          reason: "something covers $finder at $point");
    }
  }
}

Finder _inPicker(Finder finder) => find.descendant(of: find.byType(EvidencePicker), matching: finder);

/// The picker's header: the prompt, the "pick a clue" line and the countdown bar when there is one.
void expectPickerHeaderUncovered(WidgetTester tester, {bool countdown = false}) {
  expectUncovered(tester, _inPicker(find.byType(TaggedText)));
  expectUncovered(tester, _inPicker(find.text(_strings.chooseEvidence)));
  if (countdown) expectUncovered(tester, _inPicker(find.byType(LinearProgressIndicator)));
}

void main() {
  setUp(mockAudioChannels);
  languageTests();

  Future<StoryController> pumpStory(WidgetTester tester, Map<String, Map<String, dynamic>> files,
      {Map<String, dynamic>? clues = _clues, StorySkin skin = const StorySkin()}) async {
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader(files, clues: clues),
      storage: InMemoryStoryStorage(),
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StorySkinScope(skin: skin, child: StoryScreen(setup: setup))));
    await tester.pumpAndSettle();
    return tester.widget<ClueNotifications>(find.byType(ClueNotifications)).controller;
  }

  for (final (name, skin) in [("default", const StorySkin()), ("tall", const _TallHudSkin())]) {
    testWidgets('in VN, the picker sits below the $name HUD and a clue found just before shows no notification',
        (tester) async {
      tester.view.physicalSize = const Size(411, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final story = _story();
      story["index"]!["scene"] = {"mode": "VN", "day": 1, "time": "21:00"};
      (story["index"]!["conversations"] as List)[1]
        ..["timeout_ms"] = 30000
        ..["timeout"] = {"target": "#right"};
      final controller = await pumpStory(tester, story, skin: skin);
      expect(find.text(_strings.clueFound("Pier photo")), findsOneWidget);

      // Straight on to the question, while the notification would still be up. The countdown keeps frames
      // coming, so no pumpAndSettle until it stops.
      await tester.tap(find.byType(VnStage));
      for (var i = 0; i < 30 && find.byType(EvidencePicker).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(EvidencePicker), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_strings.clueFound("Pier photo")), findsNothing, reason: "it would cover the picker");
      expect(find.byTooltip("Backlog").evaluate().length + find.text("LOG").evaluate().length, 1,
          reason: "the HUD stays, with the backlog at hand");
      expectPickerHeaderUncovered(tester, countdown: true);

      await tester.tap(find.text("Pier photo").last);
      await tester.pump();
      expectPickerHeaderUncovered(tester, countdown: true);
      await tester.tap(find.text(_strings.present));
      await tester.pumpAndSettle();
      expect(controller.current?.getText(), "Right.");
      expect(find.text(_strings.clueFound("Pier photo")), findsNothing, reason: "dropped, not put off");
      expect(controller.newClues, hasLength(1), reason: "the board's badge counts it");
    });
  }

  /// Lets the clue notification time out, so no timer is left pending.
  Future<void> waitOutNotifications(WidgetTester tester) async {
    await tester.pump(ClueNotifications.duration);
    await tester.pumpAndSettle();
  }

  testWidgets('a story without clues shows no Case Board anywhere', (tester) async {
    await pumpStory(tester, {
      "index": {
        "conversation_id": "cvn",
        "scene": {"mode": "VN"},
        "conversations": [_text("Hello.")],
      },
    }, clues: null);
    expect(find.byTooltip(_strings.caseBoard), findsNothing);
    await tester.tap(find.byTooltip("Menu"));
    await tester.pumpAndSettle();
    expect(find.textContaining(_strings.caseBoard), findsNothing);
  });

  testWidgets('a found clue is announced, badged, shown on the board and viewed once the board closes',
      (tester) async {
    final controller = await pumpStory(tester, _story());
    expect(find.text(_strings.clueFound("Pier photo")), findsOneWidget);
    expect(controller.newClues, hasLength(1));

    await tester.tap(find.byTooltip(_strings.caseBoard));
    await tester.pumpAndSettle();
    expect(find.byType(CaseBoardScreen), findsOneWidget);
    expect(controller.storyHeld, isTrue);
    expect(find.text("Day 2"), findsOneWidget);
    expect(find.text("Pier photo"), findsOneWidget);
    expect(find.text(_strings.newClue), findsOneWidget);
    expect(find.text("Harbor log"), findsNothing, reason: "only found clues are shown");

    await tester.tap(find.text("Pier photo"));
    await tester.pumpAndSettle();
    expect(find.text("A boat at the end of the pier."), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // closes the detail sheet
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(controller.storyHeld, isFalse);
    expect(controller.newClues, isEmpty);
    await waitOutNotifications(tester);
  });

  testWidgets('tapping the notification opens the clue on the board', (tester) async {
    await pumpStory(tester, _story());
    await tester.tap(find.text(_strings.clueFound("Pier photo")));
    await tester.pumpAndSettle();
    expect(find.byType(CaseBoardScreen), findsOneWidget);
    expect(find.text("A boat at the end of the pier."), findsOneWidget);
    await waitOutNotifications(tester);
  });

  testWidgets('an evidence question opens the picker, needs a confirmation, and the backlog records the clue',
      (tester) async {
    final controller = await pumpStory(tester, _story());
    await waitOutNotifications(tester); // it covers the HUD
    await tester.tap(find.byType(VnStage));
    await tester.pumpAndSettle();
    expect(controller.current, isA<EvidenceItemType>());
    expect(find.byType(EvidencePicker), findsOneWidget);
    expect(find.byTooltip(_strings.caseBoard), findsNothing, reason: "the picker is the board");

    await tester.tap(find.text("Pier photo").last);
    await tester.pumpAndSettle();
    expect(controller.current, isA<EvidenceItemType>(), reason: "a tap only opens the detail");
    await tester.tap(find.text(_strings.back));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Pier photo").last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_strings.present));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Right.");

    await tester.tap(find.byTooltip("Backlog"));
    await tester.pumpAndSettle();
    expect(find.text(_strings.presented("Pier photo"), findRichText: true), findsOneWidget);
    await waitOutNotifications(tester);
  });

  testWidgets('in chat, the picker replaces the tray and the clue is sent as a message', (tester) async {
    final controller = await pumpStory(tester, _story(mode: "CHAT"));
    // The thread moves on by itself to the question.
    for (var i = 0; i < 10 && controller.current is! EvidenceItemType; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(find.byType(EvidencePicker), findsOneWidget);
    expectPickerHeaderUncovered(tester);

    await tester.tap(find.text("Pier photo").last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_strings.present));
    await tester.pump();
    expect(find.byType(EvidencePicker), findsNothing);
    expect(find.descendant(of: find.byType(MessageBubble), matching: find.text("Pier photo")), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsWidgets);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('a timed choice stops its countdown while the story is held', (tester) async {
    final controller = await pumpStory(tester, {
      "index": {
        "conversation_id": "cvn",
        "scene": {"mode": "VN"},
        "conversations": [
          _text("Hurry.", effects: [{"variable": "clue_pier_photo", "op": "set", "value": true}]),
          {
            "type": "CHOICE",
            "text": "Now?",
            "timeout_ms": 2000,
            "choices": [{"text": "Yes"}, {"text": "No"}],
          },
          _text("Done."),
        ],
      },
    });
    await waitOutNotifications(tester);
    await tester.tap(find.byType(VnStage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.phase, StoryPhase.choice);

    await tester.tap(find.byTooltip(_strings.caseBoard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.phase, StoryPhase.choice, reason: "the countdown waited under the board");

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Done.");
  });
}

void languageTests() {
  testWidgets('clue text and the presented line follow a language switch', (tester) async {
    mockAudioChannels();
    final files = _story();
    files["index"]!.addAll({"source_locale": "id", "locales": ["id", "en"]});
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader(files, clues: {
        "clues": [
          {"id": "pier_photo", "title": {"id": "Foto dermaga", "en": "Pier photo"}, "chapter": "Day 2"},
        ],
      }),
      storage: InMemoryStoryStorage(),
      audio: SilentAudio.new,
    );
    final language = StoryLanguage(locale: "en", locales: const StoryLocales(locales: ["id", "en"]));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => StoryLanguageScope(language: language, child: child!),
      home: StoryScreen(setup: setup),
    ));
    await tester.pumpAndSettle();
    expect(find.text("Clue found: Pier photo"), findsOneWidget);
    await tester.pump(ClueNotifications.duration);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(VnStage));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Pier photo").last);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Present"));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Backlog"));
    await tester.pumpAndSettle();
    expect(find.text("Presented: Pier photo", findRichText: true), findsOneWidget);

    await language.select("id");
    await tester.pumpAndSettle();
    expect(find.text("Ditunjukkan: Foto dermaga", findRichText: true), findsOneWidget);
    expect(find.text("Presented: Pier photo", findRichText: true), findsNothing);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Papan Kasus"));
    await tester.pumpAndSettle();
    expect(find.text("Papan Kasus"), findsOneWidget);
    expect(find.text("Foto dermaga"), findsOneWidget);
  });
}
