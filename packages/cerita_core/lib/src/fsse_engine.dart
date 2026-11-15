import 'dart:convert';
import 'dart:developer' as developer;

import 'data/channel.dart';
import 'data/conversation.dart';
import 'data/item_result.dart';
import 'data/items/base.dart';
import 'data/items/branch.dart';
import 'data/items/choice.dart';
import 'data/items/ending.dart';
import 'data/items/flow.dart';
import 'data/items/input.dart';
import 'data/items/media.dart';
import 'data/items/narration.dart';
import 'data/items/stage.dart';
import 'data/items/text.dart';
import 'data/items/profile_info.dart';
import 'data/profile.dart';
import 'data/effect.dart';
import 'data/scene.dart';
import 'loader.dart';
import 'state/meta_state.dart';
import 'state/rollback.dart';
import 'state/save_slot.dart';
import 'state/stage_state.dart';
import 'state/story_state.dart';
import 'state/story_storage.dart';
import 'state/transcript.dart';
import 'utils/condition_evaluator.dart';

export 'loader.dart';

abstract class FsseEngine {
  /// Advance to the next eligible item, optionally applying [prevResult]
  /// from an INPUT or CHOICE item.
  Future<ItemType> next({ItemResult? prevResult});

  /// Return the current active item without advancing the index.
  Future<ItemType> get();

  /// Read the current playthrough's variable and stats store.
  Map<String, dynamic> getDataMap();

  /// Resolve the character Profile for a given [itemType].
  Profile? getProfile(ItemType itemType);
}

abstract mixin class EngineListener {
  /// Called when a new conversation starts with its scene (mode, background, music...).
  void onNewScene(Scene scene);

  void onConversationStarted(Conversation conversation) {}

  void onMediaUnlocked(String unlockId) {}

  void onEndingUnlocked(EndingItemType ending) {}

  void onCheckpointUnlocked(Checkpoint checkpoint) {}
}

/// Thrown by [FsseEngine.next] when a conversation runs out of items without a target.
class EndOfStoryException implements Exception {
  final String conversationKey;

  const EndOfStoryException(this.conversationKey);

  @override
  String toString() => "EndOfStoryException: no more items in '$conversationKey'";
}

/* Impl */
/* ------------------------------------------ */

class RealFsseEngine extends FsseEngine {
  static const _tag = "FSSE";
  static const _maxJumps = 64;
  static const _maxRollback = 100;

  final EngineLoader loader;
  final StoryStorage? storage;
  final ConditionEvaluator evaluator;
  EngineListener? listener;

  RealFsseEngine(this.loader, {this.listener, this.storage, this.evaluator = const ConditionEvaluator()});

  RealFsseEngine.withListener(this.loader, this.listener)
      : storage = null,
        evaluator = const ConditionEvaluator();

  /// `random()` results, replayed after a rollback.
  late final RollLog _rolls = RollLog(evaluator.random);

  /// [evaluator] drawing its random numbers from [_rolls].
  late final ConditionEvaluator _evaluator = ConditionEvaluator(_rolls);

  late ProfileData profileData;
  List<Channel> channels = const [];
  GlobalMetaState meta = GlobalMetaState();

  Conversation? currentConversation;
  int dialogIndex = 0;

  /// Scene of [currentConversation], or the one it continues when it has no `scene`.
  Scene? _scene;

  /// Playthrough variables. Expressions see them through [state], together with `persistent.*` and the
  /// read-only `meta.*` memory.
  final Map<String, dynamic> dataMap = {};
  late final StoryState state = StoryState(dataMap, () => meta);

  /// The VN stage. Saved with the playthrough.
  StageState stage = StageState();

  final List<TranscriptEntry> _history = [];
  final List<CallFrame> _callStack = [];

  /// `once` choices picked in this playthrough.
  final Set<String> _chosen = {};

  /// State after each recently delivered item, oldest first. The last one is the current state.
  final List<RollbackFrame> _frames = [];

  /// The latest loaded copy of every conversation a frame or the pointer is in, by key.
  final Map<String, Conversation> _conversations = {};

  bool _replay = false;

  /// The chapter being replayed. Entering a conversation of another chapter ends the replay.
  String? _replayChapter;

  /// Whether the last item returned by [next] had been delivered in an earlier playthrough.
  bool lastItemPreviouslySeen = false;

  /// True while the last returned item is a CHOICE / INPUT waiting for its [ItemResult].
  bool _awaitingResult = false;

  /// `<conversation_key>#<index>` of the last returned item.
  String? _lastItemKey;

  bool _metaDirty = false;
  bool _started = false;

  List<TranscriptEntry> get history => List.unmodifiable(_history);

  Scene? get currentScene => _scene;

  /// True while replaying a single chapter, see [start].
  bool get replaying => _replay;

  /// Starts a playthrough: fresh from `index.json`, from a [save] slot, or from a [checkpoint].
  /// With [replay], only the [checkpoint]'s chapter is played: entering a conversation of another
  /// chapter throws [EndOfStoryException].
  Future<void> start({SaveSlot? save, Checkpoint? checkpoint, bool replay = false}) async {
    final package = await loader.initialLoad();
    profileData = package.profiles;
    channels = package.channels;
    meta = await storage?.loadMeta() ?? meta;

    dataMap.clear();
    _history.clear();
    _callStack.clear();
    _chosen.clear();
    _frames.clear();
    _conversations.clear();
    _rolls.restore();
    _replay = false;
    _replayChapter = null;
    stage = StageState();
    currentConversation = null;
    _scene = null;
    _awaitingResult = false;
    _started = true;

    if (save != null) {
      dataMap.addAll(save.dataMap);
      _history.addAll(save.history);
      _callStack.addAll(save.callStack);
      _chosen.addAll(save.chosen);
      _scene = save.scene;
      final conversation = await loader.loadConversation(save.conversationKey);
      await _enterConversation(conversation, index: save.dialogIndex);
      // A conversation without a scene kept the saved one, but the listener has not seen it yet.
      if (!conversation.hasScene && _scene != null) listener?.onNewScene(_scene!);
      if (save.stage != null) stage = _copyStage(save.stage!);
      _hearMusic();
      final log = save.rollback;
      if (log != null && log.frames.isNotEmpty) {
        await _restoreFrames(log);
      } else {
        // An older save: the loaded line is the first rollback target.
        final last = _history.lastWhere((entry) => !entry.isPlayer && entry.conversationKey == conversation.key,
            orElse: () => TranscriptEntry(conversationKey: conversation.key, mode: SceneMode.vn));
        if (last.itemType case final item?) _pushFrame(item);
      }
    } else if (checkpoint != null) {
      dataMap.addAll(checkpoint.dataMap);
      final conversation = await loader.loadConversation(checkpoint.conversationKey);
      if (replay) {
        _replay = true;
        _replayChapter = conversation.chapter;
      }
      await _enterConversation(conversation);
    } else {
      await _enterConversation(package.conversation);
    }
    developer.log("Package loaded", name: _tag);
  }

  @override
  Future<ItemType> next({ItemResult? prevResult}) async {
    developer.log("Request next with index: $dialogIndex", name: _tag);

    await _ensureStarted();
    await _handleResult(prevResult);

    final item = await _resolveCurrentItem();
    final executed = await _execute(item);
    _pushFrame(executed);
    await _flushMeta();
    return executed;
  }

  /// Continues the story at [target] (`conv`, `#label` or `conv#label`), keeping the variables. For the
  /// developer panel: the next [next] returns the item there.
  Future<void> jumpTo(String target) async {
    await _ensureStarted();
    _awaitingResult = false;
    await _jump(target);
  }

  /// Reads the current conversation again and returns the current item as it is written now, for a
  /// developer reload. Its effects are not applied again, and its transcript line is replaced. The
  /// pointer stays, so if items were added or removed above it, this may be another item. Null when
  /// there is no current item.
  Future<ItemType?> reloadCurrent() async {
    final current = currentConversation;
    if (current == null) return null;
    final conversation = await loader.loadConversation(current.key);
    currentConversation = conversation;
    _conversations[conversation.key] = conversation;
    final index = dialogIndex - 1;
    if (index < 0 || index >= conversation.conversations.length) return null;

    dialogIndex = index;
    final item = _prepare(conversation.conversations[index]);
    dialogIndex = index + 1;
    final last = _history.lastOrNull;
    if (item is! StageItemType && last != null && !last.isPlayer && last.conversationKey == conversation.key) {
      _history[_history.length - 1] = TranscriptEntry(
        conversationKey: last.conversationKey,
        mode: last.mode,
        channelId: last.channelId,
        item: item.toJson(),
      );
    }
    _awaitingResult = item is ChoiceItemType || item is InputItemType;
    return item;
  }

  /// Sets [variable], a playthrough or `persistent.*` one, from the developer panel.
  Future<void> setVariable(String variable, dynamic value) async {
    state[variable] = value;
    await _flushMeta();
  }

  /// Whether [rollback] has a line to go back to. With [historyIndex], whether the line at that
  /// transcript index can be rolled back to.
  bool canRollback({int? historyIndex}) => _rollbackTarget(historyIndex) != null;

  /// Restores the state right after the previous line was delivered, or after the line at transcript
  /// [historyIndex], and returns that line. Null if there is none. The meta-state is not rolled back.
  ItemType? rollback({int? historyIndex}) {
    final index = _rollbackTarget(historyIndex);
    if (index == null) return null;
    final frame = _frames[index];
    _frames.removeRange(index + 1, _frames.length);

    final previousScene = _scene;
    final previousConversation = currentConversation;
    _restoreFrame(frame);

    if (!_sameScene(previousScene, _scene) && _scene != null) listener?.onNewScene(_scene!);
    if (previousConversation?.key != currentConversation!.key) listener?.onConversationStarted(currentConversation!);
    return frame.item;
  }

  void _restoreFrame(RollbackFrame frame) {
    currentConversation = _conversations[frame.conversationKey];
    dialogIndex = frame.dialogIndex;
    _scene = frame.scene;
    dataMap
      ..clear()
      ..addAll(frame.dataMap);
    _history.removeRange(frame.historyLength, _history.length);
    _callStack
      ..clear()
      ..addAll(frame.callStack);
    _chosen
      ..clear()
      ..addAll(frame.chosen);
    stage = _copyStage(frame.stage);
    _awaitingResult = frame.awaitingResult;
    _lastItemKey = frame.lastItemKey;
    lastItemPreviouslySeen = frame.previouslySeen;
    _rolls.position = frame.roll;
  }

  static bool _sameScene(Scene? a, Scene? b) =>
      identical(a, b) || (a != null && b != null && jsonEncode(a.toJson()) == jsonEncode(b.toJson()));

  /// Index in [_frames] of the newest line before the current one (or at [historyIndex]).
  int? _rollbackTarget(int? historyIndex) {
    for (var i = _frames.length - 2; i >= 0; i--) {
      final frame = _frames[i];
      if (frame.isTarget && (historyIndex == null || frame.historyLength - 1 == historyIndex)) return i;
    }
    return null;
  }

  void _pushFrame(ItemType item) {
    final conversation = currentConversation!;
    _conversations[conversation.key] = conversation;
    _frames.add(RollbackFrame(
      item: item,
      conversationKey: conversation.key,
      dialogIndex: dialogIndex,
      scene: _scene,
      dataMap: Map.of(dataMap),
      historyLength: _history.length,
      callStack: _callStack.toList(),
      chosen: _chosen.toSet(),
      stage: _copyStage(stage),
      awaitingResult: _awaitingResult,
      lastItemKey: _lastItemKey,
      previouslySeen: lastItemPreviouslySeen,
      roll: _rolls.position,
    ));
    if (_frames.length > _maxRollback) {
      _frames.removeAt(0);
      _rolls.dropBefore(_frames.first.roll);
    }
  }

  /// The rollback frames for a save: the rollback targets, then the state the save is made in. A pending
  /// CHOICE / INPUT is asked again on restore, so its frame is left out. Null when there are none.
  RollbackLog? _rollbackLog() {
    final frames = _frames.toList();
    if (_awaitingResult && frames.isNotEmpty) frames.removeLast();
    if (frames.isEmpty) return null;
    final kept = [
      for (final (index, frame) in frames.indexed)
        if (frame.isTarget || index == frames.length - 1) frame,
    ];
    final base = kept.first.roll;
    return RollbackLog(frames: kept, rolls: _rolls.rollsFrom(base), rollBase: base);
  }

  /// Puts back the rollback frames of a save. Its last frame is the state the save was made in.
  Future<void> _restoreFrames(RollbackLog log) async {
    for (final key in {for (final frame in log.frames) frame.conversationKey}) {
      _conversations[key] ??= await loader.loadConversation(key);
    }
    _frames.addAll(log.frames);
    _rolls.restore(rolls: log.rolls, base: log.rollBase, position: log.frames.last.roll);
  }

  @override
  Future<ItemType> get() async {
    developer.log("Request get with index: $dialogIndex", name: _tag);
    await _ensureStarted();
    final item = _prepare(await _resolveCurrentItem());
    await _flushMeta();
    return item;
  }

  @override
  Map<String, dynamic> getDataMap() => dataMap;

  @override
  Profile? getProfile(ItemType itemType) {
    final info = itemType.getProfileInfo();
    return info == null ? null : getProfileById(info.id);
  }

  Profile? getProfileById(String id) {
    if (id == ProfileInfo.playerId) {
      return Profile(id: ProfileInfo.playerId, name: dataMap["NAME"]?.toString() ?? "You");
    }
    return profileData.byId(id);
  }

  Channel? getChannel(String? id) => channels.where((channel) => channel.id == id).firstOrNull;

  bool evaluate(String? condition) => _evaluator.evaluate(condition, state);

  /// Current playthrough state. A pending CHOICE / INPUT is rewound so it is asked again on restore.
  SaveSlot snapshot({int slotId = SaveSlot.autoSlotId}) {
    final conversation = currentConversation!;
    var index = dialogIndex;
    var history = _history.toList();
    if (_awaitingResult) {
      index -= 1;
      if (history.isNotEmpty && !history.last.isPlayer) history.removeLast();
    }
    return SaveSlot(
      slotId: slotId,
      conversationKey: conversation.key,
      dialogIndex: index,
      dataMap: Map.of(dataMap),
      history: history,
      updatedAt: DateTime.now(),
      callStack: _callStack.toList(),
      chosen: _chosen.toSet(),
      stage: _copyStage(stage),
      scene: _scene,
      chapter: conversation.chapter,
      title: conversation.title,
      rollback: _rollbackLog(),
    );
  }

  Future<void> saveTo(int slotId) async {
    final storage = this.storage;
    if (storage == null) return;
    await storage.saveSlot(snapshot(slotId: slotId));
    await storage.saveMeta(meta);
  }

  Future<void> _ensureStarted() async {
    if (!_started) await start();
  }

  StageState _copyStage(StageState stage) => StageState.fromJson(stage.toJson());

  /// Records the stage music for the music room.
  void _hearMusic() {
    final music = stage.music;
    if (music != null && meta.heardMusic.add(music)) _metaDirty = true;
  }

  void _applyEffects(List<Effect> effects) {
    for (final effect in effects) {
      effect.apply(state, _evaluator);
    }
  }

  Future<void> _flushMeta() async {
    if (!_metaDirty && !state.persistentDirty) return;
    _metaDirty = false;
    state.persistentDirty = false;
    await storage?.saveMeta(meta);
  }

  /// Skips items whose condition fails or that have nothing to pick, and follows
  /// BRANCH / JUMP / CALL / RETURN / SET.
  Future<ItemType> _resolveCurrentItem() async {
    for (var jumps = 0; jumps < _maxJumps;) {
      final conversation = currentConversation;
      if (conversation == null) {
        throw Exception("Empty conversation. Are you already load the assets?");
      }
      if (dialogIndex >= conversation.conversations.length) {
        if (_callStack.isEmpty) throw EndOfStoryException(conversation.key);
        await _return();
        jumps++;
        continue;
      }

      final item = conversation.conversations[dialogIndex];
      if (!evaluate(item.condition)) {
        dialogIndex += 1;
        continue;
      }

      switch (item) {
        case BranchItemType():
          final target =
              item.branches.where((branch) => evaluate(branch.condition)).firstOrNull?.target ?? item.fallbackTarget;
          if (target == null) {
            dialogIndex += 1;
          } else {
            await _jump(target);
            jumps++;
          }
          continue;
        case FlowItemType():
          _applyEffects(item.effects);
          dialogIndex += 1;
          switch (item) {
            case JumpItemType(:final target):
              await _jump(target);
              jumps++;
            case CallItemType(:final target):
              _callStack.add(CallFrame(conversation.key, dialogIndex));
              await _jump(target);
              jumps++;
            case ReturnItemType():
              if (_callStack.isEmpty) throw EndOfStoryException(conversation.key);
              await _return();
              jumps++;
          }
          continue;
        case ChoiceItemType() when (_prepare(item) as ChoiceItemType).availableChoices.isEmpty:
          dialogIndex += 1;
          continue;
      }
      return item;
    }
    throw Exception("Too many jumps. Is there a loop in the story?");
  }

  /// Interpolates [item] and, for a CHOICE, hides picked `once` choices and locked memory-gated ones, and flags
  /// locked / chosen ones. Must be called while [dialogIndex] points at [item].
  ItemType _prepare(ItemType item) {
    final cloned = item.cloneWithData(state);
    if (cloned is! ChoiceItemType) return cloned;
    final itemKey = "${currentConversation!.key}#$dialogIndex";
    final choices = <Choice>[];
    for (final choice in cloned.choices) {
      final key = "$itemKey#${choice.index}";
      if (choice.once && _chosen.contains(key)) continue;
      final locked = !evaluate(choice.condition);
      // A past-run reward isn't shown as a lock, so a first run looks as it would without memory.
      if (locked && choice.readsMemory) continue;
      choices.add(choice.copyWith(locked: locked, chosen: meta.chosenChoices.contains(key)));
    }
    return cloned.withChoices(choices);
  }

  Future<ItemType> _execute(ItemType item) async {
    _applyEffects(item.effects);
    final prepared = _prepare(item);
    final conversation = currentConversation!;
    _lastItemKey = "${conversation.key}#$dialogIndex";

    if (prepared is StageItemType) {
      for (final action in prepared.actions) {
        if (stage.startsPage(action)) stage.pageStart = _history.length;
        stage.apply(action);
      }
      _hearMusic();
    } else {
      _placeSpeaker(prepared);
      _history.add(TranscriptEntry(
        conversationKey: conversation.key,
        mode: _scene!.mode,
        channelId: _scene!.channelId,
        item: prepared.toJson(),
      ));
    }
    lastItemPreviouslySeen = !meta.seenItems.add(_lastItemKey!);
    _awaitingResult = prepared is ChoiceItemType || prepared is InputItemType;
    dialogIndex += 1;

    await _registerUnlocks(prepared);
    return prepared;
  }

  /// Puts the speaking character on stage: at the item's `position`, its current slot, or center.
  void _placeSpeaker(ItemType item) {
    final info = item.getProfileInfo();
    if (info == null || info.isPlayer || item is NarrationItemType) {
      stage.speakerId = null;
      return;
    }
    stage.place(info, item is TextItemType ? item.position : null);
    stage.speakerId = info.id;
  }

  Future<void> _registerUnlocks(ItemType item) async {
    if (item is MediaItemType && item.unlockId != null && meta.unlockedMediaIds.add(item.unlockId!)) {
      await storage?.saveMeta(meta);
      listener?.onMediaUnlocked(item.unlockId!);
    }
    if (item is EndingItemType) {
      meta.unlockedEndingIds.add(item.endingId);
      await storage?.saveMeta(meta);
      listener?.onEndingUnlocked(item);
    }
  }

  Future<void> _handleResult(ItemResult? itemResult) async {
    if (itemResult == null) return;
    _awaitingResult = false;

    if (itemResult.variable != null) {
      if (itemResult.value == null) {
        throw Exception("Variable exits but value is null");
      }
      state[itemResult.variable!] = itemResult.value;
    }

    final choiceIndex = itemResult.choiceIndex;
    if (choiceIndex != null && _lastItemKey != null) {
      final key = "$_lastItemKey#$choiceIndex";
      _chosen.add(key);
      if (meta.chosenChoices.add(key)) _metaDirty = true;
    }

    _applyEffects(itemResult.effects);

    final scene = _scene;
    if (itemResult.text != null && scene != null) {
      _history.add(TranscriptEntry(
        conversationKey: currentConversation!.key,
        mode: scene.mode,
        channelId: scene.channelId,
        playerText: itemResult.text,
      ));
    }

    final target = itemResult.target;
    if (target != null) await _jump(target);
  }

  /// Continues at [target]: `conv`, `#label` (current conversation) or `conv#label`.
  Future<void> _jump(String target) async {
    final hash = target.indexOf("#");
    final key = hash < 0 ? target : target.substring(0, hash);
    final label = hash < 0 ? null : target.substring(hash + 1);

    final conversation = key.isEmpty ? currentConversation! : await loader.loadConversation(key);
    var index = 0;
    if (label != null) {
      index = conversation.conversations.indexWhere((item) => item.id == label);
      if (index < 0) throw Exception("No item with id '$label' in '${conversation.key}' (target '$target')");
    }

    if (key.isEmpty) {
      dialogIndex = index;
    } else {
      await _enterConversation(conversation, index: index);
    }
  }

  Future<void> _return() async {
    final frame = _callStack.removeLast();
    if (frame.conversationKey == currentConversation?.key) {
      dialogIndex = frame.dialogIndex;
    } else {
      await _enterConversation(await loader.loadConversation(frame.conversationKey), index: frame.dialogIndex);
    }
  }

  /// Called after initial load and after a new conversation is loaded.
  Future<void> _enterConversation(Conversation conversation, {int index = 0}) async {
    final chapter = _replayChapter;
    if (chapter != null && conversation.chapter != null && conversation.chapter != chapter) {
      throw EndOfStoryException(conversation.key);
    }
    final previous = _scene;
    currentConversation = conversation;
    _conversations[conversation.key] = conversation;
    dialogIndex = index;
    if (conversation.hasScene || previous == null) {
      _scene = conversation.scene;
      stage.enterScene(conversation.scene, previous: previous);
      stage.pageStart = _history.length;
      _hearMusic();
      listener?.onNewScene(conversation.scene);
    }
    listener?.onConversationStarted(conversation);

    if (conversation.checkpoint && index == 0) {
      final checkpoint = Checkpoint(
        conversationKey: conversation.key,
        chapter: conversation.chapter,
        title: conversation.title,
        day: _scene!.day,
        dataMap: Map.of(dataMap),
        unlockedAt: DateTime.now(),
      );
      meta.unlockedCheckpoints[conversation.key] = checkpoint;
      await storage?.saveMeta(meta);
      listener?.onCheckpointUnlocked(checkpoint);
    }
  }
}
