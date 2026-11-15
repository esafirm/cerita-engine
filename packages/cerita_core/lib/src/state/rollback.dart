import 'dart:math';

import '../data/items/base.dart';
import '../data/items/choice.dart';
import '../data/items/input.dart';
import '../data/items/media.dart';
import '../data/items/narration.dart';
import '../data/items/text.dart';
import '../data/scene.dart';
import 'save_slot.dart';
import 'stage_state.dart';

/// Playthrough state right after [item] was delivered. See [RealFsseEngine.rollback].
class RollbackFrame {
  final ItemType item;
  final String conversationKey;
  final int dialogIndex;
  final Scene? scene;
  final Map<String, dynamic> dataMap;
  final int historyLength;
  final List<CallFrame> callStack;
  final Set<String> chosen;

  /// Retries used by pending evidence questions, see [SaveSlot.evidenceTries].
  final Map<String, int> evidenceTries;
  final StageState stage;
  final bool awaitingResult;
  final String? lastItemKey;
  final bool previouslySeen;

  /// Position in the [RollLog] when the item was delivered.
  final int roll;

  const RollbackFrame({
    required this.item,
    required this.conversationKey,
    required this.dialogIndex,
    required this.scene,
    required this.dataMap,
    required this.historyLength,
    required this.callStack,
    required this.chosen,
    this.evidenceTries = const {},
    required this.stage,
    required this.awaitingResult,
    required this.lastItemKey,
    required this.previouslySeen,
    required this.roll,
  });

  /// A line of a VN scene. Stage directions and waits are passed over, and chat / call threads
  /// move on by themselves.
  bool get isTarget =>
      scene?.mode == SceneMode.vn &&
      (item is TextItemType ||
          item is NarrationItemType ||
          item is MediaItemType ||
          item is ChoiceItemType ||
          item is InputItemType);

  factory RollbackFrame.fromJson(Map<String, dynamic> json) => RollbackFrame(
        item: _itemFromJson(json),
        conversationKey: json["conversation_key"] as String,
        dialogIndex: json["dialog_index"] as int,
        scene: json["scene"] == null ? null : Scene.fromJson(Map<String, dynamic>.from(json["scene"] as Map)),
        dataMap: Map<String, dynamic>.from(json["data_map"] as Map),
        historyLength: json["history_length"] as int,
        callStack: (json["call_stack"] as List<dynamic>? ?? const [])
            .map((e) => CallFrame.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        chosen: (json["chosen"] as List<dynamic>? ?? const []).map((e) => e.toString()).toSet(),
        evidenceTries: evidenceTriesFromJson(json["evidence_tries"]),
        stage: StageState.fromJson(Map<String, dynamic>.from(json["stage"] as Map)),
        awaitingResult: json["awaiting_result"] as bool? ?? false,
        lastItemKey: json["last_item_key"] as String?,
        previouslySeen: json["previously_seen"] as bool? ?? false,
        roll: json["roll"] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "item": item.toJson(),
        // The item JSON has every choice. These are the ones shown, with their runtime flags.
        if (item case ChoiceItemType(:final choices))
          "choices": [
            for (final choice in choices)
              {"index": choice.index, if (choice.locked) "locked": true, if (choice.chosen) "chosen": true},
          ],
        "conversation_key": conversationKey,
        "dialog_index": dialogIndex,
        if (scene != null) "scene": scene!.toJson(),
        "data_map": dataMap,
        "history_length": historyLength,
        if (callStack.isNotEmpty) "call_stack": callStack.map((e) => e.toJson()).toList(),
        if (chosen.isNotEmpty) "chosen": chosen.toList(),
        if (evidenceTries.isNotEmpty) "evidence_tries": evidenceTries,
        "stage": stage.toJson(),
        if (awaitingResult) "awaiting_result": true,
        if (lastItemKey != null) "last_item_key": lastItemKey,
        if (previouslySeen) "previously_seen": true,
        if (roll != 0) "roll": roll,
      };

  static ItemType _itemFromJson(Map<String, dynamic> json) {
    final item = ItemType.fromJson(Map<String, dynamic>.from(json["item"] as Map));
    final shown = json["choices"];
    if (item is! ChoiceItemType || shown is! List) return item;
    return item.withChoices([
      for (final raw in shown)
        if (item.choices.elementAtOrNull((raw as Map)["index"] as int) case final choice?)
          choice.copyWith(locked: raw["locked"] == true, chosen: raw["chosen"] == true),
    ]);
  }
}

/// The rollback frames and `random()` rolls kept in a save, so rollback still works after loading it.
class RollbackLog {
  /// Rollback targets, oldest first, then the state the save was made in.
  final List<RollbackFrame> frames;

  /// `random()` results from [rollBase] on, see [RollLog].
  final List<Roll> rolls;
  final int rollBase;

  const RollbackLog({required this.frames, this.rolls = const [], this.rollBase = 0});

  factory RollbackLog.fromJson(Map<String, dynamic> json) => RollbackLog(
        frames: (json["frames"] as List<dynamic>)
            .map((e) => RollbackFrame.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        rolls: (json["rolls"] as List<dynamic>? ?? const []).map((e) {
          final pair = e as List<dynamic>;
          return (max: pair[0] as int, value: pair[1] as int);
        }).toList(),
        rollBase: json["roll_base"] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "frames": frames.map((e) => e.toJson()).toList(),
        if (rolls.isNotEmpty) "rolls": [for (final roll in rolls) [roll.max, roll.value]],
        if (rollBase != 0) "roll_base": rollBase,
      };
}

/// One `nextInt(max)` result.
typedef Roll = ({int max, int value});

/// Records the random numbers of a playthrough. After a rollback moves [position] back, the same
/// numbers come out again, so going back and forth doesn't change a `random()` result. A call with
/// another range than the recorded one drops the recorded rest and rolls fresh numbers.
class RollLog implements Random {
  final Random _source;
  final List<Roll> _rolls = [];

  /// Absolute position of `_rolls[0]`. Rolls older than the oldest rollback frame are dropped.
  int _base = 0;

  /// Absolute position of the next roll.
  int position = 0;

  RollLog(this._source);

  int get base => _base;

  List<Roll> get rolls => List.unmodifiable(_rolls);

  @override
  int nextInt(int max) {
    final index = position - _base;
    if (index < _rolls.length) {
      final roll = _rolls[index];
      if (roll.max == max) {
        position++;
        return roll.value;
      }
      _rolls.removeRange(index, _rolls.length);
    }
    final value = _source.nextInt(max);
    _rolls.add((max: max, value: value));
    position++;
    return value;
  }

  @override
  double nextDouble() => _source.nextDouble();

  @override
  bool nextBool() => _source.nextBool();

  /// Drops the rolls before [position], which no rollback can reach any more.
  void dropBefore(int position) {
    final count = (position - _base).clamp(0, _rolls.length);
    _rolls.removeRange(0, count);
    _base += count;
  }

  /// Rolls from [position] on, for a save.
  List<Roll> rollsFrom(int position) => _rolls.sublist((position - _base).clamp(0, _rolls.length));

  void restore({List<Roll> rolls = const [], int base = 0, int? position}) {
    _rolls
      ..clear()
      ..addAll(rolls);
    _base = base;
    this.position = position ?? base;
  }
}
