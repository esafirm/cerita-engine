import 'items/base.dart';
import 'scene.dart';

class Conversation {
  /// Key of the entry-point conversation (`index.json`).
  static const indexKey = "index";

  /// Key used to load this conversation: [indexKey] or the `<id>` of `cvn_<id>.json`.
  final String key;
  final String conversationId;
  final String? chapter;
  final String? title;
  final bool checkpoint;
  final Scene scene;
  final List<ItemType> conversations;

  const Conversation({
    required this.key,
    required this.conversationId,
    required this.conversations,
    this.scene = const Scene(),
    this.chapter,
    this.title,
    this.checkpoint = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json, {required String key}) {
    final jsonConv = json["conversations"] as List<dynamic>;
    return Conversation(
      key: key,
      conversationId: json["conversation_id"] as String,
      chapter: json["chapter"] as String?,
      title: json["title"] as String?,
      checkpoint: json["checkpoint"] as bool? ?? false,
      scene: Scene.fromJson(json["scene"] as Map<String, dynamic>?),
      conversations: jsonConv.map((raw) => ItemType.fromJson(Map<String, dynamic>.from(raw as Map))).toList(),
    );
  }
}
