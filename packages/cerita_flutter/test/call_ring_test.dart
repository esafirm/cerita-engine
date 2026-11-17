import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, dynamic> _line(String text) => {"type": "TEXT", "text": text, "profile": "dinda"};

void main() {
  setUp(mockAudioChannels);

  late SilentAudio audio;

  Future<StoryController> call(WidgetTester tester, {String? ring = "ring.mp3"}) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    audio = SilentAudio();
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "cvn",
          "scene": {"mode": "CALL", "channel_id": "dinda", "ring": ?ring},
          "conversations": [
            {..._line("Ka? Sorry."), "voice": "vo_1.mp3"},
            _line("Are you there?"),
            {"type": "INPUT", "text": "Reply", "variable": "R"},
          ],
        },
      }),
      storage: InMemoryStoryStorage(),
      audio: () => audio,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    for (var i = 0; i < 20 && find.byType(CallView).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    return tester.widget<CallView>(find.byType(CallView)).controller;
  }

  Finder caption(String text) => find.text(text, findRichText: true);

  // Away from every button: a tap there moves the call on.
  Future<void> tapScreen(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 120));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a ringing call waits for the player to answer, then says its first line', (tester) async {
    final controller = await call(tester);
    expect(controller.callState, CallState.ringing);
    expect(find.text("Incoming call"), findsOneWidget);
    expect(caption("Ka? Sorry."), findsNothing);
    expect(audio.calls, contains("ring assets/story/music/ring.mp3"));
    expect(audio.calls.where((call) => call.startsWith("voice")), isEmpty, reason: "nobody speaks before the answer");

    await tapScreen(tester);
    expect(caption("Ka? Sorry."), findsNothing, reason: "a tap on the screen doesn't answer");

    await tester.tap(find.text("Answer"));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.callState, CallState.connected);
    expect(audio.calls, contains("ring stop"));
    expect(caption("Ka? Sorry."), findsOneWidget);
    expect(audio.calls.last, startsWith("voice assets/story/music/vo_1.mp3"));
  });

  testWidgets('declining or hanging up makes the caller call back, and the call goes on where it was cut',
      (tester) async {
    final controller = await call(tester);
    await tester.tap(find.text("Decline"));
    await tester.pump();
    expect(find.text("Call ended"), findsOneWidget);

    await tester.pump(StoryController.callbackDelay);
    expect(find.text("Incoming call"), findsOneWidget);
    await tester.tap(find.text("Answer"));
    await tester.pump(const Duration(milliseconds: 500));
    expect(caption("Ka? Sorry."), findsOneWidget);

    audio.calls.clear();
    await tester.tap(find.byIcon(Icons.call_end));
    await tester.pump();
    expect(find.text("Call ended"), findsOneWidget);
    expect(caption("Ka? Sorry."), findsNothing);
    await tapScreen(tester);
    expect(controller.callState, CallState.ended, reason: "a tap doesn't move a cut call on");

    await tester.pump(StoryController.callbackDelay);
    await tester.tap(find.text("Answer"));
    await tester.pump(const Duration(milliseconds: 500));
    expect(caption("Ka? Sorry."), findsOneWidget);
    expect(audio.calls.last, startsWith("voice assets/story/music/vo_1.mp3"), reason: "the cut line is said again");

    await tapScreen(tester);
    expect(caption("Are you there?"), findsOneWidget);
  });

  testWidgets('hold stops the call until it is taken off hold, mute and speaker toggle, the keypad dials',
      (tester) async {
    final controller = await call(tester);
    await tester.tap(find.text("Answer"));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text("Hold"));
    await tester.pump();
    expect(find.text("On hold"), findsOneWidget);
    await tapScreen(tester);
    expect(caption("Ka? Sorry."), findsOneWidget, reason: "a call on hold doesn't move on");
    await tester.tap(find.text("Hold"));
    await tester.pump();
    expect(controller.onHold, isFalse);

    await tester.tap(find.text("Mute"));
    await tester.pump();
    expect(find.byIcon(Icons.mic_off), findsWidgets);

    await tester.tap(find.text("Keypad"));
    await tester.pump();
    await tester.tap(find.text("5"));
    await tester.tap(find.text("#"));
    await tester.pump();
    expect(find.text("5#"), findsOneWidget);
    await tester.tap(find.text("Hide"));
    await tester.pump();
    expect(find.text("Keypad"), findsOneWidget);

    await tapScreen(tester);
    expect(caption("Are you there?"), findsOneWidget);
  });

  testWidgets('a call without a ring is already connected', (tester) async {
    final controller = await call(tester, ring: null);
    expect(controller.callState, CallState.connected);
    expect(caption("Ka? Sorry."), findsOneWidget);
    expect(audio.calls.where((call) => call.startsWith("ring")), isEmpty);
  });
}
