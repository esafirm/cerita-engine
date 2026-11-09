import 'transcript.dart';

/// Playthrough state: active pointer, variables and transcript.
class SaveSlot {
  static const autoSlotId = 0;

  final int slotId;
  final String conversationKey;
  final int dialogIndex;
  final Map<String, dynamic> dataMap;
  final List<TranscriptEntry> history;
  final DateTime updatedAt;

  /// Display info for save/load menus.
  final String? chapter;
  final String? title;

  const SaveSlot({
    required this.slotId,
    required this.conversationKey,
    required this.dialogIndex,
    required this.dataMap,
    required this.history,
    required this.updatedAt,
    this.chapter,
    this.title,
  });

  SaveSlot copyWith({int? slotId}) => SaveSlot(
        slotId: slotId ?? this.slotId,
        conversationKey: conversationKey,
        dialogIndex: dialogIndex,
        dataMap: dataMap,
        history: history,
        updatedAt: DateTime.now(),
        chapter: chapter,
        title: title,
      );

  factory SaveSlot.fromJson(Map<String, dynamic> json) {
    return SaveSlot(
      slotId: json["slot_id"] as int,
      conversationKey: json["conversation_key"] as String,
      dialogIndex: json["dialog_index"] as int,
      dataMap: Map<String, dynamic>.from(json["data_map"] as Map),
      history: (json["history"] as List<dynamic>)
          .map((e) => TranscriptEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      updatedAt: DateTime.parse(json["updated_at"] as String),
      chapter: json["chapter"] as String?,
      title: json["title"] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        "slot_id": slotId,
        "conversation_key": conversationKey,
        "dialog_index": dialogIndex,
        "data_map": dataMap,
        "history": history.map((e) => e.toJson()).toList(),
        "updated_at": updatedAt.toIso8601String(),
        if (chapter != null) "chapter": chapter,
        if (title != null) "title": title,
      };
}
