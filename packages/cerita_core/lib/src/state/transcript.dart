import 'package:cerita_core/src/data/items/base.dart';
import 'package:cerita_core/src/data/scene.dart';
import 'package:cerita_core/src/l10n/localized_text.dart';

/// One delivered line in the playthrough: an engine item or a player reply.
/// Both keep every language, so history can be shown in whichever one is active.
class TranscriptEntry {
  final String conversationKey;
  final SceneMode mode;
  final String? channelId;

  /// Interpolated item JSON, localized fields still per locale. Null for player replies.
  final Map<String, dynamic>? item;

  /// The player's outgoing text: the chosen option in every language, or the typed input.
  final LocalizedText? playerText;

  const TranscriptEntry({
    required this.conversationKey,
    required this.mode,
    this.channelId,
    this.item,
    this.playerText,
  });

  bool get isPlayer => item == null;

  /// The item in the source language. Use [itemIn] for anything the player sees.
  ItemType? get itemType => item == null ? null : ItemType.fromJson(item!);

  ItemType? itemIn(Localizer localizer) => item == null ? null : ItemType.fromJson(item!, localizer: localizer);

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) {
    return TranscriptEntry(
      conversationKey: json["conversation_key"] as String,
      mode: SceneMode.fromKey(json["mode"] as String?),
      channelId: json["channel_id"] as String?,
      item: json["item"] == null ? null : Map<String, dynamic>.from(json["item"] as Map),
      playerText: LocalizedText.fromJson(json["player_text"]),
    );
  }

  Map<String, dynamic> toJson() => {
        "conversation_key": conversationKey,
        "mode": mode.key,
        if (channelId != null) "channel_id": channelId,
        if (item != null) "item": item,
        if (playerText != null) "player_text": playerText!.toJson(),
      };
}
