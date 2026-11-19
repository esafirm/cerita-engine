import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

/// A story gate keeps the player out of conversations the app decides on, e.g. the chapters a purchase unlocks.

class _FakeEngineLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  _FakeEngineLoader(this.files);

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "dinda", "name": "Dinda", "sprites": ["dinda.png"]},
          ],
        }),
        conversation: await loadConversation(Conversation.indexKey),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);
}

Map<String, dynamic> _conversation(List<Map<String, dynamic>> items, {required String chapter}) => {
      "conversation_id": "cvn",
      "chapter": chapter,
      "checkpoint": true,
      "scene": {"mode": "VN"},
      "conversations": items,
    };

Map<String, dynamic> _text(String text) => {"type": "TEXT", "text": text, "profile": "dinda:0"};

/// Day 1 is free and leads to Day 2, which is closed.
final _story = {
  "index": _conversation([
    _text("Day one."),
    {"type": "JUMP", "target": "day2", "effects": [{"variable": "met_dinda", "op": "set", "value": true}]},
  ], chapter: "Day 1"),
  "day2": _conversation([_text("Day two.")], chapter: "Day 2"),
};

bool _freeOnly(Conversation conversation) => conversation.chapterText?.resolve(null) == "Day 1";

void main() {
  test('stops at a closed conversation without entering it or unlocking its checkpoint', () async {
    final storage = InMemoryStoryStorage();
    final engine = RealFsseEngine(_FakeEngineLoader(_story), storage: storage, gate: _freeOnly);
    await engine.start();
    expect((await engine.next() as TextItemType).text, "Day one.");

    await expectLater(
      engine.next(),
      throwsA(isA<StoryGateException>().having((e) => e.conversation.key, "conversation", "day2")),
    );
    expect(engine.currentConversation?.key, "index");
    expect((await storage.loadMeta()).unlockedCheckpoints.keys, {"index"});
  });

  test('a save taken before the gate goes on once the gate opens', () async {
    final storage = InMemoryStoryStorage();
    var open = false;
    final engine = RealFsseEngine(_FakeEngineLoader(_story), storage: storage, gate: (c) => open || _freeOnly(c));
    await engine.start();
    await engine.next();
    await engine.saveTo(SaveSlot.autoSlotId);
    await expectLater(engine.next(), throwsA(isA<StoryGateException>()));

    open = true;
    await engine.start(save: await storage.loadSlot(SaveSlot.autoSlotId));
    expect((await engine.next() as TextItemType).text, "Day two.");
    expect(engine.getDataMap()["met_dinda"], isTrue);
  });

  test('starting at a closed checkpoint or save throws', () async {
    final storage = InMemoryStoryStorage();
    final open = RealFsseEngine(_FakeEngineLoader(_story), storage: storage);
    await open.start();
    await open.next();
    await open.next();
    await open.saveTo(1);
    final checkpoint = (await storage.loadMeta()).unlockedCheckpoints["day2"]!;

    final gated = RealFsseEngine(_FakeEngineLoader(_story), storage: storage, gate: _freeOnly);
    await expectLater(gated.start(checkpoint: checkpoint), throwsA(isA<StoryGateException>()));
    await expectLater(gated.start(save: await storage.loadSlot(1)), throwsA(isA<StoryGateException>()));
  });

  test('a developer jump into a closed conversation throws', () async {
    final engine = RealFsseEngine(_FakeEngineLoader(_story), gate: _freeOnly);
    await engine.start();
    await expectLater(engine.jumpTo("day2"), throwsA(isA<StoryGateException>()));
  });
}
