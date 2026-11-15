import '../data/scene.dart';
import '../l10n/localized_text.dart';
import 'rollback.dart';
import 'stage_state.dart';
import 'transcript.dart';

/// Playthrough state: active pointer, variables and transcript.
class SaveSlot {
  static const autoSlotId = 0;
  static const quickSlotId = -1;

  final int slotId;
  final String conversationKey;
  final int dialogIndex;
  final Map<String, dynamic> dataMap;
  final List<TranscriptEntry> history;
  final DateTime updatedAt;

  /// Return points of pending `CALL`s, innermost last.
  final List<CallFrame> callStack;

  /// `once` choices picked in this playthrough, as `<conversation_key>#<index>#<choice_index>`.
  final Set<String> chosen;

  /// Null in saves made before the stage was saved.
  final StageState? stage;

  /// The active scene, which a conversation without `scene` inherits. Null in older saves.
  final Scene? scene;

  /// Rollback frames and `random()` rolls, so rollback reaches back past the load. Null in older saves.
  final RollbackLog? rollback;

  /// Clues already seen on the Case Board. Null in older saves, where every found clue counts as seen.
  final Set<String>? viewedClues;

  /// Retries used by evidence questions waiting for a final answer, by `<conversation_key>#<index>`.
  final Map<String, int> evidenceTries;

  /// Display info for save/load menus, in every language.
  final LocalizedText? chapter;
  final LocalizedText? title;

  const SaveSlot({
    required this.slotId,
    required this.conversationKey,
    required this.dialogIndex,
    required this.dataMap,
    required this.history,
    required this.updatedAt,
    this.callStack = const [],
    this.chosen = const {},
    this.stage,
    this.scene,
    this.rollback,
    this.viewedClues,
    this.evidenceTries = const {},
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
        callStack: callStack,
        chosen: chosen,
        stage: stage,
        scene: scene,
        rollback: rollback,
        viewedClues: viewedClues,
        evidenceTries: evidenceTries,
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
      callStack: (json["call_stack"] as List<dynamic>? ?? const [])
          .map((e) => CallFrame.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      chosen: (json["chosen"] as List<dynamic>? ?? const []).map((e) => e.toString()).toSet(),
      stage: json["stage"] == null ? null : StageState.fromJson(Map<String, dynamic>.from(json["stage"] as Map)),
      scene: json["scene"] == null ? null : Scene.fromJson(Map<String, dynamic>.from(json["scene"] as Map)),
      rollback: json["rollback"] == null
          ? null
          : RollbackLog.fromJson(Map<String, dynamic>.from(json["rollback"] as Map)),
      viewedClues: (json["viewed_clues"] as List<dynamic>?)?.map((e) => e.toString()).toSet(),
      evidenceTries: evidenceTriesFromJson(json["evidence_tries"]),
      chapter: LocalizedText.fromJson(json["chapter"]),
      title: LocalizedText.fromJson(json["title"]),
    );
  }

  Map<String, dynamic> toJson() => {
        "slot_id": slotId,
        "conversation_key": conversationKey,
        "dialog_index": dialogIndex,
        "data_map": dataMap,
        "history": history.map((e) => e.toJson()).toList(),
        "updated_at": updatedAt.toIso8601String(),
        if (callStack.isNotEmpty) "call_stack": callStack.map((e) => e.toJson()).toList(),
        if (chosen.isNotEmpty) "chosen": chosen.toList(),
        if (stage != null) "stage": stage!.toJson(),
        if (scene != null) "scene": scene!.toJson(),
        if (rollback != null) "rollback": rollback!.toJson(),
        if (viewedClues != null) "viewed_clues": viewedClues!.toList(),
        if (evidenceTries.isNotEmpty) "evidence_tries": evidenceTries,
        if (chapter != null) "chapter": chapter!.toJson(),
        if (title != null) "title": title!.toJson(),
      };
}

/// Reads the `evidence_tries` map of a save or rollback frame.
Map<String, int> evidenceTriesFromJson(Object? json) =>
    {for (final MapEntry(:key, :value) in (json as Map? ?? const {}).entries) key.toString(): (value as num).toInt()};

/// Where a `RETURN` continues: item [dialogIndex] of [conversationKey].
class CallFrame {
  final String conversationKey;
  final int dialogIndex;

  const CallFrame(this.conversationKey, this.dialogIndex);

  factory CallFrame.fromJson(Map<String, dynamic> json) =>
      CallFrame(json["conversation_key"] as String, json["dialog_index"] as int);

  Map<String, dynamic> toJson() => {"conversation_key": conversationKey, "dialog_index": dialogIndex};
}
