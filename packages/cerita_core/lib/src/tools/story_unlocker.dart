import '../data/items/base.dart';
import '../data/items/choice.dart';
import '../data/items/ending.dart';
import '../data/items/evidence.dart';
import '../data/items/input.dart';
import '../data/item_result.dart';
import '../fsse_engine.dart';
import '../state/meta_state.dart';
import '../story_catalog.dart';

/// What [StoryUnlocker.unlockAll] added to the meta-state, by kind. Counts only what was new.
class UnlockReport {
  final int chapters;
  final int media;
  final int endings;
  final int music;

  /// Chapters no headless run reached. They start with no variables set.
  final List<String> unplayedChapters;

  const UnlockReport({
    this.chapters = 0,
    this.media = 0,
    this.endings = 0,
    this.music = 0,
    this.unplayedChapters = const [],
  });
}

/// How a headless run answers choices and evidence questions. Several runs with different policies reach more of
/// a branching story than one.
enum UnlockPolicy {
  /// A timed choice takes its timeout option, any other choice its first option, evidence its first response.
  defaults,

  /// A timed choice takes its timeout option, any other choice its last option, evidence its first response. It
  /// reaches the routes behind last options without the wrong answers authors tend to list after the right one.
  defaultsLast,

  /// Every choice and evidence question takes its first option.
  first,

  /// Every choice and evidence question takes its last option.
  last,
}

/// Unlocks everything a story has, for a tester or an admin who needs to see all of it: every gallery item,
/// ending and music track, and every chapter in the chapter list (authoring tools §5).
///
/// A chapter needs the variables of a real playthrough, or the story after it misses its clues and flags. So the
/// unlocker plays the story headlessly, once per [UnlockPolicy], and keeps the first snapshot each run takes at
/// each checkpoint. The runs use a meta-state of their own: what they read, choose or remember never reaches the
/// player's.
class StoryUnlocker {
  final EngineLoader loader;

  /// Stops a run that goes this many items without an ending, like a puzzle that a blank answer never solves.
  final int maxSteps;

  StoryUnlocker(this.loader, {this.maxSteps = 5000});

  /// Adds every gallery item, ending, music track and chapter of the story to [meta]. What [meta] already has,
  /// a chapter snapshot included, stays as it is.
  Future<UnlockReport> unlockAll(GlobalMetaState meta) async {
    final catalog = await StoryCatalog.load(loader);
    var media = 0, endings = 0, music = 0, chapters = 0;
    for (final entry in catalog.media) {
      if (meta.unlockedMediaIds.add(entry.item.unlockId!)) media++;
    }
    for (final entry in catalog.endings) {
      if (meta.unlockedEndingIds.add(entry.item.endingId)) endings++;
    }
    for (final track in catalog.music) {
      if (meta.heardMusic.add(track)) music++;
    }

    final played = await playToCheckpoints();
    final unplayed = <String>[];
    for (final conversation in catalog.checkpoints) {
      if (meta.unlockedCheckpoints.containsKey(conversation.key)) continue;
      final checkpoint = played[conversation.key];
      if (checkpoint == null) unplayed.add(conversation.key);
      meta.unlockedCheckpoints[conversation.key] = checkpoint ??
          Checkpoint(
            conversationKey: conversation.key,
            chapter: conversation.chapterText,
            title: conversation.titleText,
            day: conversation.scene.day,
            dataMap: const {},
            unlockedAt: DateTime.now(),
          );
      chapters++;
    }
    return UnlockReport(
      chapters: chapters,
      media: media,
      endings: endings,
      music: music,
      unplayedChapters: unplayed,
    );
  }

  /// Plays the story once per policy and returns the first snapshot taken at each checkpoint, by conversation key.
  Future<Map<String, Checkpoint>> playToCheckpoints() async {
    final found = <String, Checkpoint>{};
    for (final policy in UnlockPolicy.values) {
      final engine = RealFsseEngine(loader);
      await engine.start();
      ItemResult? result;
      for (var step = 0; step < maxSteps; step++) {
        final ItemType item;
        try {
          item = await engine.next(prevResult: result);
        } on EndOfStoryException {
          break;
        }
        if (item is EndingItemType) break;
        result = _answer(engine, item, policy);
      }
      for (final MapEntry(:key, :value) in engine.meta.unlockedCheckpoints.entries) {
        found.putIfAbsent(key, () => value);
      }
    }
    return found;
  }

  static ItemResult? _answer(RealFsseEngine engine, ItemType item, UnlockPolicy policy) {
    final last = policy == UnlockPolicy.last || policy == UnlockPolicy.defaultsLast;
    switch (item) {
      case EvidenceItemType(:final responses):
        final ordered = policy == UnlockPolicy.last ? responses.reversed : responses;
        for (final response in ordered) {
          final clue = engine.clues.byId(response.clue);
          if (clue != null) return ItemResult.present(item, clue);
        }
        return const ItemResult.evidenceTimeout();
      case ChoiceItemType():
        final open = item.availableChoices.where((choice) => !choice.locked).toList();
        final timed = item.timeoutMs != null && policy.index <= UnlockPolicy.defaultsLast.index;
        final choice = (timed ? item.timeoutChoice : null) ?? (last ? open.lastOrNull : open.firstOrNull);
        return choice == null ? null : ItemResult.choice(item.variable, choice);
      case InputItemType(:final variable, :final defaultValue):
        return ItemResult.input(variable, defaultValue ?? "");
      default:
        return null;
    }
  }
}
