import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  setUp(mockAudioChannels);

  testWidgets('holding the stage hides the UI until release, holding a button does not', (tester) async {
    final storage = InMemoryStoryStorage();
    await storage.saveSettings(const PlayerSettings(textMsPerChar: 0));
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "cvn",
          "scene": {"mode": "VN"},
          "conversations": [
            {"type": "NARRATION", "text": "The tide is out."},
            {
              "type": "CHOICE",
              "text": "Wade in?",
              "variable": "W",
              "choices": [
                {"text": "Yes"},
                {"text": "No"},
              ],
            },
            {"type": "NARRATION", "text": "Still out."},
          ],
        },
      }),
      storage: storage,
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final line = find.text("The tide is out.", findRichText: true);
    expect(line, findsOneWidget);

    final stage = await tester.startGesture(const Offset(400, 200));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(line, findsNothing, reason: "held: the dialogue box is hidden");
    await stage.up();
    await tester.pump();
    expect(line, findsOneWidget, reason: "released: it is back");

    await tester.tapAt(const Offset(400, 200));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final choice = find.descendant(of: find.byType(ChoiceList), matching: find.byType(InkWell)).last;
    final button = await tester.startGesture(tester.getCenter(choice));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(choice, findsOneWidget, reason: "a held button doesn't hide the UI");
    await button.up();
    await tester.pump(const Duration(milliseconds: 500));
  });
}
