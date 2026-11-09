/// Global meta-state shared across playthroughs: gallery, endings, checkpoints and read lines.
class GlobalMetaState {
  final Set<String> unlockedMediaIds;
  final Set<String> unlockedEndingIds;

  /// Checkpoint snapshots keyed by conversation key.
  final Map<String, Checkpoint> unlockedCheckpoints;

  /// `<conversation_key>#<index>` of every line ever delivered. Powers VN "Skip".
  final Set<String> seenItems;

  GlobalMetaState({
    Set<String>? unlockedMediaIds,
    Set<String>? unlockedEndingIds,
    Map<String, Checkpoint>? unlockedCheckpoints,
    Set<String>? seenItems,
  })  : unlockedMediaIds = unlockedMediaIds ?? {},
        unlockedEndingIds = unlockedEndingIds ?? {},
        unlockedCheckpoints = unlockedCheckpoints ?? {},
        seenItems = seenItems ?? {};

  factory GlobalMetaState.fromJson(Map<String, dynamic> json) {
    Set<String> stringSet(String key) => (json[key] as List<dynamic>? ?? const []).map((e) => e.toString()).toSet();
    final checkpoints = Map<String, dynamic>.from(json["unlocked_checkpoints"] as Map? ?? const {});
    return GlobalMetaState(
      unlockedMediaIds: stringSet("unlocked_media_ids"),
      unlockedEndingIds: stringSet("unlocked_ending_ids"),
      seenItems: stringSet("seen_items"),
      unlockedCheckpoints: checkpoints.map(
        (key, value) => MapEntry(key, Checkpoint.fromJson(Map<String, dynamic>.from(value as Map))),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        "unlocked_media_ids": unlockedMediaIds.toList(),
        "unlocked_ending_ids": unlockedEndingIds.toList(),
        "seen_items": seenItems.toList(),
        "unlocked_checkpoints": unlockedCheckpoints.map((key, value) => MapEntry(key, value.toJson())),
      };
}

/// Variable snapshot taken when entering a conversation marked `"checkpoint": true`.
class Checkpoint {
  final String conversationKey;
  final String? chapter;
  final String? title;
  final int? day;
  final Map<String, dynamic> dataMap;
  final DateTime unlockedAt;

  const Checkpoint({
    required this.conversationKey,
    required this.dataMap,
    required this.unlockedAt,
    this.chapter,
    this.title,
    this.day,
  });

  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    return Checkpoint(
      conversationKey: json["conversation_key"] as String,
      chapter: json["chapter"] as String?,
      title: json["title"] as String?,
      day: json["day"] as int?,
      dataMap: Map<String, dynamic>.from(json["data_map"] as Map),
      unlockedAt: DateTime.parse(json["unlocked_at"] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        "conversation_key": conversationKey,
        if (chapter != null) "chapter": chapter,
        if (title != null) "title": title,
        if (day != null) "day": day,
        "data_map": dataMap,
        "unlocked_at": unlockedAt.toIso8601String(),
      };
}
