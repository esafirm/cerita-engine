import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

/// Unlocking everything for a tester or admin (authoring tools §5).

class _FakeEngineLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  _FakeEngineLoader(this.files);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "tasya", "name": "Tasya", "sprites": ["tasya.png"]},
          ],
        }),
        conversation: await loadConversation(Conversation.indexKey),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);

  @override
  Future<List<String>> listConversationKeys() async => files.keys.toList();
}

Map<String, dynamic> _conversation(List<Map<String, dynamic>> items, {String? chapter, bool checkpoint = false}) => {
      "conversation_id": "cvn",
      "chapter": ?chapter,
      "checkpoint": checkpoint,
      "scene": {"mode": "VN", "music": "theme.mp3"},
      "conversations": items,
    };

Map<String, dynamic> _text(String text, {List<Map<String, dynamic>>? effects}) =>
    {"type": "TEXT", "text": text, "profile": "tasya:0", "effects": ?effects};

Map<String, dynamic> _ending(String id) =>
    {"type": "ENDING", "ending_id": id, "title": id, "category": "GOOD", "summary": "."};

/// A puzzle, then a timed choice whose first option is a bad end. The timeout and the last option go on to a
/// route split, and only the last option reaches the network route. The lab is never reached at all.
Map<String, Map<String, dynamic>> _story() => {
      "index": _conversation([
        _text("Day one.", effects: [
          {"variable": "clue_photo", "op": "set", "value": true},
          {"variable": "heard_note", "op": "meta_set"},
        ]),
        {"type": "INPUT", "variable": "CODE", "text": "Code?"},
        {
          "type": "CHOICE",
          "variable": "HAND",
          "text": "Hand it over?",
          "timeout_ms": 5000,
          "default_choice": 1,
          "choices": [
            {"text": "Yes", "value": "yes", "target": "bad"},
            {"text": "Wait", "value": "wait", "target": "harbor"},
            {"text": "Network", "value": "net", "target": "network"},
          ],
        },
      ], chapter: "Day 1", checkpoint: true),
      "bad": _conversation([
        {"type": "MEDIA", "media_type": "CG", "uri": "cg_bad.png", "unlock_id": "cg_bad"},
        _ending("end_bad"),
      ]),
      "harbor": _conversation([_text("The pier."), _ending("end_harbor")], chapter: "Harbor", checkpoint: true),
      "network": _conversation([_text("The people."), _ending("end_network")], chapter: "Network", checkpoint: true),
      "lab": _conversation([_text("Never reached.")], chapter: "Lab", checkpoint: true),
    };

void main() {
  test('unlocks every picture, ending, track and chapter', () async {
    final meta = GlobalMetaState();
    final report = await StoryUnlocker(_FakeEngineLoader(_story())).unlockAll(meta);

    expect(meta.unlockedMediaIds, {"cg_bad"});
    expect(meta.unlockedEndingIds, {"end_bad", "end_harbor", "end_network"});
    expect(meta.heardMusic, {"theme.mp3"});
    expect(meta.unlockedCheckpoints.keys, unorderedEquals(["index", "harbor", "network", "lab"]));
    expect((report.chapters, report.media, report.endings, report.music), (4, 1, 3, 1));
  });

  test('a chapter keeps the variables of a headless run that reached it', () async {
    final meta = GlobalMetaState();
    await StoryUnlocker(_FakeEngineLoader(_story())).unlockAll(meta);

    // The timed choice takes its timeout option on the first run, so the harbor gets there without the bad end.
    expect(meta.unlockedCheckpoints["harbor"]!.dataMap, containsPair("HAND", "wait"));
    expect(meta.unlockedCheckpoints["harbor"]!.dataMap, containsPair("clue_photo", true));
    // Only the run that takes last options reaches the network.
    expect(meta.unlockedCheckpoints["network"]!.dataMap, containsPair("HAND", "net"));
  });

  test('a chapter no run reaches starts empty and is reported', () async {
    final meta = GlobalMetaState();
    final report = await StoryUnlocker(_FakeEngineLoader(_story())).unlockAll(meta);

    expect(meta.unlockedCheckpoints["lab"]!.dataMap, isEmpty);
    expect(meta.unlockedCheckpoints["lab"]!.chapter.toString(), "Lab");
    expect(report.unplayedChapters, ["lab"]);
  });

  test('the headless runs leave the player\'s memory and progress alone', () async {
    final reached = Checkpoint(
      conversationKey: "harbor",
      dataMap: const {"mine": true},
      unlockedAt: DateTime(2026),
    );
    final meta = GlobalMetaState(unlockedCheckpoints: {"harbor": reached}, unlockedEndingIds: {"end_harbor"});
    final report = await StoryUnlocker(_FakeEngineLoader(_story())).unlockAll(meta);

    expect(meta.unlockedCheckpoints["harbor"], same(reached), reason: "a chapter already reached keeps its snapshot");
    expect(report.chapters, 3);
    expect(report.endings, 2);
    expect(meta.rememberedFacts, isEmpty);
    expect(meta.seenItems, isEmpty);
    expect(meta.chosenChoices, isEmpty);
  });
}
