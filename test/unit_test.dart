import 'package:flutter_test/flutter_test.dart';
import 'package:fsse/src/engine/data/conversation.dart';
import 'package:fsse/src/engine/data/item_result.dart';
import 'package:fsse/src/engine/data/items/choice.dart';
import 'package:fsse/src/engine/data/items/input.dart';
import 'package:fsse/src/engine/data/items/text.dart';
import 'package:fsse/src/engine/data/profile.dart';
import 'package:fsse/src/engine/data/scene.dart';
import 'package:fsse/src/engine/fsse_engine.dart';
import 'package:fsse/src/engine/utils/var_replacer.dart';

class _FakeEngineLoader extends EngineLoader {
  @override
  Future<EnginePackage> initialLoad() async {
    return const EnginePackage(
      profiles: ProfileData([
        Profile(
          id: "123aaa",
          name: "Nora",
          avatar: "avatar.png",
          sprites: ["nora_open.png", "nora_smile.png"],
        ),
      ]),
      conversation: Conversation(
        conversationId: "cvn_init",
        scene: Scene(background: "bg1.png", music: "sunny.mp3"),
        conversations: [
          InputItemType("What is your name?", "NAME", null),
          TextItemType("Hello {{NAME}}", null),
          ChoiceItemType(
            "Pick one",
            "CHOICE",
            null,
            [Choice("Go next", "A", "target_2")],
          ),
        ],
      ),
    );
  }

  @override
  Future<Conversation> loadConversation(String conversationId) async {
    return Conversation(
      conversationId: conversationId,
      scene: const Scene(background: "bg2.png", music: "sunny.mp3"),
      conversations: const [
        TextItemType("Branched to {{CHOICE}}", null),
      ],
    );
  }
}

void main() {
  group('VariableReplacer', () {
    test('replaces placeholders with values from dataMap', () {
      const template = "Hi my name is {{NAME}} {{HAHA}}";
      final data = {'NAME': 'TikTok', 'HAHA': 'Ketawa'};
      expect(template.replaceWithVars(data), "Hi my name is TikTok Ketawa");
    });

    test('throws when placeholder variable is missing', () {
      const template = "Hello {{MISSING}}";
      expect(() => template.replaceWithVars({}), throwsException);
    });
  });

  group('RealFsseEngine', () {
    test('progresses through items, stores variables, and loads target conversation', () async {
      final engine = RealFsseEngine(_FakeEngineLoader());

      final first = await engine.next();
      expect(first, isA<InputItemType>());

      final second = await engine.next(prevResult: const ItemResult.input("NAME", "Nora"));
      expect(second.getText(), "Hello Nora");

      final third = await engine.next();
      expect(third, isA<ChoiceItemType>());

      final branched = await engine.next(prevResult: const ItemResult.choice("CHOICE", "A", "target_2"));
      expect(branched.getText(), "Branched to A");
      expect(engine.getDataMap(), {"NAME": "Nora", "CHOICE": "A"});
    });
  });
}

