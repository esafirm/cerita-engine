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

  final EngineLoader loader;
  final StoryStorage? storage;
  final ConditionEvaluator evaluator;
  EngineListener? listener;

  RealFsseEngine(this.loader, {this.listener, this.storage, this.evaluator = const ConditionEvaluator()});

  RealFsseEngine.withListener(this.loader, this.listener)
      : storage = null,
        evaluator = const ConditionEvaluator();

  late ProfileData profileData;
  List<Channel> channels = const [];
  GlobalMetaState meta = GlobalMetaState();

  Conversation? currentConversation;
  int dialogIndex = 0;

  /// Scene of [currentConversation], or the one it continues when it has no `scene`.
  Scene? _scene;

  /// Playthrough variables. Expressions see them through [state], together with `persistent.*`.
  final Map<String, dynamic> dataMap = {};
  late final StoryState state = StoryState(dataMap, () => meta.persistent);

  /// The VN stage. Saved with the playthrough.
  StageState stage = StageState();

  final List<TranscriptEntry> _history = [];
  final List<CallFrame> _callStack = [];

  /// `once` choices picked in this playthrough.
  final Set<String> _chosen = {};

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

  /// Starts a playthrough: fresh from `index.json`, from a [save] slot, or from a [checkpoint].
  Future<void> start({SaveSlot? save, Checkpoint? checkpoint}) async {
    final package = await loader.initialLoad();
    profileData = package.profiles;
    channels = package.channels;
    meta = await storage?.loadMeta() ?? meta;

    dataMap.clear();
    _history.clear();
    _callStack.clear();
    _chosen.clear();
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
    } else if (checkpoint != null) {
      dataMap.addAll(checkpoint.dataMap);
      await _enterConversation(await loader.loadConversation(checkpoint.conversationKey));
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
    await _flushMeta();
    return executed;
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

  bool evaluate(String? condition) => evaluator.evaluate(condition, state);

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

  void _applyEffects(List<Effect> effects) {
    for (final effect in effects) {
      effect.apply(state, evaluator);
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

  /// Interpolates [item] and, for a CHOICE, hides picked `once` choices and flags locked / chosen ones.
  /// Must be called while [dialogIndex] points at [item].
  ItemType _prepare(ItemType item) {
    final cloned = item.cloneWithData(state);
    if (cloned is! ChoiceItemType) return cloned;
    final itemKey = "${currentConversation!.key}#$dialogIndex";
    return cloned.withChoices([
      for (final choice in cloned.choices)
        if (!(choice.once && _chosen.contains("$itemKey#${choice.index}")))
          choice.copyWith(
            locked: !evaluate(choice.condition),
            chosen: meta.chosenChoices.contains("$itemKey#${choice.index}"),
          ),
    ]);
  }

  Future<ItemType> _execute(ItemType item) async {
    _applyEffects(item.effects);
    final prepared = _prepare(item);
    final conversation = currentConversation!;
    _lastItemKey = "${conversation.key}#$dialogIndex";

    if (prepared is StageItemType) {
      prepared.actions.forEach(stage.apply);
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
    final previous = _scene;
    currentConversation = conversation;
    dialogIndex = index;
    if (conversation.hasScene || previous == null) {
      _scene = conversation.scene;
      stage.enterScene(conversation.scene, previous: previous);
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
