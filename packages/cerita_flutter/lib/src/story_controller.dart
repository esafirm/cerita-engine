import 'dart:async';
import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/foundation.dart';

import 'audio_helper.dart';

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
/// paces typing / waits, plays audio, tracks the VN sprite stage and autosaves.
class StoryController extends ChangeNotifier with EngineListener {
  static const _readingDelayMs = 1200;
  static const _readingDelayPerCharMs = 45;

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

  StoryController({required EngineLoader loader, required StoryStorage storage, required this.config, AudioHelper? audio})
      : audio = audio ?? AudioHelper(),
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

  /// One-off messages (unlocks, saves) for the UI to show as toasts.
  final StreamController<String> _toasts = StreamController.broadcast();

  Stream<String> get toasts => _toasts.stream;

  bool _busy = false;
  bool _disposed = false;
  bool _pacingHeld = false;
  Timer? _autoTimer;

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

  Future<void> start({SaveSlot? save, Checkpoint? checkpoint}) async {
    audio.addObserver();
    await engine.start(save: save, checkpoint: checkpoint);
    _playMusic();

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
      phase = item is EndingItemType ? StoryPhase.ending : StoryPhase.showing;
      _notify();
      _scheduleAutoAdvance();
    }
  }

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
    await engine.saveTo(slotId);
    if (slotId != SaveSlot.autoSlotId) _toasts.add("Saved to slot $slotId");
  }

  Future<void> _next([ItemResult? result]) async {
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

    if (phase != StoryPhase.typing) await engine.saveTo(SaveSlot.autoSlotId);
    if (phase == StoryPhase.waiting) {
      final duration = switch (current) {
        WaitItemType(:final durationMs) => skipMode ? 200 : durationMs,
        StageItemType item => skipMode ? 0 : item.effectiveWaitMs,
        _ => 0,
      };
      await Future.delayed(Duration(milliseconds: duration));
      if (_disposed) return;
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
        min(_typingDelayMs + text.length * _typingDelayPerCharMs, _maxTypingDelayMs),
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
    if (item is TextItemType && item.voice != null && !skipMode) audio.playVoice(config.music(item.voice!));

    direction = item is StageItemType ? item : null;
    if (item is StageItemType) _playStageAudio(item);

    current = item;
    currentProfile = profile;
    phase = switch (item) {
      ChoiceItemType() => StoryPhase.choice,
      InputItemType() => StoryPhase.input,
      WaitItemType() || StageItemType() => StoryPhase.waiting,
      EndingItemType() => StoryPhase.ending,
      _ => StoryPhase.showing,
    };
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
        case MusicAction():
          _playMusic();
        case SoundAction(:final file) when !skipMode:
          audio.playSfx(config.music(file));
        default:
          break;
      }
    }
  }

  void _playMusic() => audio.playBgm(stage.music == null ? null : config.music(stage.music!));

  /// Pauses chat pacing, e.g. while a chapter card covers the thread.
  void holdPacing(bool held) {
    if (_pacingHeld == held) return;
    _pacingHeld = held;
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
    if (skipMode && !engine.lastItemPreviouslySeen) {
      // Skip only fast-forwards text read in an earlier playthrough.
      skipMode = false;
      _notify();
      return;
    }
    final length = current?.getText()?.length ?? 0;
    final delay = skipMode ? 120 : _readingDelayMs + length * _readingDelayPerCharMs;
    _autoTimer = Timer(Duration(milliseconds: delay), advance);
  }

  @override
  void onNewScene(Scene scene) {
    this.scene = scene;
    _playMusic();
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
    _toasts.close();
    audio.removeObserver();
    super.dispose();
  }
}
