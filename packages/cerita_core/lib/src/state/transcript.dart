import 'package:cerita_core/src/data/items/base.dart';
import 'package:cerita_core/src/data/scene.dart';

/// One delivered line in the playthrough: an engine item or a player reply.
class TranscriptEntry {
  final String conversationKey;
  final SceneMode mode;
  final String? channelId;

  /// Interpolated item JSON. Null for player replies.
  final Map<String, dynamic>? item;

  /// The player's outgoing text (chosen option or typed input).
  final String? playerText;

  const TranscriptEntry({
    required this.conversationKey,
    required this.mode,
    this.channelId,
    this.item,
    this.playerText,
  });

  bool get isPlayer => item == null;

  ItemType? get itemType => item == null ? null : ItemType.fromJson(item!);

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) {
    return TranscriptEntry(
      conversationKey: json["conversation_key"] as String,
      mode: SceneMode.fromKey(json["mode"] as String?),
      channelId: json["channel_id"] as String?,
      item: json["item"] == null ? null : Map<String, dynamic>.from(json["item"] as Map),
      playerText: json["player_text"] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        "conversation_key": conversationKey,
        "mode": mode.key,
        if (channelId != null) "channel_id": channelId,
        if (item != null) "item": item,
        if (playerText != null) "player_text": playerText,
      };
}
