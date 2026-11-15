import 'package:cerita_flutter/cerita_flutter.dart';
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

void main() {
  setUp(mockAudioChannels);
  languageTests();

  Future<StoryController> pumpStory(WidgetTester tester, Map<String, Map<String, dynamic>> files,
      {Map<String, dynamic>? clues = _clues}) async {
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader(files, clues: clues),
      storage: InMemoryStoryStorage(),
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    await tester.pumpAndSettle();
    return tester.widget<ClueNotifications>(find.byType(ClueNotifications)).controller;
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
