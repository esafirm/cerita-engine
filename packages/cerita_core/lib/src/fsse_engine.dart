import 'dart:developer' as developer;

import 'data/channel.dart';
import 'data/conversation.dart';
import 'data/item_result.dart';
import 'data/items/base.dart';
import 'data/items/branch.dart';
import 'data/items/choice.dart';
import 'data/items/ending.dart';
import 'data/items/input.dart';
import 'data/items/media.dart';
import 'data/items/profile_info.dart';
import 'data/profile.dart';
import 'data/scene.dart';
import 'loader.dart';
import 'state/meta_state.dart';
import 'state/save_slot.dart';
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

  final Map<String, dynamic> dataMap = {};
  final List<TranscriptEntry> _history = [];

  /// Whether the last item returned by [next] had been delivered in an earlier playthrough.
  bool lastItemPreviouslySeen = false;

  /// True while the last returned item is a CHOICE / INPUT waiting for its [ItemResult].
  bool _awaitingResult = false;

  bool _started = false;

  List<TranscriptEntry> get history => List.unmodifiable(_history);

  Scene? get currentScene => currentConversation?.scene;

  /// Starts a playthrough: fresh from `index.json`, from a [save] slot, or from a [checkpoint].
  Future<void> start({SaveSlot? save, Checkpoint? checkpoint}) async {
    final package = await loader.initialLoad();
    profileData = package.profiles;
    channels = package.channels;
    meta = await storage?.loadMeta() ?? meta;

    dataMap.clear();
    _history.clear();
    _awaitingResult = false;
    _started = true;

    if (save != null) {
      dataMap.addAll(save.dataMap);
      _history.addAll(save.history);
      await _enterConversation(await loader.loadConversation(save.conversationKey), index: save.dialogIndex);
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
    return _execute(item);
  }

  @override
  Future<ItemType> get() async {
    developer.log("Request get with index: $dialogIndex", name: _tag);
    await _ensureStarted();
    return _prepare(await _resolveCurrentItem());
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

  bool evaluate(String? condition) => evaluator.evaluate(condition, dataMap);

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

  /// Skips items whose condition fails and follows BRANCH routers.
  Future<ItemType> _resolveCurrentItem() async {
    for (var jumps = 0; jumps < _maxJumps;) {
      final conversation = currentConversation;
      if (conversation == null) {
        throw Exception("Empty conversation. Are you already load the assets?");
      }
      if (dialogIndex >= conversation.conversations.length) {
        throw EndOfStoryException(conversation.key);
      }

      final item = conversation.conversations[dialogIndex];
      if (!evaluate(item.condition)) {
        dialogIndex += 1;
        continue;
      }

      if (item is BranchItemType) {
        final target =
            item.branches.where((branch) => evaluate(branch.condition)).firstOrNull?.target ?? item.fallbackTarget;
        if (target == null) {
          dialogIndex += 1;
          continue;
        }
        await _enterConversation(await loader.loadConversation(target));
        jumps++;
        continue;
      }
      return item;
    }
    throw Exception("Too many BRANCH jumps. Is there a loop in the story?");
  }

  ItemType _prepare(ItemType item) {
    final cloned = item.cloneWithData(dataMap);
    return cloned is ChoiceItemType ? cloned.withAvailability(evaluate) : cloned;
  }

  Future<ItemType> _execute(ItemType item) async {
    for (final effect in item.effects) {
      effect.apply(dataMap);
    }
    final prepared = _prepare(item);
    final conversation = currentConversation!;

    _history.add(TranscriptEntry(
      conversationKey: conversation.key,
      mode: conversation.scene.mode,
      channelId: conversation.scene.channelId,
      item: prepared.toJson(),
    ));
    lastItemPreviouslySeen = !meta.seenItems.add("${conversation.key}#$dialogIndex");
    _awaitingResult = prepared is ChoiceItemType || prepared is InputItemType;
    dialogIndex += 1;

    await _registerUnlocks(prepared);
    return prepared;
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
      dataMap[itemResult.variable!] = itemResult.value;
    }

    for (final effect in itemResult.effects) {
      effect.apply(dataMap);
    }

    final scene = currentConversation?.scene;
    if (itemResult.text != null && scene != null) {
      _history.add(TranscriptEntry(
        conversationKey: currentConversation!.key,
        mode: scene.mode,
        channelId: scene.channelId,
        playerText: itemResult.text,
      ));
    }

    final target = itemResult.target;
    if (target != null) {
      await _enterConversation(await loader.loadConversation(target));
    }
  }

  /// Called after initial load and after a new conversation is loaded.
  Future<void> _enterConversation(Conversation conversation, {int index = 0}) async {
    currentConversation = conversation;
    dialogIndex = index;
    listener?.onNewScene(conversation.scene);
    listener?.onConversationStarted(conversation);

    if (conversation.checkpoint && index == 0) {
      final checkpoint = Checkpoint(
        conversationKey: conversation.key,
        chapter: conversation.chapter,
        title: conversation.title,
        day: conversation.scene.day,
        dataMap: Map.of(dataMap),
        unlockedAt: DateTime.now(),
      );
      meta.unlockedCheckpoints[conversation.key] = checkpoint;
      await storage?.saveMeta(meta);
      listener?.onCheckpointUnlocked(checkpoint);
    }
  }
}
