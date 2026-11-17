import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class _ChannelLoader extends FakeEngineLoader {
  final List<Channel> channels;

  _ChannelLoader(super.files, this.channels);

  @override
  Future<EnginePackage> initialLoad() async {
    final package = await super.initialLoad();
    return EnginePackage(conversation: package.conversation, profiles: package.profiles, channels: channels);
  }
}

Map<String, dynamic> _text(String text, String profile) => {"type": "TEXT", "text": text, "profile": profile};

void main() {
  setUp(mockAudioChannels);

  /// Plays a thread with Miki on [owner]'s phone, and the profiles shown typing on the way.
  Future<Set<String?>> play(WidgetTester tester, {String? owner}) async {
    final storage = InMemoryStoryStorage();
    await storage.saveSettings(const PlayerSettings(textMsPerChar: 0));
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: _ChannelLoader({
        "index": {
          "conversation_id": "cvn",
          "scene": {"mode": "CHAT", "channel_id": "nora_miki"},
          "conversations": [
            _text("you there?", "miki"),
            _text("yeah. what's up", "nora"),
            {..._text("ok", "nora"), "typing_delay_ms": 800},
            _text("they called me", "miki"),
            {"type": "INPUT", "text": "Reply", "variable": "R"},
          ],
        },
      }, [Channel(id: "nora_miki", name: "Miki", members: const ["miki"], owner: owner)]),
      storage: storage,
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    final typing = <String?>{};
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final chat = find.byType(ChatView);
      if (chat.evaluate().isEmpty) continue;
      final controller = tester.widget<ChatView>(chat.last).controller;
      if (controller.phase == StoryPhase.typing) typing.add(controller.typingProfile?.id);
      if (find.byType(TypingBubble).evaluate().isNotEmpty) typing.add("bubble:${controller.typingProfile?.id}");
    }
    expect(find.text("they called me"), findsOneWidget);
    return typing;
  }

  bool outgoing(WidgetTester tester, String text) => find
      .ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is Align && w.alignment == Alignment.centerRight))
      .evaluate()
      .isNotEmpty;

  testWidgets("the owner's messages are outgoing, without a name or typing", (tester) async {
    final typing = await play(tester, owner: "nora");
    expect(outgoing(tester, "yeah. what's up"), isTrue);
    expect(outgoing(tester, "ok"), isTrue);
    expect(outgoing(tester, "they called me"), isFalse);
    expect(find.text("Nora"), findsNothing, reason: "an outgoing bubble has no sender name");
    expect(typing, isNot(contains("nora")));
    expect(typing, isNot(contains("bubble:nora")));
    expect(typing, contains("miki"));
    // The header is the contact's, not the owner's.
    expect(find.text("Miki"), findsWidgets);
  });

  testWidgets('without an owner, everyone else is incoming', (tester) async {
    final typing = await play(tester);
    expect(outgoing(tester, "yeah. what's up"), isFalse);
    expect(find.text("Nora"), findsOneWidget);
    expect(typing, contains("nora"));
  });
}
