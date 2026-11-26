import 'dart:async';
import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/foundation.dart';

import 'audio_helper.dart';
import 'l10n/cerita_strings.dart';
import 'l10n/localized_assets.dart';
import 'l10n/story_language.dart';
import 'player_prefs.dart';

enum StoryPhase {
  /// Nothing delivered yet.
  idle,

  /// Chat / call: "is typing..." before the next message appears.
  typing,

  /// An item is on screen. VN waits for a tap, chat moves on by itself.
  showing,
  choice,
  input,

  /// A WAIT item or a STAGE direction is running.
  waiting,
  ending,

  /// The story ran out of items without an ENDING.
  finished,

  /// The story's [StoryGate] keeps it out of [StoryController.closedConversation]. Nothing is saved, and
  /// [StoryController.reopen] tries again once the gate may have opened.
  gated,
}

/// Where a `CALL` scene's call is, see [StoryController.callState].
enum CallState {
  /// Talking. Every scene that is not a call stays here.
  connected,

  /// The phone rings: a `ring=` scene that just started. The story waits for [StoryController.answerCall].
  ringing,

  /// The player hung up or declined a call with a `hangup` target. The story goes there after
  /// [StoryController.hangUpDelay].
  ended,
}

/// UI-side runner shared by every presentation mode: drives [RealFsseEngine],
/// paces typing / waits, plays audio, autosaves, and handles rollback and quick save / load.
class StoryController extends ChangeNotifier with EngineListener {
  // Typing time of incoming chat messages that set no `typing_delay_ms`.
  static const _typingDelayMs = 900;
  static const _typingDelayPerCharMs = 35;
  static const _maxTypingDelayMs = 3500;

  // Chat moves on by itself, like a real thread. The pause after a delivered message, before the
  // next one starts (incoming ones then type for a while too).
  static const _chatPauseMs = 900;
  static const _chatMediaPauseMs = 1800;

  final RealFsseEngine engine;
  final LoaderConfig config;
  final AudioHelper audio;
  final PlayerPrefs settings;
  final LocalizedAssets assets;

  StoryController({
    required EngineLoader loader,
    required StoryStorage storage,
    required this.config,
    AudioHelper? audio,
    PlayerPrefs? settings,
    LocalizedAssets? assets,
    StoryGate? gate,
  })  : audio = audio ?? AudioHelper(),
        settings = settings ?? PlayerPrefs(storage),
        assets = assets ?? LocalizedAssets(),
        engine = RealFsseEngine(loader, storage: storage, gate: gate) {
    engine.listener = this;
  }

  /// The conversation the gate kept the story out of, while [phase] is [StoryPhase.gated].
  Conversation? closedConversation;

  /// Plays on from where the story stood before the gate. Null when there's nowhere to go back to.
  Future<void> Function()? _reopen;

  /// Whether [reopen] has somewhere to go on from.
  bool get canReopen => _reopen != null;

  /// Tries the closed conversation again, e.g. after a purchase. The story starts over from where it was before
  /// the gate: the start it was asked for, or the autosave of the last line shown, so a choice that led to the
  /// gate is asked again.
  Future<void> reopen() async {
    final reopen = _reopen;
    if (phase != StoryPhase.gated || reopen == null) return;
    await reopen();
  }

  void _close(StoryGateException gated, Future<void> Function()? reopen) {
    _epoch++;
    _autoTimer?.cancel();
    autoMode = false;
    skipMode = false;
    notification = null;
    typingProfile = null;
    _typingEntry = null;
    closedConversation = gated.conversation;
    _reopen = reopen;
    phase = StoryPhase.gated;
    _notify();
  }

  /// After a gate stops [RealFsseEngine.next] or a jump: the engine is part way through the move, so play goes on
  /// from the autosave of the last line. A replay saves nothing, so it can only be left.
  Future<void> _closeMidStory(StoryGateException gated) async {
    final save = replay ? null : await engine.storage?.loadSlot(SaveSlot.autoSlotId);
    _close(gated, save == null ? null : () => _begin(save: save));
  }

  Scene scene = const Scene();
  Conversation? conversation;
  StoryPhase phase = StoryPhase.idle;

  /// Last delivered engine item.
  ItemType? current;
  Profile? currentProfile;

  /// Chat / call typing indicator owner while [phase] is [StoryPhase.typing].
  Profile? typingProfile;

  /// The message being typed. The engine records it on delivery, so it is hidden from
  /// [channelHistory] until the typing indicator is done.
  TranscriptEntry? _typingEntry;

  /// Banner text of the running WAIT item.
  String? notification;

  /// The STAGE item being played, so the stage can use its transitions and camera cues.
  /// Cleared by the next item.
  StageItemType? direction;

  bool autoMode = false;
  bool skipMode = false;

  /// Replaying a single chapter: nothing is saved.
  bool replay = false;

  /// The current line was restored by a rollback, so it is shown without animating.
  bool rolledBack = false;

  /// False while the VN line on screen is still typing out. Auto mode waits for it, see [lineTyped].
  bool _lineTyped = true;

  /// Engine strings for toasts, in the language set by [setLanguage].
  CeritaStrings strings = CeritaStrings.en;

  /// One-off messages (unlocks, saves) for the UI to show as toasts.
  final StreamController<String> _toasts = StreamController.broadcast();

  Stream<String> get toasts => _toasts.stream;

  void _toast(String message) {
    if (!_toasts.isClosed) _toasts.add(message);
  }

  /// Cached localized [ItemType] per [TranscriptEntry] for the active language, cleared on locale switch or reset.
  final Map<TranscriptEntry, ItemType> _itemCache = Map.identity();

  /// Incremental cache of visible entries for the active chat thread, avoiding a full-history scan on every rebuild.
  int _historyEpoch = 0;
  String? _cachedChannelId;
  int _cachedChannelEpoch = -1;
  int _cachedChannelLen = 0;
  TranscriptEntry? _cachedChannelTyping;
  List<TranscriptEntry> _cachedVisibleChannel = const [];

  /// Clean post-delivery autosave snapshot buffered during fast skip or transient waits, plus a write/delete queue
  /// so deferred autosaves never race with ending deletion or snapshot half-completed async gate jumps.
  SaveSlot? _pendingAutoSave;
  Future<void> _saveQueue = Future.value();
  bool _waitAdvancePending = false;

  final StreamController<Clue> _cluesFound = StreamController.broadcast();

  /// Clues as the story finds them, for the clue notification.
  Stream<Clue> get cluesFound => _cluesFound.stream;

  /// How long a call the player ends shows as ended before the story goes on to the scene's `hangup` target.
  static const hangUpDelay = Duration(milliseconds: 1200);

  /// How long [refusal] stays up.
  static const refusalDuration = Duration(milliseconds: 3200);

  /// The call of a `CALL` scene.
  CallState callState = CallState.connected;

  /// What the player's character thinks when they try to end a call that can't be ended (the scene's `stay`).
  /// Null when nothing is shown.
  String? refusal;
  Timer? _refusalTimer;

  /// The scene has played out by itself and waits for a tap before the story goes on to the next one, so a
  /// thread or a stage direction that ends a scene doesn't cut straight to the next. See [_holdsAtSceneEnd].
  bool sceneEndHeld = false;

  /// The player put the call on hold: the line stops and the story waits.
  bool onHold = false;

  /// The scene that just started rings: [_next] holds its first item until the player answers.
  bool _ringPending = false;

  Timer? _hangUp;

  bool _busy = false;
  bool _disposed = false;
  int _pacingHoldCount = 0;
  bool _uiHidden = false;
  int _storyHoldCount = 0;
  Timer? _autoTimer;

  bool get _pacingHeld => _pacingHoldCount > 0;

  /// Bumped when a load or rollback replaces the state, so pending waits of the old state stop.
  int _epoch = 0;

  List<TranscriptEntry> get history => engine.history;

  /// VN background, characters, music, weather and zoom.
  StageState get stage => engine.stage;

  Map<String, dynamic> get dataMap => engine.dataMap;

  Localizer get localizer => engine.localizer;

  /// A delivered item in the active language.
  ItemType? itemOf(TranscriptEntry entry) {
    if (entry.item == null) return null;
    return _itemCache[entry] ??= entry.itemIn(localizer)!;
  }

  /// The player's reply of [entry] in the active language. A presented clue reads "Presented: <title>".
  String? playerTextOf(TranscriptEntry entry) {
    final clue = entry.clueId == null ? null : clues.byId(entry.clueId!);
    if (clue != null) return strings.presented(localizer.resolve(clue.title));
    return localizer.maybe(entry.playerText);
  }

  /// The story's clues. Empty when it has no `clues.json`, and then no Case Board is shown anywhere.
  ClueCatalog get clues => engine.clues;

  bool get hasClues => engine.clues.isNotEmpty;

  List<Clue> get foundClues => engine.foundClues;

  /// Found clues the player hasn't seen on the Case Board yet.
  List<Clue> get newClues => engine.newClues;

  bool isClueNew(Clue clue) => !engine.viewedClues.contains(clue.id);

  void markCluesViewed(Iterable<Clue> clues) {
    engine.markCluesViewed([for (final clue in clues) clue.id]);
    _notify();
  }

  /// Clue text in the active language.
  String clueText(LocalizedText text) => localizer.resolve(text);

  /// Asset path of [clue]'s image, in `media/`.
  String? clueImage(Clue clue) => clue.image == null ? null : config.media(clue.image!);

  /// Transcript of a messenger thread across every conversation that used it.
  List<TranscriptEntry> channelHistory(String? channelId) =>
      history
          .where((entry) => entry.channelId == channelId && entry.mode != SceneMode.vn && !identical(entry, _typingEntry))
          .toList();

  /// Visible transcript entries of a messenger thread, cached incrementally across rebuilds.
  List<TranscriptEntry> visibleChannelHistory(String? channelId) {
    final all = history;
    final len = all.length;
    if (channelId == _cachedChannelId &&
        _cachedChannelEpoch == _historyEpoch &&
        identical(_cachedChannelTyping, _typingEntry)) {
      if (len == _cachedChannelLen) return _cachedVisibleChannel;
      if (_typingEntry == null && len > _cachedChannelLen) {
        final next = List<TranscriptEntry>.of(_cachedVisibleChannel);
        for (var i = _cachedChannelLen; i < len; i++) {
          final entry = all[i];
          if (_isVisibleInChannel(entry, channelId)) next.add(entry);
        }
        _cachedChannelLen = len;
        return _cachedVisibleChannel = List.unmodifiable(next);
      }
    }
    final visible = <TranscriptEntry>[];
    for (var i = 0; i < len; i++) {
      final entry = all[i];
      if (_isVisibleInChannel(entry, channelId)) visible.add(entry);
    }
    _cachedChannelId = channelId;
    _cachedChannelEpoch = _historyEpoch;
    _cachedChannelLen = len;
    _cachedChannelTyping = _typingEntry;
    return _cachedVisibleChannel = List.unmodifiable(visible);
  }

  bool _isVisibleInChannel(TranscriptEntry entry, String? channelId) {
    if (entry.channelId != channelId || entry.mode == SceneMode.vn || identical(entry, _typingEntry)) return false;
    if (entry.isPlayer) return true;
    final item = itemOf(entry);
    return item is TextItemType || item is NarrationItemType || item is MediaItemType;
  }

  Channel? get channel => engine.getChannel(scene.channelId);

  /// Whether [profile]'s messages sit on the outgoing side of the current thread: the player's, and the thread
  /// owner's when the thread is on another character's phone (data schema §2, chat threads).
  bool isOutgoing(Profile? profile) =>
      profile != null && (profile.isPlayer || (scene.mode == SceneMode.chat && profile.id == channel?.owner));

  Profile? profileOf(ItemType item) => engine.getProfile(item);

  Profile? profileById(String id) => engine.getProfileById(id);

  /// The cast, as the story files name it (see [profileById] for the active language).
  List<Profile> get profiles => engine.profileData.profiles;

  bool get canAdvance => !_busy && !_callPaused && (phase == StoryPhase.idle || phase == StoryPhase.showing);

  /// The call is ringing, ended or on hold, so the story waits.
  bool get _callPaused => callState != CallState.connected || onHold;

  /// Whether [rollback] has a line to go back to.
  bool get canRollback => _canRewind && engine.canRollback();

  /// Whether the transcript line at [historyIndex] can be rolled back to.
  bool canRollbackTo(int historyIndex) => _canRewind && engine.canRollback(historyIndex: historyIndex);

  bool get _canRewind =>
      !_busy && !_callPaused && phase != StoryPhase.idle && phase != StoryPhase.typing && phase != StoryPhase.waiting &&
      phase != StoryPhase.gated;

  /// Starts the story fresh, from a [save] or from a [checkpoint]. With [replay], only the checkpoint's
  /// chapter is played and nothing is saved.
  Future<void> start({SaveSlot? save, Checkpoint? checkpoint, bool replay = false}) async {
    audio.addObserver();
    assets.preload();
    await settings.load();
    _applySettings();
    settings.addListener(_applySettings);
    await _begin(save: save, checkpoint: checkpoint, replay: replay);
  }

  /// Replaces the running story with [save].
  Future<void> load(SaveSlot save) async {
    if (_busy) return;
    await _begin(save: save);
  }

  Future<void> quickSave() async {
    if (replay) return;
    await saveTo(SaveSlot.quickSlotId);
  }

  Future<void> quickLoad() async {
    final save = await engine.storage?.loadSlot(SaveSlot.quickSlotId);
    if (save == null) {
      _toast(strings.noQuickSave);
      return;
    }
    await load(save);
    _toast(strings.quickLoaded);
  }

  /// Developer panel: continues the story at [target], keeping the variables.
  Future<void> jumpTo(String target) async {
    if (_busy) return;
    _epoch++;
    _autoTimer?.cancel();
    _waitAdvancePending = false;
    autoMode = false;
    skipMode = false;
    _pacingHoldCount = 0;
    notification = null;
    rolledBack = false;
    _resetCall();
    phase = StoryPhase.idle;
    await audio.stopVoice();
    try {
      await engine.jumpTo(target);
    } on StoryGateException catch (gated) {
      await flushPendingAutoSave();
      return _closeMidStory(gated);
    }
    _pendingAutoSave = null;
    if (_ringPending && !skipMode) {
      _ringPending = false;
      _ring();
      await _saveRingingAutoSave();
      return;
    }
    _ringPending = false;
    await _next();
  }

  /// Developer panel: sets a playthrough or `persistent.*` variable.
  Future<void> setVariable(String variable, dynamic value) async {
    await engine.setVariable(variable, value);
    _notify();
  }

  /// Reads the story files again and shows the current item as it is written now, see
  /// [RealFsseEngine.reloadCurrent]. Runs on a Flutter hot reload, so edits to the story show up without
  /// restarting it.
  Future<void> reloadStory() async {
    if (_busy || phase == StoryPhase.idle) return;
    engine.loader.clearCache();
    assets.clearCache();
    final item = await engine.reloadCurrent();
    if (item == null || _disposed) return;
    _itemCache.clear();
    _historyEpoch++;
    _epoch++;
    if (item is StageItemType) {
      _notify();
    } else {
      rolledBack = true;
      _show(item);
    }
    _toast(strings.storyReloaded);
  }

  /// Goes back to the previous line, or to the transcript line at [historyIndex]. A choice there can be
  /// picked again.
  Future<void> rollback({int? historyIndex}) async {
    if (!_canRewind) return;
    final item = engine.rollback(historyIndex: historyIndex);
    if (item == null) return;
    _epoch++;
    _autoTimer?.cancel();
    _itemCache.clear();
    _historyEpoch++;
    _pendingAutoSave = null;
    _waitAdvancePending = false;
    autoMode = false;
    skipMode = false;
    _pacingHoldCount = 0;
    notification = null;
    direction = null;
    await audio.stopVoice();
    _playMusic();
    _playAmbience();
    rolledBack = true;
    _show(item);
    if (!replay) {
      final slot = engine.snapshot(slotId: SaveSlot.autoSlotId);
      await _enqueueSave(() async {
        await engine.storage?.saveSlot(slot);
        await engine.flushMeta();
      });
    }
  }

  Future<void> _begin({SaveSlot? save, Checkpoint? checkpoint, bool replay = false}) async {
    _epoch++;
    _autoTimer?.cancel();
    _pendingAutoSave = null;
    _waitAdvancePending = false;
    this.replay = replay;
    autoMode = false;
    skipMode = false;
    _pacingHoldCount = 0;
    rolledBack = false;
    notification = null;
    direction = null;
    typingProfile = null;
    _typingEntry = null;
    phase = StoryPhase.idle;
    _resetCall();
    sceneEndHeld = false;
    closedConversation = null;
    _reopen = null;
    await audio.stopVoice();
    try {
      await engine.start(save: save, checkpoint: checkpoint, replay: replay);
    } on StoryGateException catch (gated) {
      _close(gated, () => _begin(save: save, checkpoint: checkpoint, replay: replay));
      return;
    }
    _itemCache.clear();
    _historyEpoch++;
    _playMusic();
    _playAmbience();

    if (save == null) {
      if (_ringPending && !skipMode) {
        _ringPending = false;
        _ring();
        await _saveRingingAutoSave();
        return;
      }
      _ringPending = false;
      await advance();
      return;
    }
    // Restore: show the last delivered line of the active conversation.
    final last = history.lastWhere(
      (entry) => !entry.isPlayer && entry.conversationKey == conversation?.key,
      orElse: () => const TranscriptEntry(conversationKey: "", mode: SceneMode.vn),
    );
    final item = itemOf(last);
    // A save made while an incoming call was still ringing (before item 0) must stay ringing on load.
    if (item == null && scene.mode == SceneMode.call && scene.ring != null && engine.dialogIndex == 0) {
      _ringPending = false;
      _ring();
      return;
    }
    _ringPending = false;
    if (item == null || item is WaitItemType) {
      await advance();
    } else {
      current = item;
      currentProfile = engine.getProfile(item);
      _lineTyped = !_typesOut(item);
      phase = item is EndingItemType ? StoryPhase.ending : StoryPhase.showing;
      if (scene.mode == SceneMode.chat && phase == StoryPhase.showing) await _holdsAtSceneEnd(_epoch);
      _notify();
      _scheduleAutoAdvance();
    }
  }

  /// Shows [item] again, as restored by a rollback.
  void _show(ItemType item) {
    sceneEndHeld = false;
    _ringPending = false;
    current = item;
    currentProfile = engine.getProfile(item);
    _lineTyped = !_typesOut(item);
    phase = _phaseOf(item);
    _notify();
    _scheduleAutoAdvance();
  }

  /// Whether the VN stage types [item] out and reports it through [lineTyped].
  bool _typesOut(ItemType item) => scene.mode == SceneMode.vn && (item is TextItemType || item is NarrationItemType);

  /// Called by the VN stage once the current line is fully shown. Auto mode counts its delay from here.
  void lineTyped() {
    if (_lineTyped) return;
    _lineTyped = true;
    _scheduleAutoAdvance();
  }

  /// Plays the voice of a line again, e.g. from the backlog.
  Future<void> replayVoice(TextItemType item) async {
    final voice = item.voice;
    if (voice == null) return;
    final path = assets.resolveNow(config.music(voice), localizer.activeLocale);
    await audio.playVoice(path, character: _characterVolume(item));
  }

  double _characterVolume(ItemType item) => settings.value.voiceVolumes[item.getProfileInfo()?.id] ?? 1;

  static StoryPhase _phaseOf(ItemType item) => switch (item) {
        ChoiceItemType() => StoryPhase.choice,
        InputItemType() => StoryPhase.input,
        WaitItemType() || StageItemType() => StoryPhase.waiting,
        EndingItemType() => StoryPhase.ending,
        _ => StoryPhase.showing,
      };

  /// Requests the next item. Ignored while an interaction or delivery is pending.
  Future<void> advance() async {
    if (!canAdvance) return;
    await _next();
  }

  Future<void> choose(Choice choice) async {
    final item = current;
    if (_busy || phase != StoryPhase.choice || item is! ChoiceItemType || choice.locked) return;
    await _next(ItemResult.choice(item.variable, choice));
  }

  /// Presents [clue] to the pending evidence question.
  Future<void> present(Clue clue) async {
    final item = current;
    if (_busy || phase != StoryPhase.choice || item is! EvidenceItemType) return;
    await _next(ItemResult.present(item, clue));
  }

  /// The pending evidence question's countdown ran out.
  Future<void> evidenceTimedOut() async {
    if (_busy || phase != StoryPhase.choice || current is! EvidenceItemType) return;
    await _next(const ItemResult.evidenceTimeout());
  }

  Future<void> submitInput(String value) async {
    final item = current;
    if (_busy || phase != StoryPhase.input || item is! InputItemType) return;
    // Too short, too long or not digits for a digits input: not sent, the prompt stays.
    if (!item.accepts(value.trim())) return;
    final text = value.trim().isEmpty ? (item.defaultValue ?? "") : value.trim();
    await _next(ItemResult.input(item.variable, text));
  }

  void toggleAuto() {
    autoMode = !autoMode;
    skipMode = false;
    _scheduleAutoAdvance();
    _notify();
  }

  void toggleSkip() {
    skipMode = !skipMode;
    autoMode = false;
    if (!skipMode) unawaited(flushPendingAutoSave());
    _scheduleAutoAdvance();
    _notify();
  }

  Future<void> _enqueueSave(Future<void> Function() action) {
    final next = _saveQueue.then((_) => action(), onError: (_) => action());
    _saveQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _saveRingingAutoSave() async {
    _pendingAutoSave = null;
    if (replay || engine.currentConversation == null) return;
    final slot = engine.snapshot(slotId: SaveSlot.autoSlotId);
    await _enqueueSave(() async {
      await engine.storage?.saveSlot(slot);
      await engine.flushMeta();
    });
  }

  /// Flushes any autosave or seen-item meta write deferred during rapid skip mode or transient waits.
  /// Always persists the clean post-delivery snapshot captured when the save was deferred, never a mid-transition state.
  Future<void> flushPendingAutoSave() {
    final slot = _pendingAutoSave;
    _pendingAutoSave = null;
    if (slot != null && !replay) {
      return _enqueueSave(() async {
        await engine.storage?.saveSlot(slot);
        await engine.flushMeta();
      });
    }
    return _enqueueSave(engine.flushMeta);
  }

  Future<void> saveTo(int slotId) async {
    if (replay || phase == StoryPhase.gated) return;
    if (slotId == SaveSlot.autoSlotId) _pendingAutoSave = null;
    await _enqueueSave(() => engine.saveTo(slotId));
    switch (slotId) {
      case SaveSlot.autoSlotId:
        break;
      case SaveSlot.quickSlotId:
        _toast(strings.quickSaved);
      default:
        _toast(strings.savedToSlot(slotId));
    }
  }

  Future<void> _next([ItemResult? result]) async {
    if (_busy || _disposed) return;
    _busy = true;
    _waitAdvancePending = false;
    sceneEndHeld = false;
    _autoTimer?.cancel();
    final epoch = _epoch;
    ItemType? item;
    var ended = false;
    try {
      if (result?.text != null && scene.mode == SceneMode.chat) audio.playSfx(config.music("sfx_msg_send.mp3"));
      item = await engine.nextOrPause(
        prevResult: result,
        stopAtScene: (scene) => !skipMode && scene.mode == SceneMode.call && scene.ring != null,
        deferSeenFlush: skipMode,
      );
    } on EndOfStoryException {
      ended = true;
      phase = StoryPhase.finished;
      _notify();
    } on StoryGateException catch (gated) {
      await flushPendingAutoSave();
      return _closeMidStory(gated);
    } finally {
      _busy = false;
    }
    if (ended) return _afterDelivery(epoch);
    if (item == null) {
      // An incoming call: the scene shows the phone ringing, and its first item waits for the player to answer.
      _ringPending = false;
      _ring();
      await _saveRingingAutoSave();
      return;
    }
    _ringPending = false;
    await _deliver(item);
  }

  /// Presents [item], then saves and moves on as its phase needs.
  Future<void> _deliver(ItemType item) async {
    final epoch = _epoch;
    _busy = true;
    try {
      await _present(item);
    } finally {
      _busy = false;
    }
    await _afterDelivery(epoch);
  }

  Future<void> _afterDelivery(int epoch) async {
    if (_disposed) return;

    if (!replay) {
      // A finished playthrough leaves no autosave, so the title screen doesn't offer Continue into it.
      if (phase == StoryPhase.ending || phase == StoryPhase.finished) {
        _pendingAutoSave = null;
        await _enqueueSave(() async {
          await engine.storage?.deleteSlot(SaveSlot.autoSlotId);
          await engine.flushMeta();
        });
      } else if (phase == StoryPhase.waiting || (skipMode && phase == StoryPhase.showing)) {
        // Capture a clean snapshot now and coalesce the write during fast skip or transient STAGE/WAIT steps.
        _pendingAutoSave = engine.snapshot(slotId: SaveSlot.autoSlotId);
      } else if (phase != StoryPhase.typing) {
        _pendingAutoSave = null;
        final slot = engine.snapshot(slotId: SaveSlot.autoSlotId);
        await _enqueueSave(() async {
          await engine.storage?.saveSlot(slot);
          await engine.flushMeta();
        });
      }
    }
    if (phase == StoryPhase.waiting) {
      final duration = switch (current) {
        WaitItemType(:final durationMs) => skipMode ? 200 : durationMs,
        StageItemType item => skipMode ? 0 : item.effectiveWaitMs,
        _ => 0,
      };
      await Future.delayed(Duration(milliseconds: duration));
      if (_disposed || epoch != _epoch) return;
      notification = null;
      phase = StoryPhase.showing;
      if (await _holdsAtSceneEnd(epoch)) {
        await flushPendingAutoSave();
        if (!_disposed && epoch == _epoch) _notify();
        return;
      }
      if (storyHeld) {
        _waitAdvancePending = true;
        await flushPendingAutoSave();
        if (!_disposed && epoch == _epoch) _notify();
        return;
      }
      await advance();
      return;
    }
    // A thread moves on by itself.
    if (scene.mode == SceneMode.chat && phase == StoryPhase.showing && await _holdsAtSceneEnd(epoch)) _notify();
    _scheduleAutoAdvance();
  }

  /// Sets [sceneEndHeld] when the story would leave the scene on its own next: the player taps to go on, unless
  /// Auto or Skip moves the story for them. As [StoryScreen] shows scenes, a new VN conversation is a new scene,
  /// and a chat or call thread goes on across conversations unless a new chapter starts.
  Future<bool> _holdsAtSceneEnd(int epoch) async {
    if (skipMode || autoMode) return false;
    final exit = await engine.peekExit();
    if (_disposed || epoch != _epoch || exit == null) return false;
    final next = exit.next;
    final nextScene = exit.scene ?? scene;
    sceneEndHeld =
        next == null ||
        nextScene.mode != scene.mode ||
        nextScene.channelId != scene.channelId ||
        scene.mode == SceneMode.vn ||
        (next.chapterText != null && next.chapterText != conversation?.chapterText);
    return sceneEndHeld;
  }

  Future<void> _present(ItemType item) async {
    final locale = engine.locale;
    var profile = engine.getProfile(item);
    final typingDelay = switch (item) {
      TextItemType(:final typingDelayMs) || MediaItemType(:final typingDelayMs) when typingDelayMs != null =>
        typingDelayMs,
      // The owner of the phone being read writes their own messages: no typing from them.
      _ when scene.mode == SceneMode.chat && isOutgoing(profile) => null,
      // Incoming messages without an explicit delay still take a moment to type.
      TextItemType(:final text) when scene.mode == SceneMode.chat && profile != null =>
        min(_typingDelayMs + TextMarkup.plain(text).length * _typingDelayPerCharMs, _maxTypingDelayMs),
      MediaItemType() when scene.mode == SceneMode.chat && profile != null => _typingDelayMs * 2,
      _ => null,
    };

    // The player's chat pacing speeds it up, down to instant.
    final typingMs = typingDelay == null ? 0 : settings.value.chatTypingFor(typingDelay);
    if (scene.mode != SceneMode.vn && typingMs > 0 && !skipMode) {
      phase = StoryPhase.typing;
      // An explicit delay on the owner's message is a pause: the phone being read doesn't show its owner typing.
      typingProfile = profile?.isPlayer == false && isOutgoing(profile) ? null : profile;
      _typingEntry = history.lastOrNull;
      _notify();
      await Future.delayed(Duration(milliseconds: typingMs));
      if (_disposed) return;
      typingProfile = null;
      _typingEntry = null;
    }
    // The player may have switched language while the message was being typed.
    if (engine.locale != locale) {
      item = item.localized(localizer);
      profile = engine.getProfile(item);
    }

    final sfx = switch (item) {
      TextItemType(:final sfx) || NarrationItemType(:final sfx) || MediaItemType(:final sfx) => sfx,
      _ => null,
    };
    if (sfx != null) audio.playSfx(config.music(sfx));
    await audio.stopVoice();
    if (item is TextItemType && item.voice != null && !skipMode) {
      final voice = assets.resolveNow(config.music(item.voice!), localizer.activeLocale);
      audio.playVoice(voice, character: _characterVolume(item));
    }

    direction = item is StageItemType ? item : null;
    if (item is StageItemType) _playStageAudio(item);

    current = item;
    currentProfile = profile;
    rolledBack = false;
    _lineTyped = !_typesOut(item);
    phase = _phaseOf(item);
    if (item is WaitItemType) notification = item.notificationText;
    // Stage directions keep Auto / Skip running. Anything else that is not a line stops them.
    if (phase != StoryPhase.showing && item is! StageItemType) {
      autoMode = false;
      skipMode = false;
    }
    _notify();
  }

  /// Switches story text, toasts and voice clips to [language]. The current line, speaker, chapter and
  /// banner are re-read in it; history follows through [itemOf].
  void setLanguage(StoryLanguage language) {
    strings = language.strings;
    engine.playerFallbackName = strings.you;
    if (engine.locale == language.locale) return;
    engine.locale = language.locale;
    _itemCache.clear();
    final item = current?.localized(localizer);
    current = item;
    if (item != null) currentProfile = engine.getProfile(item);
    conversation = conversation?.localized(localizer);
    if (item is WaitItemType && notification != null) notification = item.notificationText;
    _notify();
  }

  void _playStageAudio(StageItemType item) {
    for (final action in item.actions) {
      switch (action) {
        case MusicAction(:final fadeMs):
          _playMusic(fadeMs: fadeMs);
        case AmbienceAction(:final fadeMs):
          _playAmbience(fadeMs: fadeMs);
        case SoundAction(:final file) when !skipMode:
          audio.playSfx(config.music(file));
        default:
          break;
      }
    }
  }

  void _playMusic({int? fadeMs}) =>
      audio.playBgm(stage.music == null ? null : config.music(stage.music!), fadeMs: fadeMs);

  void _playAmbience({int? fadeMs}) =>
      audio.playAmbience(stage.ambience == null ? null : config.music(stage.ambience!), fadeMs: fadeMs);

  void _applySettings() {
    final value = settings.value;
    audio.setVolumes(music: value.musicVolume, sound: value.soundVolume, voice: value.voiceVolume);
    _notify();
  }

  /// Pauses chat pacing, e.g. while a chapter card covers the thread.
  void holdPacing(bool held) {
    if (_disposed) return;
    final wasHeld = _pacingHeld;
    _pacingHoldCount = held ? _pacingHoldCount + 1 : (_pacingHoldCount > 0 ? _pacingHoldCount - 1 : 0);
    if (_pacingHeld != wasHeld) _scheduleAutoAdvance();
  }

  /// Holds the story while a screen covers it, like the Case Board: chat pacing, auto, skip and a timed choice's
  /// countdown wait until it is released.
  void holdStory(bool held) {
    if (_disposed) return;
    final wasHeld = storyHeld;
    _storyHoldCount = held ? _storyHoldCount + 1 : (_storyHoldCount > 0 ? _storyHoldCount - 1 : 0);
    if (storyHeld != wasHeld) {
      if (!storyHeld && _waitAdvancePending) {
        _waitAdvancePending = false;
        unawaited(advance());
      } else {
        _scheduleAutoAdvance();
      }
      _notify();
    }
  }

  bool get storyHeld => _storyHoldCount > 0;

  /// Rings the phone: the scene's `ring` sound, or the phone on silent when it has none.
  void _ring() {
    callState = CallState.ringing;
    onHold = false;
    phase = StoryPhase.idle;
    if (scene.ring case final ring?) audio.startRing(config.music(ring));
    _notify();
  }

  /// Picks up the ringing phone and delivers the scene's first line.
  Future<void> answerCall() async {
    if (callState != CallState.ringing || _busy) return;
    audio.stopRing();
    _clearRefusal();
    callState = CallState.connected;
    await _next();
  }

  /// Declines the ringing phone or hangs up. A scene with a `hangup` target ends the call and goes there after
  /// [hangUpDelay]. Any other call can't be ended: [refusal] shows what the player's character thinks of it,
  /// and the call goes on.
  void endCall() {
    if (scene.mode != SceneMode.call || callState == CallState.ended) return;
    final target = scene.hangUp;
    if (target == null) {
      refusal = switch (scene.stay) {
        final stay? => localizer.resolve(stay),
        null => strings.cantHangUp,
      };
      _refusalTimer?.cancel();
      _refusalTimer = Timer(refusalDuration, _clearRefusal);
      _notify();
      return;
    }
    if (_busy) return;
    audio.stopRing();
    audio.stopVoice();
    _autoTimer?.cancel();
    _clearRefusal();
    callState = CallState.ended;
    onHold = false;
    _hangUp?.cancel();
    final epoch = _epoch;
    _hangUp = Timer(hangUpDelay, () {
      if (!_disposed && epoch == _epoch && callState == CallState.ended) jumpTo(target);
    });
    _notify();
  }

  void _clearRefusal() {
    _refusalTimer?.cancel();
    if (refusal == null) return;
    refusal = null;
    _notify();
  }

  /// Puts the call on hold, or takes it off: the line stops, and is said again when the call comes back.
  void holdCall(bool held) {
    if (scene.mode != SceneMode.call || callState != CallState.connected || onHold == held) return;
    onHold = held;
    if (held) {
      _autoTimer?.cancel();
      audio.stopVoice();
    } else {
      _speakAgain();
      _scheduleAutoAdvance();
    }
    _notify();
  }

  /// Says the current line again after the call was held.
  void _speakAgain() {
    if (current case final TextItemType item when phase == StoryPhase.showing && !skipMode) replayVoice(item);
  }

  void _resetCall() {
    _hangUp?.cancel();
    _refusalTimer?.cancel();
    refusal = null;
    _ringPending = false;
    if (callState == CallState.ringing) audio.stopRing();
    callState = CallState.connected;
    onHold = false;
  }

  /// The VN UI is hidden to look at the stage. Auto and skip wait until it comes back.
  void setUiHidden(bool hidden) {
    if (_uiHidden == hidden) return;
    _uiHidden = hidden;
    _scheduleAutoAdvance();
  }

  void _scheduleAutoAdvance() {
    _autoTimer?.cancel();
    if (_disposed) return;
    if (phase != StoryPhase.showing) return;
    if (_callPaused) return;
    if (storyHeld) return;
    if (scene.mode == SceneMode.chat && !skipMode && !sceneEndHeld) {
      if (_pacingHeld) return;
      final pause = current is MediaItemType ? _chatMediaPauseMs : _chatPauseMs;
      _autoTimer = Timer(Duration(milliseconds: pause), advance);
      return;
    }
    if (!autoMode && !skipMode) return;
    if (_uiHidden) return;
    if (autoMode && !_lineTyped) return;
    if (skipMode && !engine.lastItemPreviouslySeen && !settings.value.skipUnread) {
      // Skip only fast-forwards text read in an earlier playthrough, unless the player skips unread text too.
      skipMode = false;
      unawaited(flushPendingAutoSave());
      _notify();
      return;
    }
    final length = TextMarkup.plain(current?.getText() ?? "").length;
    final delay = skipMode ? 120 : settings.value.autoDelayFor(length);
    _autoTimer = Timer(Duration(milliseconds: delay), advance);
  }

  @override
  void onNewScene(Scene scene) {
    this.scene = scene;
    _ringPending = scene.mode == SceneMode.call && scene.ring != null;
    _playMusic();
    _playAmbience();
    // No notify: the new scene is shown together with its first item in [_present]. Showing it now
    // would build the incoming scene around the previous scene's item.
  }

  @override
  void onConversationStarted(Conversation conversation) {
    this.conversation = conversation.localized(localizer);
  }

  @override
  void onMediaUnlocked(MediaItemType item) =>
      _toast(strings.galleryUnlocked(item.title ?? item.caption ?? strings.newGalleryItem));

  @override
  void onClueFound(Clue clue) {
    if (!_cluesFound.isClosed) _cluesFound.add(clue);
  }

  @override
  void onCheckpointUnlocked(Checkpoint checkpoint) {
    _toast(strings.checkpoint(localizer.maybe(checkpoint.chapter) ?? checkpoint.conversationKey));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(flushPendingAutoSave());
    _disposed = true;
    _autoTimer?.cancel();
    _hangUp?.cancel();
    _refusalTimer?.cancel();
    _itemCache.clear();
    _cachedVisibleChannel = const [];
    settings.removeListener(_applySettings);
    _toasts.close();
    _cluesFound.close();
    audio.removeObserver();
    super.dispose();
  }
}
