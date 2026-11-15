import 'dart:async';
import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/foundation.dart';

import 'audio_helper.dart';
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

  StoryController({
    required EngineLoader loader,
    required StoryStorage storage,
    required this.config,
    AudioHelper? audio,
    PlayerPrefs? settings,
  })  : audio = audio ?? AudioHelper(),
        settings = settings ?? PlayerPrefs(storage),
        engine = RealFsseEngine(loader, storage: storage) {
    engine.listener = this;
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

  /// One-off messages (unlocks, saves) for the UI to show as toasts.
  final StreamController<String> _toasts = StreamController.broadcast();

  Stream<String> get toasts => _toasts.stream;

  bool _busy = false;
  bool _disposed = false;
  bool _pacingHeld = false;
  bool _uiHidden = false;
  Timer? _autoTimer;

  /// Bumped when a load or rollback replaces the state, so pending waits of the old state stop.
  int _epoch = 0;

  List<TranscriptEntry> get history => engine.history;

  /// VN background, characters, music, weather and zoom.
  StageState get stage => engine.stage;

  Map<String, dynamic> get dataMap => engine.dataMap;

  /// Transcript of a messenger thread across every conversation that used it.
  List<TranscriptEntry> channelHistory(String? channelId) =>
      history
          .where((entry) => entry.channelId == channelId && entry.mode != SceneMode.vn && !identical(entry, _typingEntry))
          .toList();

  Channel? get channel => engine.getChannel(scene.channelId);

  Profile? profileOf(ItemType item) => engine.getProfile(item);

  Profile? profileById(String id) => engine.getProfileById(id);

  bool get canAdvance => !_busy && (phase == StoryPhase.idle || phase == StoryPhase.showing);

  /// Whether [rollback] has a line to go back to.
  bool get canRollback => _canRewind && engine.canRollback();

  /// Whether the transcript line at [historyIndex] can be rolled back to.
  bool canRollbackTo(int historyIndex) => _canRewind && engine.canRollback(historyIndex: historyIndex);

  bool get _canRewind =>
      !_busy && phase != StoryPhase.idle && phase != StoryPhase.typing && phase != StoryPhase.waiting;

  /// Starts the story fresh, from a [save] or from a [checkpoint]. With [replay], only the checkpoint's
  /// chapter is played and nothing is saved.
  Future<void> start({SaveSlot? save, Checkpoint? checkpoint, bool replay = false}) async {
    audio.addObserver();
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
      _toasts.add("No quick save yet");
      return;
    }
    await load(save);
    _toasts.add("Quick loaded");
  }

  /// Developer panel: continues the story at [target], keeping the variables.
  Future<void> jumpTo(String target) async {
    if (_busy) return;
    _epoch++;
    _autoTimer?.cancel();
    autoMode = false;
    skipMode = false;
    notification = null;
    rolledBack = false;
    phase = StoryPhase.idle;
    await audio.stopVoice();
    await engine.jumpTo(target);
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
    final item = await engine.reloadCurrent();
    if (item == null || _disposed) return;
    _epoch++;
    if (item is StageItemType) {
      _notify();
    } else {
      rolledBack = true;
      _show(item);
    }
    _toasts.add("Story reloaded");
  }

  /// Goes back to the previous line, or to the transcript line at [historyIndex]. A choice there can be
  /// picked again.
  Future<void> rollback({int? historyIndex}) async {
    if (!_canRewind) return;
    final item = engine.rollback(historyIndex: historyIndex);
    if (item == null) return;
    _epoch++;
    _autoTimer?.cancel();
    autoMode = false;
    skipMode = false;
    notification = null;
    direction = null;
    await audio.stopVoice();
    _playMusic();
    _playAmbience();
    rolledBack = true;
    _show(item);
    if (!replay) await engine.saveTo(SaveSlot.autoSlotId);
  }

  Future<void> _begin({SaveSlot? save, Checkpoint? checkpoint, bool replay = false}) async {
    _epoch++;
    _autoTimer?.cancel();
    this.replay = replay;
    autoMode = false;
    skipMode = false;
    rolledBack = false;
    notification = null;
    direction = null;
    typingProfile = null;
    _typingEntry = null;
    phase = StoryPhase.idle;
    await audio.stopVoice();
    await engine.start(save: save, checkpoint: checkpoint, replay: replay);
    _playMusic();
    _playAmbience();

    if (save == null) {
      await advance();
      return;
    }
    // Restore: show the last delivered line of the active conversation.
    final last = history.lastWhere(
      (entry) => !entry.isPlayer && entry.conversationKey == conversation?.key,
      orElse: () => const TranscriptEntry(conversationKey: "", mode: SceneMode.vn),
    );
    final item = last.itemType;
    if (item == null || item is WaitItemType) {
      await advance();
    } else {
      current = item;
      currentProfile = engine.getProfile(item);
      _lineTyped = !_typesOut(item);
      phase = item is EndingItemType ? StoryPhase.ending : StoryPhase.showing;
      _notify();
      _scheduleAutoAdvance();
    }
  }

  /// Shows [item] again, as restored by a rollback.
  void _show(ItemType item) {
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
    await audio.playVoice(config.music(voice), character: _characterVolume(item));
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
    if (phase != StoryPhase.choice || item is! ChoiceItemType || choice.locked) return;
    await _next(ItemResult.choice(item.variable, choice));
  }

  Future<void> submitInput(String value) async {
    final item = current;
    if (phase != StoryPhase.input || item is! InputItemType) return;
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
    _scheduleAutoAdvance();
    _notify();
  }

  Future<void> saveTo(int slotId) async {
    if (replay) return;
    await engine.saveTo(slotId);
    switch (slotId) {
      case SaveSlot.autoSlotId:
        break;
      case SaveSlot.quickSlotId:
        _toasts.add("Quick saved");
      default:
        _toasts.add("Saved to slot $slotId");
    }
  }

  Future<void> _next([ItemResult? result]) async {
    final epoch = _epoch;
    _busy = true;
    _autoTimer?.cancel();
    try {
      if (result?.text != null && scene.mode == SceneMode.chat) audio.playSfx(config.music("sfx_msg_send.mp3"));
      final item = await engine.next(prevResult: result);
      await _present(item);
    } on EndOfStoryException {
      phase = StoryPhase.finished;
      _notify();
    } finally {
      _busy = false;
    }
    if (_disposed) return;

    if (phase != StoryPhase.typing && !replay) await engine.saveTo(SaveSlot.autoSlotId);
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
      await advance();
      return;
    }
    _scheduleAutoAdvance();
  }

  Future<void> _present(ItemType item) async {
    final profile = engine.getProfile(item);
    final typingDelay = switch (item) {
      TextItemType(:final typingDelayMs) || MediaItemType(:final typingDelayMs) when typingDelayMs != null =>
        typingDelayMs,
      // Incoming messages without an explicit delay still take a moment to type.
      TextItemType(:final text) when scene.mode == SceneMode.chat && !(profile?.isPlayer ?? true) =>
        min(_typingDelayMs + TextMarkup.plain(text).length * _typingDelayPerCharMs, _maxTypingDelayMs),
      MediaItemType() when scene.mode == SceneMode.chat && !(profile?.isPlayer ?? true) => _typingDelayMs * 2,
      _ => null,
    };

    if (scene.mode != SceneMode.vn && typingDelay != null && typingDelay > 0 && !skipMode) {
      phase = StoryPhase.typing;
      typingProfile = profile;
      _typingEntry = history.lastOrNull;
      _notify();
      await Future.delayed(Duration(milliseconds: typingDelay));
      if (_disposed) return;
      typingProfile = null;
      _typingEntry = null;
    }

    final sfx = switch (item) {
      TextItemType(:final sfx) || NarrationItemType(:final sfx) || MediaItemType(:final sfx) => sfx,
      _ => null,
    };
    if (sfx != null) audio.playSfx(config.music(sfx));
    await audio.stopVoice();
    if (item is TextItemType && item.voice != null && !skipMode) {
      audio.playVoice(config.music(item.voice!), character: _characterVolume(item));
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
    if (_pacingHeld == held) return;
    _pacingHeld = held;
    _scheduleAutoAdvance();
  }

  /// The VN UI is hidden to look at the stage. Auto and skip wait until it comes back.
  void setUiHidden(bool hidden) {
    if (_uiHidden == hidden) return;
    _uiHidden = hidden;
    _scheduleAutoAdvance();
  }

  void _scheduleAutoAdvance() {
    _autoTimer?.cancel();
    if (phase != StoryPhase.showing) return;
    if (scene.mode == SceneMode.chat && !skipMode) {
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
    _playMusic();
    _playAmbience();
    // No notify: the new scene is shown together with its first item in [_present]. Showing it now
    // would build the incoming scene around the previous scene's item.
  }

  @override
  void onConversationStarted(Conversation conversation) {
    this.conversation = conversation;
  }

  @override
  void onMediaUnlocked(String unlockId) => _toasts.add("Gallery unlocked: $unlockId");

  @override
  void onCheckpointUnlocked(Checkpoint checkpoint) {
    _toasts.add("Checkpoint: ${checkpoint.chapter ?? checkpoint.conversationKey}");
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoTimer?.cancel();
    settings.removeListener(_applySettings);
    _toasts.close();
    audio.removeObserver();
    super.dispose();
  }
}
