import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fsse/fsse.dart';

import 'audio_helper.dart';

enum StoryPhase {
  /// Nothing delivered yet.
  idle,

  /// Chat / call: "is typing..." before the next message appears.
  typing,

  /// An item is on screen; tap to continue.
  showing,
  choice,
  input,

  /// A WAIT item is running.
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

  /// Banner text of the running WAIT item.
  String? notification;

  /// VN sprite slots and the active speaker.
  final Map<SpritePosition, ProfileInfo> stage = {};
  String? speakerId;

  bool autoMode = false;
  bool skipMode = false;

  /// One-off messages (unlocks, saves) for the UI to show as toasts.
  final StreamController<String> _toasts = StreamController.broadcast();

  Stream<String> get toasts => _toasts.stream;

  bool _busy = false;
  bool _disposed = false;
  Timer? _autoTimer;

  List<TranscriptEntry> get history => engine.history;

  Map<String, dynamic> get dataMap => engine.dataMap;

  /// Transcript of a messenger thread across every conversation that used it.
  List<TranscriptEntry> channelHistory(String? channelId) =>
      history.where((entry) => entry.channelId == channelId && entry.mode != SceneMode.vn).toList();

  Channel? get channel => engine.getChannel(scene.channelId);

  Profile? profileOf(ItemType item) => engine.getProfile(item);

  Profile? profileById(String id) => engine.getProfileById(id);

  bool get canAdvance => !_busy && (phase == StoryPhase.idle || phase == StoryPhase.showing);

  Future<void> start({SaveSlot? save, Checkpoint? checkpoint}) async {
    audio.addObserver();
    await engine.start(save: save, checkpoint: checkpoint);

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
      _updateStage(item);
      phase = item is EndingItemType ? StoryPhase.ending : StoryPhase.showing;
      _notify();
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
      final wait = current as WaitItemType;
      await Future.delayed(Duration(milliseconds: skipMode ? 200 : wait.durationMs));
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
      TextItemType(:final typingDelayMs) => typingDelayMs,
      MediaItemType(:final typingDelayMs) => typingDelayMs,
      _ => null,
    };

    if (scene.mode != SceneMode.vn && typingDelay != null && typingDelay > 0 && !skipMode) {
      phase = StoryPhase.typing;
      typingProfile = profile;
      _notify();
      await Future.delayed(Duration(milliseconds: typingDelay));
      if (_disposed) return;
      typingProfile = null;
    }

    final sfx = switch (item) {
      TextItemType(:final sfx) || NarrationItemType(:final sfx) || MediaItemType(:final sfx) => sfx,
      _ => null,
    };
    if (sfx != null) audio.playSfx(config.music(sfx));
    await audio.stopVoice();
    if (item is TextItemType && item.voice != null && !skipMode) audio.playVoice(config.music(item.voice!));

    current = item;
    currentProfile = profile;
    _updateStage(item);
    phase = switch (item) {
      ChoiceItemType() => StoryPhase.choice,
      InputItemType() => StoryPhase.input,
      WaitItemType() => StoryPhase.waiting,
      EndingItemType() => StoryPhase.ending,
      _ => StoryPhase.showing,
    };
    if (item is WaitItemType) notification = item.notificationText;
    if (phase != StoryPhase.showing) {
      autoMode = false;
      skipMode = false;
    }
    _notify();
  }

  /// Places the speaker in its slot: the item's `position`, its current slot, or center.
  void _updateStage(ItemType item) {
    final info = item.getProfileInfo();
    if (info == null || info.isPlayer) {
      speakerId = null;
      return;
    }
    final existing = stage.entries.where((entry) => entry.value.id == info.id).firstOrNull?.key;
    final position = (item is TextItemType ? item.position : null) ?? existing ?? SpritePosition.center;
    if (existing != null) stage.remove(existing);
    stage[position] = info;
    speakerId = info.id;
  }

  void _scheduleAutoAdvance() {
    _autoTimer?.cancel();
    if (phase != StoryPhase.showing || (!autoMode && !skipMode)) return;
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
    final sceneChanged = scene.background != this.scene.background || scene.mode != this.scene.mode;
    this.scene = scene;
    if (sceneChanged) stage.clear();
    audio.playBgm(scene.music == null ? null : config.music(scene.music!));
    _notify();
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
