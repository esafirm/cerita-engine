import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Map<String, dynamic> _text(String text, {String profile = "nora:0", String? voice}) =>
    {"type": "TEXT", "text": text, "profile": profile, "voice": ?voice};

Map<String, dynamic> _story(List<Map<String, dynamic>> items, {Map<String, dynamic> scene = const {"mode": "VN"}}) =>
    {"conversation_id": "cvn", "scene": scene, "conversations": items};

void main() {
  setUp(mockAudioChannels);

  /// Without [settle], returns as soon as the first line is on screen, before it is typed out.
  Future<(StoryController, SilentAudio)> pumpStory(WidgetTester tester, Map<String, dynamic> index,
      {PlayerSettings settings = const PlayerSettings(), bool settle = true}) async {
    final storage = InMemoryStoryStorage();
    await storage.saveSettings(settings);
    final audio = SilentAudio();
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader({"index": index}),
      storage: storage,
      audio: () => audio,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 20 && find.byType(DialogueBox).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    // The incoming scene is the last one while the scene switch runs.
    return (tester.widget<VnStage>(find.byType(VnStage).last).controller, audio);
  }

  group('TypewriterText', () {
    Future<GlobalKey<TypewriterTextState>> pumpLine(WidgetTester tester, String text,
        {int msPerChar = 10, bool instant = false, Duration? autoResume, VoidCallback? onTyped}) async {
      final key = GlobalKey<TypewriterTextState>();
      await tester.pumpWidget(_wrap(TypewriterText(
        text,
        key: key,
        msPerChar: msPerChar,
        instant: instant,
        autoResume: autoResume,
        onTyped: onTyped,
        builder: (context, text, done) => Column(children: [text, if (done) const Text("NEXT")]),
      )));
      return key;
    }

    testWidgets('stops at {w} until a tap, then types the rest', (tester) async {
      var typed = 0;
      final key = await pumpLine(tester, "Wait.{w} Why?", onTyped: () => typed++);
      await tester.pump(const Duration(milliseconds: 100));
      expect(key.currentState!.visibleText, "Wait.");
      expect(find.text("NEXT"), findsOneWidget, reason: "the box shows its next indicator at a stop");
      expect(typed, 0);

      expect(key.currentState!.complete(), isTrue);
      await tester.pump(); // The typing starts on this frame.
      await tester.pump(const Duration(milliseconds: 15));
      expect(key.currentState!.visibleText, "Wait. ");
      expect(key.currentState!.complete(), isTrue, reason: "a tap while typing finishes the part");
      await tester.pump();
      expect(key.currentState!.visibleText, "Wait. Why?");
      expect(typed, 1);
      expect(key.currentState!.complete(), isFalse);
    });

    testWidgets('{w=ms} pauses and {speed} changes the pace', (tester) async {
      // a at 10 ms, b at 20, the pause, c at 530, then 20 ms per character: d at 550, e at 570.
      final key = await pumpLine(tester, "ab{w=500}c{speed=0.5}de", msPerChar: 10);
      await tester.pump(const Duration(milliseconds: 25));
      expect(key.currentState!.visibleText, "ab");
      await tester.pump(const Duration(milliseconds: 480));
      expect(key.currentState!.visibleText, "ab");
      await tester.pump(const Duration(milliseconds: 30));
      expect(key.currentState!.visibleText, "abc");
      await tester.pump(const Duration(milliseconds: 20));
      expect(key.currentState!.visibleText, "abcd");
      await tester.pump(const Duration(milliseconds: 20));
      expect(key.currentState!.visibleText, "abcde");
    });

    testWidgets('auto mode continues after a {w} by itself', (tester) async {
      final key = await pumpLine(tester, "a{w}b", autoResume: const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 50));
      expect(key.currentState!.visibleText, "a");
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 50));
      expect(key.currentState!.visibleText, "ab");
    });

    testWidgets('instant shows the whole line and ignores stops', (tester) async {
      var typed = 0;
      final key = await pumpLine(tester, "a{w}b{w=900}c", instant: true, onTyped: () => typed++);
      await tester.pump();
      expect(key.currentState!.visibleText, "abc");
      expect(typed, 1);
    });

    testWidgets('the untyped rest is laid out but transparent', (tester) async {
      final key = await pumpLine(tester, "{b}Hi{/b} you");
      await tester.pump(const Duration(milliseconds: 15));
      expect(key.currentState!.visibleText, "H");
      final spans = <TextSpan>[];
      tester.widget<Text>(find.byType(Text).first).textSpan!.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });
      expect([for (final span in spans) span.text], ["H", "i", " you"]);
      expect(spans[0].style!.fontWeight, FontWeight.bold);
      expect(spans[1].style!.color, Colors.transparent);
      expect(spans[2].style!.color, Colors.transparent);
    });
  });

  testWidgets('TaggedText draws colours and moving letters', (tester) async {
    await tester.pumpWidget(_wrap(const TaggedText("{color=#FF0000}red{/color} {wave}hi{/wave}")));
    final text = tester.widget<Text>(find.byType(Text).first);
    final span = text.textSpan! as TextSpan;
    expect((span.children![0] as TextSpan).style!.color, const Color(0xFFFF0000));
    expect(span.children!.whereType<WidgetSpan>(), hasLength(2));
    expect(find.text("h"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100)); // The letters keep moving.
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('NVL shows the page, and a page action starts a new one', (tester) async {
    final (controller, _) = await pumpStory(
      tester,
      _story([
        _text("First line"),
        {"type": "NARRATION", "text": "The rain gets louder."},
        {"type": "STAGE", "actions": [{"action": "page"}]},
        _text("New page"),
      ], scene: const {"mode": "VN", "textbox": "nvl"}),
      settings: const PlayerSettings(textMsPerChar: 0),
    );
    expect(find.byType(NvlPage), findsOneWidget);
    expect(find.byType(DialogueBox), findsNothing);

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "The rain gets louder.");
    expect(NvlPage.linesOf(controller).map((e) => e.itemType?.getText()), ["First line", "The rain gets louder."]);
    expect(find.text("First line"), findsOneWidget);
    expect(find.text("Nora"), findsOneWidget);

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "New page");
    expect(find.text("First line"), findsNothing);
    expect(NvlPage.linesOf(controller), hasLength(1));
  });

  testWidgets('a {nw} line moves on by itself', (tester) async {
    final (controller, _) = await pumpStory(
      tester,
      _story([_text("I was going to say-{nw}"), _text("Stop.")]),
      settings: const PlayerSettings(textMsPerChar: 0),
    );
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Stop.");
  });

  testWidgets('auto mode waits for the line to type out', (tester) async {
    final line = "A slow line that takes a while to type out.";
    final (controller, _) = await pumpStory(
      tester,
      _story([_text(line), _text("Next")]),
      settings: const PlayerSettings(textMsPerChar: 80, autoDelayMs: 400),
      settle: false,
    );
    controller.toggleAuto();
    // The reading delay alone (400 + 45 * 400 / 1200 per character) is shorter than the typing (80 ms each).
    await tester.pump(const Duration(milliseconds: 2500));
    expect(controller.current?.getText(), line);
    // Typed out at about 3.5 s, then the reading delay of about 1 s.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(controller.current?.getText(), line);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Next");
  });

  testWidgets('music and ambience follow the scene and stage, with fades', (tester) async {
    final (controller, audio) = await pumpStory(
      tester,
      _story([
        _text("one"),
        {
          "type": "STAGE",
          "actions": [
            {"action": "music", "file": "night.mp3", "fade_ms": 3000},
            {"action": "ambience", "file": null, "fade_ms": 0},
          ],
        },
        _text("two"),
      ], scene: const {"mode": "VN", "music": "theme.mp3", "ambience": "rain.mp3"}),
      settings: const PlayerSettings(textMsPerChar: 0),
    );
    expect(audio.calls, containsAll(["bgm assets/story/music/theme.mp3 -", "ambience assets/story/music/rain.mp3 -"]));
    audio.calls.clear();
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "two");
    expect(audio.calls, ["bgm assets/story/music/night.mp3 3000", "ambience null 0"]);
  });

  testWidgets('voices play at the speaker volume and replay from the backlog', (tester) async {
    final (controller, audio) = await pumpStory(
      tester,
      _story([_text("Hey", profile: "miki:0", voice: "miki_01.mp3"), _text("Hi", profile: "nora:0")]),
      settings: const PlayerSettings(textMsPerChar: 0, voiceVolumes: {"miki": 0.5}),
    );
    expect(audio.calls.where((call) => call.startsWith("voice")), ["voice assets/story/music/miki_01.mp3 0.5"]);
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    audio.calls.clear();

    await tester.tap(find.byTooltip("Backlog"));
    await tester.pumpAndSettle();
    expect(find.byTooltip("Play voice"), findsOneWidget);
    await tester.tap(find.byTooltip("Play voice"));
    expect(audio.calls, ["voice assets/story/music/miki_01.mp3 0.5"]);
    expect(controller.current?.getText(), "Hi");
  });

  testWidgets('settings list a voice volume for each voiced character', (tester) async {
    final storage = InMemoryStoryStorage();
    final prefs = PlayerPrefs(storage);
    final loader = FakeEngineLoader({
      "index": _story([_text("Hey", profile: "miki:0", voice: "m.mp3"), _text("Hi")]),
    });
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: prefs, loader: loader)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text("Miki"), 100);
    expect(find.text("Character voices"), findsOneWidget);
    expect(find.text("Nora"), findsNothing);

    final slider = find.descendant(of: find.widgetWithText(ListTile, "Miki"), matching: find.byType(Slider));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.left + rect.width * 0.2, rect.center.dy));
    await tester.pumpAndSettle();
    expect(prefs.value.voiceVolumes["miki"], lessThan(0.5));
  });
}
