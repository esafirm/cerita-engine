import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, dynamic> _line(String text) => {"type": "TEXT", "text": text, "profile": "dinda"};

void main() {
  setUp(mockAudioChannels);

  late SilentAudio audio;

  Future<StoryController> call(WidgetTester tester, {String? ring = "ring.mp3", String? stay, String? hangUp}) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    audio = SilentAudio();
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader({
        "index": {
          "conversation_id": "cvn",
          "scene": {"mode": "CALL", "channel_id": "dinda", "ring": ?ring, "stay": ?stay, "hangup": ?hangUp},
          "conversations": [
            {..._line("Ka? Sorry."), "voice": "vo_1.mp3"},
            _line("Are you there?"),
            {"type": "INPUT", "text": "Reply", "variable": "R"},
          ],
        },
        "after": {
          "conversation_id": "after",
          "scene": {"mode": "VN"},
          "conversations": [
            {"type": "NARRATION", "text": "You hung up."},
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

  testWidgets('a call that can\'t be hung up shows what the player thinks, and goes on ringing or talking', (
    tester,
  ) async {
    final controller = await call(tester, stay: "Not her. Not now.");
    await tester.tap(find.text("Decline"));
    await tester.pump();
    expect(find.text("Not her. Not now."), findsOneWidget);
    expect(controller.callState, CallState.ringing, reason: "the phone keeps ringing");
    await tester.pump(StoryController.refusalDuration);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("Not her. Not now."), findsNothing);

    await tester.tap(find.text("Answer"));
    await tester.pump(const Duration(milliseconds: 500));
    expect(caption("Ka? Sorry."), findsOneWidget);
    await tester.tap(find.byIcon(Icons.call_end));
    await tester.pump();
    expect(controller.callState, CallState.connected);
    expect(find.text("Not her. Not now."), findsOneWidget);
    expect(caption("Ka? Sorry."), findsOneWidget, reason: "the line stays");

    await tapScreen(tester);
    expect(caption("Are you there?"), findsOneWidget);
    await tester.pump(StoryController.refusalDuration);
  });

  testWidgets('without a stay line, the engine\'s own thought is shown', (tester) async {
    await call(tester);
    await tester.tap(find.text("Decline"));
    await tester.pump();
    expect(find.text("Not now. I need to hear this."), findsOneWidget);
    await tester.pump(StoryController.refusalDuration);
  });

  testWidgets('a call with a hangup target ends there when the player hangs up or declines', (tester) async {
    final controller = await call(tester, hangUp: "after");
    await tester.tap(find.text("Answer"));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.call_end));
    await tester.pump();
    expect(controller.callState, CallState.ended);
    expect(find.text("Call ended"), findsOneWidget);

    await tester.pump(StoryController.hangUpDelay);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(controller.conversation?.key, "after");
    expect(find.text("You hung up.", findRichText: true), findsOneWidget);
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
