import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// [FakeEngineLoader] with a `channels.json`.
class _ChannelLoader extends FakeEngineLoader {
  final List<Channel> channels;

  _ChannelLoader(super.files, this.channels);

  @override
  Future<EnginePackage> initialLoad() async {
    final package = await super.initialLoad();
    return EnginePackage(conversation: package.conversation, profiles: package.profiles, channels: channels);
  }
}

const _miki = Channel(id: "dm", name: "Miki", status: "last seen Saturday 6:12 AM", members: ["miki"]);

Map<String, dynamic> _code() => {
      "type": "INPUT",
      "text": "Enter the four-digit code.",
      "variable": "CODE",
      "keyboard": "digits",
      "min_length": 4,
      "max_length": 4,
    };

void main() {
  setUp(mockAudioChannels);

  Future<StoryController> pumpStory(WidgetTester tester, Map<String, dynamic> index, {Locale? locale}) async {
    final storage = InMemoryStoryStorage();
    await storage.saveSettings(const PlayerSettings(textMsPerChar: 0));
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: _ChannelLoader({"index": index}, const [_miki]),
      storage: storage,
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    // Chat paces itself.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    // The incoming scene is the last one while the scene switch runs.
    final vn = find.byType(VnStage);
    return vn.evaluate().isNotEmpty
        ? tester.widget<VnStage>(vn.last).controller
        : tester.widget<ChatView>(find.byType(ChatView).last).controller;
  }

  Finder sendButton() => find.descendant(of: find.byType(InputPrompt), matching: find.byType(IconButton));

  bool sendEnabled(WidgetTester tester) => tester.widget<IconButton>(sendButton()).onPressed != null;

  for (final mode in ["VN", "CHAT"]) {
    testWidgets('$mode: a digits input opens the number pad and takes exactly its length', (tester) async {
      final controller = await pumpStory(tester, {
        "conversation_id": "cvn",
        "scene": {"mode": mode, "channel_id": "dm"},
        "conversations": [_code()],
      });
      final field = tester.widget<TextField>(find.descendant(of: find.byType(InputPrompt), matching: find.byType(TextField)));
      expect(field.keyboardType, TextInputType.number);
      expect(sendEnabled(tester), isFalse, reason: "nothing typed yet");

      await tester.enterText(find.byType(TextField), "5a3");
      await tester.pump();
      expect(find.text("53"), findsOneWidget, reason: "letters are dropped");
      expect(sendEnabled(tester), isFalse, reason: "too short");

      // The send key on the keyboard doesn't send a short code either.
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(find.byType(InputPrompt), findsOneWidget);

      await tester.enterText(find.byType(TextField), "053012");
      await tester.pump();
      expect(find.text("0530"), findsOneWidget, reason: "cut at max_length, leading zero kept");
      expect(sendEnabled(tester), isTrue);

      await tester.tap(sendButton());
      await tester.pump();
      expect(controller.engine.dataMap["CODE"], "0530");
    });
  }

  testWidgets('a short code sent from code is refused', (tester) async {
    final controller = await pumpStory(tester, {
      "conversation_id": "cvn",
      "scene": {"mode": "VN"},
      "conversations": [_code()],
    });
    await controller.submitInput("530");
    await tester.pump();
    expect(controller.phase, StoryPhase.input);
    expect(controller.engine.dataMap.containsKey("CODE"), isFalse);
  });

  testWidgets('a plain input still sends anything, and empty falls back to the default', (tester) async {
    final controller = await pumpStory(tester, {
      "conversation_id": "cvn",
      "scene": {"mode": "VN"},
      "conversations": [
        {"type": "INPUT", "text": "Name?", "variable": "NAME", "default_value": "Alex"},
      ],
    });
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.text);
    expect(sendEnabled(tester), isTrue);
    await tester.tap(sendButton());
    await tester.pump();
    expect(controller.engine.dataMap["NAME"], "Alex");
  });

  group('chat header', () {
    Map<String, dynamic> chat(Map<String, dynamic> scene) => {
          "conversation_id": "cvn",
          "scene": {"mode": "CHAT", "channel_id": "dm", ...scene},
          "conversations": [_code()],
        };

    testWidgets("shows the time like the story's timestamps, then the channel status, and no day", (tester) async {
      await pumpStory(tester, chat({"day": 0, "time": "23:58"}));
      expect(find.text("11:58 PM · last seen Saturday 6:12 AM"), findsOneWidget);
      expect(find.textContaining("Day"), findsNothing);
    });

    testWidgets('the status may wrap onto a second line instead of cutting it short', (tester) async {
      await pumpStory(tester, chat({"day": 1, "time": "02:14"}));
      final subtitle = tester.widget<Text>(find.text("2:14 AM · last seen Saturday 6:12 AM"));
      expect(subtitle.maxLines, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets("a scene's status replaces the channel's", (tester) async {
      await pumpStory(tester, chat({"time": "21:12", "status": "online"}));
      expect(find.text("9:12 PM · online"), findsOneWidget);
    });

    testWidgets('a scene can hide the status', (tester) async {
      await pumpStory(tester, chat({"time": "06:05", "status": null}));
      expect(find.text("6:05 AM"), findsOneWidget);
      expect(find.textContaining("last seen"), findsNothing);
    });

    testWidgets('a time the story writes another way is shown as written', (tester) async {
      await pumpStory(tester, chat({"time": "late", "status": ""}));
      expect(find.text("late"), findsOneWidget);
    });
  });

  test('clock formats per language', () {
    expect(CeritaStrings.en.sceneTime("00:05"), "12:05 AM");
    expect(CeritaStrings.en.sceneTime("12:30"), "12:30 PM");
    expect(CeritaStrings.en.sceneTime("23.58"), "11:58 PM");
    expect(CeritaStrings.id.sceneTime("02:14"), "02.14");
    expect(CeritaStrings.id.sceneTime("9:05"), "09.05");
    expect(CeritaStrings.en.sceneTime("25:00"), "25:00");
  });
}
