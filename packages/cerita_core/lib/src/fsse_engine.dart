import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'data/channel.dart';
import 'data/clue.dart';
import 'data/conversation.dart';
import 'data/item_result.dart';
import 'data/items/base.dart';
import 'data/items/branch.dart';
import 'data/items/choice.dart';
import 'data/items/ending.dart';
import 'data/items/evidence.dart';
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
import 'l10n/localized_text.dart';
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

  /// [item] is in the active language, so it can be named by its `title`.
  void onMediaUnlocked(MediaItemType item) {}

  void onEndingUnlocked(EndingItemType ending) {}

  void onCheckpointUnlocked(Checkpoint checkpoint) {}

  /// Called once for each clue a step of the story finds, in `clues.json` order. Not called when a load,
  /// checkpoint or rollback restores clues.
  void onClueFound(Clue clue) {}
}

/// Thrown by [FsseEngine.next] when a conversation runs out of items without a target.
class EndOfStoryException implements Exception {
  final String conversationKey;

  const EndOfStoryException(this.conversationKey);

  @override
  String toString() => "EndOfStoryException: no more items in '$conversationKey'";
}

/// Asked before the story enters a [Conversation]: false keeps the player out of it. A story that sells part of
/// itself decides here, by chapter or key, without the engine knowing about the store.
typedef StoryGate = FutureOr<bool> Function(Conversation conversation);

/// Thrown by [RealFsseEngine.start], [RealFsseEngine.next] and [RealFsseEngine.jumpTo] when the
/// [RealFsseEngine.gate] keeps the story out of [conversation]. The engine is left part way through the move, so
/// play goes on from a save or a fresh [RealFsseEngine.start], not from another `next`.
class StoryGateException implements Exception {
  final Conversation conversation;

  const StoryGateException(this.conversation);

  @override
  String toString() => "StoryGateException: '${conversation.key}' is closed";
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

  /// Asked before every conversation the story enters, see [StoryGate]. Null lets the story go anywhere.
  StoryGate? gate;

  RealFsseEngine(this.loader, {this.listener, this.storage, this.gate, this.evaluator = const ConditionEvaluator()});

  RealFsseEngine.withListener(this.loader, this.listener)
      : storage = null,
        evaluator = const ConditionEvaluator();

  /// `random()` results, replayed after a rollback.
  late final RollLog _rolls = RollLog(evaluator.random);

  /// [evaluator] drawing its random numbers from [_rolls].
  late final ConditionEvaluator _evaluator = ConditionEvaluator(_rolls);

  /// The cast. Empty until [start] reads the story.
  ProfileData profileData = const ProfileData([]);
  List<Channel> channels = const [];
  ClueCatalog clues = ClueCatalog.empty;

  /// The story's languages, from `index.json`.
  StoryLocales storyLocales = const StoryLocales();
  String? _locale;
  ProfileData? _localizedProfiles;

  /// Name of the player profile until `NAME` is set.
  String playerFallbackName = "You";
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

  /// Clues the player has seen on the Case Board.
  final Set<String> _viewedClues = {};

  /// Retries used by evidence questions waiting for a final answer, by `<conversation_key>#<index>`.
  final Map<String, int> _evidenceTries = {};

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

  /// The player's language. Null shows the story's source language. Can change at any time: the next item,
  /// profiles and channels follow it, and [history] keeps every language.
  String? get locale => _locale;

  set locale(String? locale) {
    if (locale == _locale) return;
    _locale = locale;
    _localizedProfiles = null;
  }

  Localizer get localizer => Localizer(locale: _locale, sourceLocale: storyLocales.source);

  /// Starts a playthrough: fresh from `index.json`, from a [save] slot, or from a [checkpoint].
  /// With [replay], only the [checkpoint]'s chapter is played: entering a conversation of another
  /// chapter throws [EndOfStoryException]. Throws [StoryGateException] when the [gate] keeps the story out of the
  /// conversation it starts in.
  Future<void> start({SaveSlot? save, Checkpoint? checkpoint, bool replay = false}) async {
    final package = await loader.initialLoad();
    profileData = package.profiles;
    channels = package.channels;
    clues = package.clues;
    storyLocales = package.conversation.locales;
    _localizedProfiles = null;
    meta = await storage?.loadMeta() ?? meta;

    dataMap.clear();
    _history.clear();
    _callStack.clear();
    _chosen.clear();
    _viewedClues.clear();
    _evidenceTries.clear();
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
      _evidenceTries.addAll(save.evidenceTries);
      // Older saves didn't record viewed clues: what was found counts as seen.
      _viewedClues.addAll(save.viewedClues ?? _foundIds());
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
      _viewedClues.addAll(_foundIds());
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
    final found = _foundIds();
    await _handleResult(prevResult);

    final item = await _resolveCurrentItem();
    final executed = await _execute(item);
    _pushFrame(executed);
    await _flushMeta();
    for (final clue in clues.clues) {
      if (isClueFound(clue) && !found.contains(clue.id)) listener?.onClueFound(clue);
    }
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

  /// Whether [clue] is found in this playthrough: its `clue_<id>` variable is `true`.
  bool isClueFound(Clue clue) => dataMap[clue.variable] == true;

  /// The clues found in this playthrough, in `clues.json` order.
  List<Clue> get foundClues => clues.clues.where(isClueFound).toList();

  Set<String> _foundIds() => {for (final clue in foundClues) clue.id};

  /// Ids of the clues the player has seen on the Case Board.
  Set<String> get viewedClues => Set.unmodifiable(_viewedClues);

  /// Found clues the player hasn't seen on the Case Board yet.
  List<Clue> get newClues => foundClues.where((clue) => !_viewedClues.contains(clue.id)).toList();

  /// Marks clues as seen on the Case Board. Saved with the playthrough, not rolled back.
  void markCluesViewed(Iterable<String> ids) => _viewedClues.addAll(ids);

  /// Whether [rollback] has a line to go back to. With [historyIndex], whether the line at that
  /// transcript index can be rolled back to.
  bool canRollback({int? historyIndex}) => _rollbackTarget(historyIndex) != null;

  /// Where the story goes before it shows its next item, without going there: null while the next item is in the
  /// current conversation, else the conversation it is in and the scene it plays in. The record's `next` is null
  /// when the story ends first. Follows conditions, `BRANCH`, `JUMP`, `CALL` and `RETURN` as [next] does, but
  /// applies no effects, so a condition that reads a variable set on the way is read as it is now.
  Future<({Conversation? next, Scene? scene})?> peekExit() async {
    var conversation = currentConversation;
    if (conversation == null) return null;
    var index = dialogIndex;
    var scene = _scene;
    final callStack = _callStack.toList();

    Future<bool> enter(String key, int at) async {
      final entered = _conversations[key] ?? await loader.loadConversation(key);
      final chapter = _replayChapter;
      if (chapter != null && entered.chapter != null && entered.chapter != chapter) return false;
      conversation = entered;
      index = at;
      if (entered.hasScene) scene = entered.scene;
      return true;
    }

    for (var steps = 0; steps < _maxJumps; steps++) {
      final current = conversation!;
      if (index >= current.conversations.length) {
        if (callStack.isEmpty) return (next: null, scene: null);
        final frame = callStack.removeLast();
        if (!await enter(frame.conversationKey, frame.dialogIndex)) return (next: null, scene: null);
        continue;
      }
      final item = current.conversations[index];
      if (!evaluate(item.condition)) {
        index++;
        continue;
      }
      final String target;
      switch (item) {
        case BranchItemType():
          final branch =
              item.branches.where((branch) => evaluate(branch.condition)).firstOrNull?.target ?? item.fallbackTarget;
          if (branch == null) {
            index++;
            continue;
          }
          target = branch;
        case JumpItemType():
          target = item.target;
        case CallItemType():
          callStack.add(CallFrame(current.key, index + 1));
          target = item.target;
        case ReturnItemType():
          if (callStack.isEmpty) return (next: null, scene: null);
          final frame = callStack.removeLast();
          if (!await enter(frame.conversationKey, frame.dialogIndex)) return (next: null, scene: null);
          continue;
        case FlowItemType():
          index++;
          continue;
        default:
          return identical(current, currentConversation) ? null : (next: current, scene: scene);
      }
      final hash = target.indexOf("#");
      final key = hash < 0 ? target : target.substring(0, hash);
      final label = hash < 0 ? null : target.substring(hash + 1);
      if (key.isNotEmpty && !await enter(key, 0)) return (next: null, scene: null);
      if (label != null) {
        index = conversation!.conversations.indexWhere((item) => item.id == label);
        if (index < 0) return null;
      } else if (key.isEmpty) {
        index = 0;
      }
    }
    return null;
  }

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
    // The frame may come from a save, or the player may have switched language since.
    return frame.item.localized(localizer);
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
    _evidenceTries
      ..clear()
      ..addAll(frame.evidenceTries);
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
      evidenceTries: Map.of(_evidenceTries),
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
      return Profile(id: ProfileInfo.playerId, name: dataMap["NAME"]?.toString() ?? playerFallbackName);
    }
    return (_localizedProfiles ??= profileData.localized(localizer)).byId(id);
  }

  Channel? getChannel(String? id) => channels.where((channel) => channel.id == id).firstOrNull?.localized(localizer);

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
      chapter: conversation.chapterText,
      title: conversation.titleText,
      rollback: _rollbackLog(),
      viewedClues: _viewedClues.toSet(),
      evidenceTries: Map.of(_evidenceTries),
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
        // Nothing to present: the question isn't asked and its fallback plays.
        case EvidenceItemType(:final fallback) when foundClues.isEmpty:
          _evidenceTries.remove("${conversation.key}#$dialogIndex");
          dialogIndex += 1;
          if (await _playOutcome(fallback)) jumps++;
          continue;
        case EvidenceItemType():
          break;
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
    final cloned = item.cloneWithData(state, localizer: localizer);
    // An evidence question's options are the found clues, which the UI reads from the engine.
    if (cloned is! ChoiceItemType || cloned is EvidenceItemType) return cloned;
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

  /// Makes the item's character the speaker. A `TEXT` line puts its speaker on stage: at the line's `position`,
  /// its current slot, or center. Other items (a `CHOICE` or `INPUT` prompt, a `MEDIA` sender) only change the
  /// expression of a character already on stage, and an offstage line leaves the stage as it is. A speaker who
  /// isn't on stage leaves everyone on stage dimmed.
  void _placeSpeaker(ItemType item) {
    final info = item.getProfileInfo();
    if (info == null || info.isPlayer || item is NarrationItemType) {
      stage.speakerId = null;
      return;
    }
    stage.speakerId = info.id;
    if (item is TextItemType && item.offstage) return;
    if (item is TextItemType) {
      stage.place(info, item.position);
    } else if (stage.slotOf(info.id) != null) {
      stage.place(info);
    }
  }

  Future<void> _registerUnlocks(ItemType item) async {
    if (item is MediaItemType && item.unlockId != null && meta.unlockedMediaIds.add(item.unlockId!)) {
      await storage?.saveMeta(meta);
      listener?.onMediaUnlocked(item);
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
    if (itemResult.presentedClue != null || itemResult.evidenceTimedOut) return _answerEvidence(itemResult);

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
    final playerText = itemResult.localizedText ??
        switch (itemResult.text) {
          final text? => LocalizedText(text),
          null => null,
        };
    if (playerText != null && scene != null) {
      _history.add(TranscriptEntry(
        conversationKey: currentConversation!.key,
        mode: scene.mode,
        channelId: scene.channelId,
        playerText: playerText,
      ));
    }

    final target = itemResult.target;
    if (target != null) await _jump(target);
  }

  /// Answers the evidence question that was returned last: a presented clue or a timeout. See
  /// `specs/data-schema.md` section 4.4.
  Future<void> _answerEvidence(ItemResult result) async {
    final conversation = currentConversation!;
    final index = dialogIndex - 1;
    final key = "${conversation.key}#$index";
    final question = conversation.conversations.elementAtOrNull(index);
    if (_lastItemKey != key || question is! EvidenceItemType) {
      throw StateError("Evidence answer, but the last item isn't an evidence question ($_lastItemKey)");
    }

    final clueId = result.presentedClue;
    EvidenceOutcome? outcome;
    var askAgain = false;
    if (clueId == null) {
      _evidenceTries.remove(key);
      outcome = question.timeout ?? question.fallback;
    } else {
      final clue = clues.byId(clueId) ?? (throw ArgumentError.value(clueId, "presentedClue", "No such clue"));
      if (result.variable != null) state[result.variable!] = clue.id;
      // The title in every language, so the reply follows a language switch like the rest of the history.
      _history.add(TranscriptEntry(
        conversationKey: conversation.key,
        mode: _scene!.mode,
        channelId: _scene!.channelId,
        playerText: clue.title,
        clueId: clue.id,
      ));
      final used = _evidenceTries[key] ?? 0;
      if (question.responseFor(clue.id) case final response?) {
        _evidenceTries.remove(key);
        outcome = response;
      } else if (used < question.retries) {
        _evidenceTries[key] = used + 1;
        outcome = question.retry;
        askAgain = outcome?.target == null;
      } else {
        _evidenceTries.remove(key);
        outcome = question.fallback;
      }
    }

    if (!await _playOutcome(outcome) && askAgain) dialogIndex = index;
  }

  /// Applies the [outcome]'s effects and follows its target. True if it jumped.
  Future<bool> _playOutcome(EvidenceOutcome? outcome) async {
    if (outcome == null) return false;
    _applyEffects(outcome.effects);
    final target = outcome.target;
    if (target == null) return false;
    await _jump(target);
    return true;
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
    // Before anything changes, so a closed conversation is never current and its checkpoint stays locked.
    final gate = this.gate;
    if (gate != null && !await gate(conversation)) throw StoryGateException(conversation);
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
        chapter: conversation.chapterText,
        title: conversation.titleText,
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
