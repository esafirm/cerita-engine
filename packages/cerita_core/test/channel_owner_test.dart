import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

class _Loader extends EngineLoader {
  final List<Channel> channels;

  _Loader(this.channels);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "sekar", "name": "Sekar"},
            {"id": "tasya", "name": "Tasya"},
          ],
        }),
        channels: channels,
        conversation: await loadConversation(Conversation.indexKey),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async => Conversation.fromJson({
        "conversation_id": "cvn",
        "scene": {"mode": "CHAT", "channel_id": "sekar_tasya"},
        "conversations": [
          {"type": "TEXT", "text": "Hi", "profile": "tasya"},
          {"type": "ENDING", "ending_id": "end", "category": "NORMAL", "title": "End"},
        ],
      }, key: conversationId);

  @override
  Future<List<String>> listConversationKeys() async => [Conversation.indexKey];
}

Future<List<String>> _channelIssues(List<Channel> channels) async => [
      for (final issue in await StoryLinter(_Loader(channels)).lint())
        if (issue.file == "channels.json") issue.message,
    ];

void main() {
  test('a thread reads its owner, and keeps it in another language', () {
    final channel = Channel.fromJson({
      "id": "sekar_tasya",
      "name": {"id": "Tasya", "en": "Tasya"},
      "members": ["tasya"],
      "owner": "sekar",
    });
    expect(channel.owner, "sekar");
    expect(channel.localized(const Localizer(locale: "en")).owner, "sekar");
    expect(Channel.fromJson({"id": "dm", "name": "Miki"}).owner, isNull);
  });

  test('the linter flags threads that name unknown characters', () async {
    expect(
      await _channelIssues(const [Channel(id: "sekar_tasya", name: "Tasya", members: ["tasya"], owner: "sekar")]),
      isEmpty,
    );
    expect(await _channelIssues(const [Channel(id: "sekar_tasya", name: "Tasya", members: ["tasyaa"], owner: "sekr")]), [
      "Thread 'sekar_tasya' names unknown character 'tasyaa'",
      "Thread 'sekar_tasya' names unknown character 'sekr'",
    ]);
  });
}
