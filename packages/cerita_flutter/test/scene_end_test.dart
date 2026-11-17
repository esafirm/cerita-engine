import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, dynamic> _text(String text) => {"type": "TEXT", "text": text, "profile": "miki"};

const _morning = {
  "conversation_id": "morning",
  "scene": {"mode": "VN"},
  "conversations": [
    {"type": "NARRATION", "text": "Morning."},
  ],
};

void main() {
  setUp(mockAudioChannels);

  Future<StoryController> play(WidgetTester tester, Map<String, Map<String, dynamic>> files) async {
    final storage = InMemoryStoryStorage();
    await storage.saveSettings(const PlayerSettings(textMsPerChar: 0));
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader(files),
      storage: storage,
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    for (var i = 0; i < 20 && _views(tester).isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return _views(tester).first;
  }

  Future<void> wait(WidgetTester tester, {int seconds = 8}) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a thread that ends its scene waits for a tap before the next scene', (tester) async {
    final controller = await play(tester, {
      "index": {
        "conversation_id": "cvn",
        "scene": {"mode": "CHAT", "channel_id": "miki"},
        "conversations": [
          _text("you there?"),
          _text("call me tomorrow"),
          {"type": "JUMP", "target": "morning"},
        ],
      },
      "morning": _morning,
    });
    await wait(tester);
    expect(find.text("call me tomorrow"), findsOneWidget);
    expect(controller.sceneEndHeld, isTrue);
    expect(controller.conversation?.key, "index", reason: "the thread waits for the player");
    expect(find.text("Tap to continue"), findsOneWidget);

    await tester.tap(find.text("Tap to continue"));
    await wait(tester, seconds: 2);
    expect(controller.conversation?.key, "morning");
    expect(controller.sceneEndHeld, isFalse);
  });

  testWidgets('a thread that goes on in the same chat moves on by itself', (tester) async {
    final controller = await play(tester, {
      "index": {
        "conversation_id": "cvn",
        "scene": {"mode": "CHAT", "channel_id": "miki"},
        "conversations": [
          _text("you there?"),
          {"type": "JUMP", "target": "more"},
        ],
      },
      "more": {
        "conversation_id": "more",
        "scene": {"mode": "CHAT", "channel_id": "miki"},
        "conversations": [
          _text("hello??"),
          {"type": "INPUT", "text": "Reply", "variable": "R"},
        ],
      },
    });
    await wait(tester);
    expect(find.text("hello??"), findsOneWidget);
    expect(controller.sceneEndHeld, isFalse);
  });

  testWidgets('a stage direction that ends a VN scene waits for a tap, and Auto goes on by itself', (tester) async {
    final controller = await play(tester, {
      "index": {
        "conversation_id": "cvn",
        "scene": {"mode": "VN"},
        "conversations": [
          {"type": "NARRATION", "text": "Night."},
          {"type": "WAIT", "duration_ms": 300},
          {"type": "JUMP", "target": "morning"},
        ],
      },
      "morning": _morning,
    });
    await wait(tester, seconds: 1);
    await tester.tapAt(const Offset(400, 300));
    await wait(tester, seconds: 1);
    expect(controller.sceneEndHeld, isTrue);
    expect(find.text("Tap to continue"), findsOneWidget);
    expect(controller.conversation?.key, "index");

    controller.toggleAuto();
    await wait(tester, seconds: 4);
    expect(controller.conversation?.key, "morning");
  });
}

List<StoryController> _views(WidgetTester tester) => [
  ...tester.widgetList<ChatView>(find.byType(ChatView)).map((view) => view.controller),
  ...tester.widgetList<VnStage>(find.byType(VnStage)).map((view) => view.controller),
];
