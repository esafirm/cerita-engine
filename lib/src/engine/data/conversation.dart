import 'items/base.dart';
import 'items/choice.dart';
import 'items/input.dart';
import 'items/text.dart';
import 'scene.dart';

class Conversation {
  final String conversationId;
  final List<ItemType> conversations;
  final Scene scene;

  const Conversation({
    required this.conversationId,
    required this.conversations,
    required this.scene,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final jsonConv = json["conversations"] as List<dynamic>;
    return Conversation(
      conversationId: json["conversation_id"] as String,
      scene: Scene.fromJson(json["scene"] as Map<String, dynamic>),
      conversations: jsonConv.map((raw) {
        final item = raw as Map<String, dynamic>;
        final type = item["type"] as String?;
        return switch (type) {
          ChoiceItemType.type => ChoiceItemType.fromJson(item),
          TextItemType.type => TextItemType.fromJson(item),
          InputItemType.type => InputItemType.fromJson(item),
          _ => throw Exception("Can't handle $type in conversation"),
        };
      }).toList(),
    );
  }
}

